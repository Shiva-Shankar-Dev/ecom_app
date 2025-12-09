// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';
import 'package:ecom_app/widgets/auth_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart'
    hide Order;
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ecom_app/services/auth.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';

import '../models/product.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  final AuthService _authService = AuthService();

  List<Product> products = [];
  List<Order> orders = [];
  int _selectedIndex = 0;

  //reading excel
  Future<List<Map<String, dynamic>>> readExcelFromHive() async {
    final box = Hive.box('filesBox');
    final Uint8List? bytes = box.get('excelFile');

    if (bytes == null) {
      debugPrint("No Excel file found in Hive.");
      return [];
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]; // First sheet

    if (sheet == null) return [];

    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString() ?? "")
        .toList();
    final products = <Map<String, dynamic>>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final product = <String, dynamic>{};

      for (var j = 0; j < headers.length; j++) {
        product[headers[j]] = row[j]?.value;
      }

      products.add(product);
    }

    return products;
  }

  @override
  void initState() {
    super.initState();
    loadProducts();
    loadOrders();
  }

  // Load products directly from Firestore since that's where the actual products are stored
  Future<void> loadProducts() async {
    await loadProductsFromFirestore();
    debugPrint("Products loaded from Firestore: ${products.length}");
  }

  Future<void> loadProductsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        debugPrint("User not logged in!");
        return;
      }

      final QuerySnapshot existingProducts = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user)
          .get();

      setState(() {
        products = existingProducts.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          final variants = <ProductVariant>[];
          if (data['variants'] != null) {
            for (final variantData in data['variants']) {
              variants.add(
                ProductVariant.fromMap(variantData as Map<String, dynamic>),
              );
            }
          }

          return Product(
            pid: data['pid']?.toString() ?? 'No product ID',
            name: data['name']?.toString() ?? 'No name',
            brand: data['brand']?.toString() ?? 'No brand',
            category: data['category']?.toString() ?? 'No category',
            basePrice: (data['price'] is num)
                ? (data['price'] as num).toDouble()
                : (data['basePrice'] is num)
                ? (data['basePrice'] as num).toDouble()
                : 0.0,
            description: data['description']?.toString() ?? 'No description',
            deliveryTime: data['deliveryTime']?.toString() ?? 'N/A',
            stockQuantity: data['stockQuantity'] ?? 0,
            images: List<String>.from(data['images'] ?? []),
            keywords: List<String>.from(data['keywords'] ?? []),
            variants: variants,
          );
        }).toList();
      });

      debugPrint("✅ Loaded ${products.length} products from Firestore");
    } catch (e) {
      debugPrint("❌ Failed to load products from Firestore: $e");
    }
  }

  Future<void> pickAndStoreExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.bytes != null) {
      // Process Excel file directly and upload to Firestore
      final excelData = await processExcelFile(result.files.single.bytes!);
      if (excelData.isNotEmpty) {
        await uploadExcelProductsToFirestore(excelData);
        // Reload products from Firestore after upload
        await loadProducts();

        // Show upload summary
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Excel file processed successfully! Check console for details.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      debugPrint("File picking canceled or failed.");
    }
  }

  Future<List<Map<String, dynamic>>> processExcelFile(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);

    // Debug: Print all available sheet names
    debugPrint("📋 Available Excel sheets: ${excel.tables.keys.toList()}");

    // Get Products sheet (try different possible names)
    Sheet? productsSheet;
    for (String sheetName in ['Products', 'Product', 'products', 'PRODUCTS']) {
      if (excel.tables.containsKey(sheetName)) {
        productsSheet = excel.tables[sheetName];
        debugPrint("✅ Found Products sheet: $sheetName");
        break;
      }
    }

    // If no "Products" sheet found, use the first sheet
    if (productsSheet == null) {
      productsSheet = excel.tables[excel.tables.keys.first];
      debugPrint(
        "⚠️ No Products sheet found, using first sheet: ${excel.tables.keys.first}",
      );
    }

    if (productsSheet == null) return [];

    // Get Variants sheet (try different possible names)
    Sheet? variantsSheet;
    for (String sheetName in ['Variants', 'Variant', 'variants', 'VARIANTS']) {
      if (excel.tables.containsKey(sheetName)) {
        variantsSheet = excel.tables[sheetName];
        debugPrint("✅ Found Variants sheet: $sheetName");
        break;
      }
    }

    if (variantsSheet == null) {
      debugPrint(
        "⚠️ No Variants sheet found. Available sheets: ${excel.tables.keys.toList()}",
      );
    }

    final products = await _processProductsSheet(productsSheet);
    debugPrint("📦 Processed ${products.length} products from Products sheet");

    if (variantsSheet != null) {
      final variants = await _processVariantsSheet(variantsSheet);
      debugPrint(
        "🎨 Processed ${variants.length} variants from Variants sheet",
      );
      _attachVariantsToProducts(products, variants);

      // Debug: Check how many products have variants after attachment
      int productsWithVariants = products
          .where((p) => (p['variants'] as List).isNotEmpty)
          .length;
      debugPrint("🔗 ${productsWithVariants} products have variants attached");
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _processProductsSheet(Sheet sheet) async {
    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString() ?? "")
        .toList();
    debugPrint("📊 Products sheet headers: $headers");

    final products = <Map<String, dynamic>>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final product = <String, dynamic>{};

      for (var j = 0; j < headers.length; j++) {
        product[headers[j]] = row[j]?.value;
      }

      // Initialize variants list
      product['variants'] = <Map<String, dynamic>>[];

      // Debug: Print product ID for tracking
      final productId = product['PID']?.toString();
      debugPrint(
        "📦 Processing product: ${product['Name']} with PID: $productId",
      );

      products.add(product);
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _processVariantsSheet(Sheet sheet) async {
    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString() ?? "")
        .toList();
    debugPrint("🎨 Variants sheet headers: $headers");

    final variants = <Map<String, dynamic>>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final variant = <String, dynamic>{};

      for (var j = 0; j < headers.length; j++) {
        variant[headers[j]] = row[j]?.value;
      }

      // Debug: Print variant details
      final variantName =
          variant['Variant_Name']?.toString() ?? variant['Name']?.toString();
      final parentId =
          variant['Parent_ID']?.toString() ?? variant['ParentID']?.toString();
      final priceModifier =
          variant['Price_Modifier'] ??
          variant['PriceModifier'] ??
          variant['Modifier'];
      debugPrint(
        "🎨 Processing variant: $variantName, Parent_ID: $parentId, Price_Modifier: $priceModifier",
      );

      variants.add(variant);
    }

    return variants;
  }

  void _attachVariantsToProducts(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> variants,
  ) {
    debugPrint(
      "🔗 Starting to attach ${variants.length} variants to ${products.length} products",
    );

    for (final variant in variants) {
      final parentId =
          variant['Parent_ID']?.toString() ?? variant['ParentID']?.toString();
      debugPrint(
        "🎯 Processing variant: ${variant['Variant_Name'] ?? variant['Name']} with Parent_ID: $parentId",
      );

      if (parentId != null) {
        bool attached = false;
        for (final product in products) {
          final productId = product['PID']?.toString();
          debugPrint(
            "   Checking product PID: $productId against Parent_ID: $parentId",
          );

          if (productId == parentId) {
            (product['variants'] as List<Map<String, dynamic>>).add(variant);
            debugPrint("   ✅ Variant attached to product: ${product['Name']}");
            attached = true;
            break;
          }
        }

        if (!attached) {
          debugPrint("   ❌ No matching product found for Parent_ID: $parentId");
        }
      } else {
        debugPrint("   ⚠️ Variant has no Parent_ID");
      }
    }
  }

  // Dynamic attribute extraction method
  Map<String, String> _extractDynamicAttributes(Map<String, dynamic> variant) {
    final attributes = <String, String>{};

    debugPrint(
      "🔍 Extracting attributes from variant keys: ${variant.keys.toList()}",
    );

    // System/reserved fields that should not be treated as attributes
    final systemFields = {
      'Variant_ID', 'VariantID', 'Parent_ID', 'ParentID',
      'Variant_Name', 'Name', 'Price', 'Variant_Price',
      'Price_Modifier', 'PriceModifier', 'Modifier',
      'price_modifier', 'pricemodifier', 'modifier', // lowercase variants
      'PRICE_MODIFIER', 'PRICEMODIFIER', 'MODIFIER', // uppercase variants
      'Stock', 'Quantity', 'Stock_Quantity', 'Image',
      'stock', 'quantity', 'stock_quantity', 'image', // lowercase variants
    };

    // Convert any non-system field with a value into an attribute
    for (final entry in variant.entries) {
      final key = entry.key;
      // Check both exact match and case-insensitive match for system fields
      final isSystemField =
          systemFields.contains(key) ||
          systemFields.contains(key.toLowerCase()) ||
          systemFields.contains(key.toUpperCase());

      if (!isSystemField) {
        final cleanValue = _cleanString(entry.value);
        if (cleanValue != null && cleanValue.isNotEmpty) {
          // Format the attribute key nicely
          String attributeKey = key;
          if (attributeKey.contains('_')) {
            attributeKey = attributeKey
                .split('_')
                .map(
                  (word) =>
                      word[0].toUpperCase() + word.substring(1).toLowerCase(),
                )
                .join(' ');
          }
          attributes[attributeKey] = cleanValue;
          debugPrint("   ✅ Added attribute: '$attributeKey' = '$cleanValue'");
        }
      } else {
        debugPrint("   ❌ Excluded system field: '$key'");
      }
    }

    return attributes;
  }

  // Helper method to clean string values and handle nulls
  String? _cleanString(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    final cleaned = value.toString().trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  // Helper method to parse integers with better null handling
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();

    final str = value.toString().trim();
    if (str.isEmpty) return 0;

    // Remove non-numeric characters except decimal point for parsing
    final cleanStr = str.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleanStr) ?? 0;
  }

  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is DateTime) return 0.0; // Don't treat dates as price

    final str = value.toString().replaceAll(RegExp(r'[^\d.]'), '');

    return double.tryParse(str) ?? 0.0;
  }

  double _calculateItemTotal(Map<String, dynamic> item) {
    try {
      final price = _parsePrice(item['price'] ?? item['productPrice']);
      final quantity = (item['quantity'] ?? 1) is num
          ? (item['quantity'] ?? 1)
          : 1;
      return price * quantity.toDouble();
    } catch (e) {
      print("❌ Error calculating item total: $e");
      return 0.0;
    }
  }

  Future<void> uploadExcelProductsToFirestore(
    List<Map<String, dynamic>> excelData,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        debugPrint("User not logged in!");
        return;
      }

      // Get all existing products for this seller
      final QuerySnapshot existingProducts = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user)
          .get();

      // Create a map of existing products by PID for quick lookup
      Map<String, DocumentSnapshot> existingProductMap = {};
      for (var doc in existingProducts.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pid = data['pid']?.toString();
        if (pid != null) {
          existingProductMap[pid] = doc;
        }
      }

      int updatedCount = 0;
      int addedCount = 0;

      for (var productMap in excelData) {
        // Extract known fields with better null handling
        final pid = _cleanString(productMap['PID']) ?? 'No product ID';
        final name = _cleanString(productMap['Name']) ?? 'No Name';
        final brand = _cleanString(productMap['Brand']) ?? 'No Brand';
        final category = _cleanString(productMap['Category']) ?? 'No Category';
        final price = _parsePrice(productMap['Price']);
        final description =
            _cleanString(productMap['Description']) ?? 'No Description';
        final deliveryTime = _cleanString(productMap['Delivery Time']) ?? 'N/A';

        // Calculate total stock from variants if available, otherwise use product stock
        int totalStock = 0;
        List<String> allImages = [];

        // Process variants first to get images and calculate total stock
        final variantsList = <Map<String, dynamic>>[];
        if (productMap['variants'] != null &&
            (productMap['variants'] as List).isNotEmpty) {
          for (final variant in productMap['variants']) {
            final variantStock = _parseInt(
              variant['Stock'] ??
                  variant['Quantity'] ??
                  variant['Stock_Quantity'],
            );
            totalStock += variantStock;

            // Collect variant images
            final variantImage = _cleanString(variant['Image']);
            if (variantImage != null && variantImage.isNotEmpty) {
              allImages.add(variantImage);
            }

            // Calculate variant price using base price + modifier
            final priceModifier = _parsePrice(
              variant['Price_Modifier'] ??
                  variant['PriceModifier'] ??
                  variant['Modifier'] ??
                  variant['Price'] ??
                  variant['Variant_Price'] ??
                  0,
            );
            final variantPrice = price + priceModifier;

            variantsList.add({
              'variantId':
                  _cleanString(variant['Variant_ID']) ??
                  _cleanString(variant['VariantID']) ??
                  '',
              'name':
                  _cleanString(variant['Variant_Name']) ??
                  _cleanString(variant['Name']) ??
                  '',
              'price': variantPrice,
              'basePrice': price,
              'priceModifier': priceModifier,
              'stockQuantity': variantStock,
              'attributes': _extractDynamicAttributes(variant),
              'image': variantImage,
            });
          }
        } else {
          // No variants, use product-level stock
          totalStock = _parseInt(productMap['Stock Quantity']);
        }

        // Handle product images - prefer variant images if available
        final productImageField = _cleanString(productMap['Images']);
        if (productImageField != null && productImageField.isNotEmpty) {
          final productImages = productImageField
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          allImages.insertAll(0, productImages); // Product images first
        }

        // Remove duplicates and empty images
        final images = allImages
            .toSet()
            .where((img) => img.isNotEmpty)
            .toList();

        final keywordsList = _cleanString(productMap['Keywords']) ?? '';
        final keywords = keywordsList
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final productData = {
          'sellerId': user,
          'pid': pid,
          'name': name,
          'brand': brand,
          'category': category,
          'price': price, // Keep as basePrice for backwards compatibility
          'basePrice': price,
          'description': description,
          'deliveryTime': deliveryTime,
          'stockQuantity':
              totalStock, // Total stock from variants or product level
          'keywords': keywords.isNotEmpty
              ? keywords
              : [
                  name.toLowerCase(),
                  brand.toLowerCase(),
                  category.toLowerCase(),
                ].where((k) => k.isNotEmpty).toList(),
          'images': images, // Combined images from variants and product
          'variants': variantsList,
          'hasVariants': variantsList.isNotEmpty,
        };

        debugPrint("📦 Product data for $name:");
        debugPrint("   - PID: $pid");
        debugPrint(
          "   - Total Stock: $totalStock (from ${variantsList.isNotEmpty ? 'variants' : 'product'})",
        );
        debugPrint(
          "   - Images: ${images.length} (${images.take(2).join(', ')}${images.length > 2 ? '...' : ''})",
        );
        debugPrint("   - Variants: ${variantsList.length}");
        if (variantsList.isNotEmpty) {
          for (int i = 0; i < variantsList.length; i++) {
            final v = variantsList[i];
            debugPrint(
              "     Variant ${i + 1}: ${v['name']} (Stock: ${v['stockQuantity']}, Base: ₹${v['basePrice']}, Modifier: ${v['priceModifier'] >= 0 ? '+' : ''}₹${v['priceModifier']}, Final: ₹${v['price']})",
            );
            if (v['attributes'] != null &&
                (v['attributes'] as Map).isNotEmpty) {
              debugPrint("       Attributes: ${v['attributes']}");
            } else {
              debugPrint("       No attributes found");
            }
          }
        }

        // Check if product already exists
        if (existingProductMap.containsKey(pid)) {
          // Update existing product
          final existingDoc = existingProductMap[pid]!;
          await existingDoc.reference.update(productData);
          updatedCount++;
          debugPrint("✅ Product '$name' (PID: $pid) updated in Firestore.");
        } else {
          // Add new product
          await FirebaseFirestore.instance
              .collection('products')
              .add(productData);
          addedCount++;
          debugPrint("✅ Product '$name' (PID: $pid) added to Firestore.");
        }
      }

      debugPrint(
        "✅ Upload complete! Added: $addedCount, Updated: $updatedCount products.",
      );
    } catch (e) {
      debugPrint("❌ Upload failed: $e");
      rethrow;
    }
  }

  Future<void> loadOrders() async {
    await loadOrdersFromFirestore();
    print("Orders loaded from Firestore: ${orders.length}");
  }

  Future<void> loadOrdersFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        print("User not logged in!");
        return;
      }

      print("🔍 Current user ID: $user");
      print("🔍 Attempting to load orders from 'user_orders' collection...");

      // Get all orders and filter by sellerId in items array
      final QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('user_orders')
          .get(); // Get all orders first, then filter

      print("🔍 Raw query returned ${orderSnapshot.docs.length} documents");

      List<Order> filteredOrders = [];

      for (var doc in orderSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if items array exists and has seller matching current user
        if (data['items'] != null && data['items'] is List) {
          List<dynamic> items = data['items'] as List<dynamic>;

          // Check each item for sellerId matching current user
          for (var item in items) {
            if (item is Map<String, dynamic> && item['sellerId'] == user) {
              try {
                // Create order object for each item that belongs to current seller
                final orderData = {
                  'orderId': (data['orderId'] ?? doc.id).toString(),
                  'sellerId': (item['sellerId'] ?? '').toString(),
                  'buyerId': (data['buyerId'] ?? data['userId'] ?? '')
                      .toString(),
                  'productId': (item['productId'] ?? '').toString(),
                  'productName':
                      (item['productName'] ??
                              item['productTitle'] ??
                              item['name'] ??
                              '')
                          .toString(),
                  'productImage': (item['productImage'] ?? item['image'] ?? '')
                      .toString(),
                  'price': _parsePrice(item['price'] ?? item['productPrice']),
                  'quantity': (item['quantity'] ?? 1) is num
                      ? (item['quantity'] ?? 1)
                      : 1,
                  'totalAmount': _calculateItemTotal(item),
                  'status': (data['status'] ?? item['status'] ?? 'pending')
                      .toString(),
                  'orderDate':
                      data['orderDate'] ?? data['createdAt'] ?? Timestamp.now(),
                  'buyerName':
                      (data['buyerName'] ??
                              data['customerName'] ??
                              data['name'] ??
                              '')
                          .toString(),
                  'buyerEmail': (data['buyerEmail'] ?? data['email'] ?? '')
                      .toString(),
                  'buyerPhone': (data['buyerPhone'] ?? data['phone'] ?? '')
                      .toString(),
                  'shippingAddress':
                      (data['shippingAddress'] ?? data['address'] ?? '')
                          .toString(),
                };

                filteredOrders.add(Order.fromFirestore(orderData));
                print("🔍 Found order item for seller: ${item['productName']}");
              } catch (e) {
                print("❌ Error parsing order item: $e");
                print("❌ Problematic item data: $item");
              }
            }
          }
        }
      }

      // Sort orders by date (newest first)
      filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

      setState(() {
        orders = filteredOrders;
      });

      print(
        "✅ Loaded ${orders.length} orders from Firestore for current seller",
      );

      // Debug: Print first few orders
      for (int i = 0; i < orders.length && i < 3; i++) {
        final order = orders[i];
        print(
          "🔍 Order $i: ${order.orderId} - ${order.productName} - ${order.status}",
        );
      }
    } catch (e) {
      print("❌ Failed to load orders from Firestore: $e");

      // Test basic collection access
      try {
        print("🔍 Testing basic collection access...");
        final testSnapshot = await FirebaseFirestore.instance
            .collection('user_orders')
            .limit(1)
            .get();
        print(
          "🔍 Basic collection test returned ${testSnapshot.docs.length} docs",
        );
        if (testSnapshot.docs.isNotEmpty) {
          print(
            "🔍 Sample document structure: ${testSnapshot.docs.first.data()}",
          );
        }
      } catch (testError) {
        print("❌ Basic collection test failed: $testError");
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildProductsTab() {
    return products.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Lottie.asset('assets/post.json', width: 200, height: 200),
                SizedBox(height: 20),
                Text(
                  'No Products Found',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Please add products to get started.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                AuthButton(
                  hintText: 'Add Products',
                  onPressed: () async {
                    try {
                      await pickAndStoreExcel();
                    } catch (e) {
                      print("❌ Upload failed: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Upload failed: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Products',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(product);
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildProductCard(Product product) {
    // Get the best image to display (prefer variant images if main product has none)
    String? displayImage;
    if (product.images.isNotEmpty) {
      displayImage = product.images.first;
    } else if (product.variants.isNotEmpty) {
      // Try to get image from first variant that has one
      for (final variant in product.variants) {
        if (variant.image != null && variant.image!.isNotEmpty) {
          displayImage = variant.image;
          break;
        }
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ExpansionTile(
        leading: displayImage != null && displayImage.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  displayImage,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, color: Colors.grey[600]),
                  ),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_bag, color: Colors.grey[600]),
              ),
        title: Text(
          product.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.priceRange,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
            Text('${product.brand} • ${product.category}'),
            if (product.variants.isNotEmpty)
              Text(
                '${product.variants.length} variant${product.variants.length > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.blue[600], fontSize: 12),
              ),
          ],
        ),
        children: [
          if (product.variants.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Variants:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...product.variants.map(
                    (variant) => _buildVariantItem(variant),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Base Price: ₹${product.basePrice.toStringAsFixed(2)}'),
                  Text('Stock: ${product.stockQuantity}'),
                  Text('Delivery: ${product.deliveryTime}'),
                  SizedBox(height: 8),
                  Text(
                    product.description,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantItem(ProductVariant variant) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Variant image (if available)
          if (variant.image != null && variant.image!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                variant.image!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.image, size: 20, color: Colors.grey[500]),
                ),
              ),
            ),
            SizedBox(width: 12),
          ],

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.name.isNotEmpty ? variant.name : 'Unnamed Variant',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (variant.attributes.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: variant.attributes.entries
                        .where((attr) => attr.value.isNotEmpty)
                        .map(
                          (attr) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Text(
                              '${attr.key}: ${attr.value}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Stock: ${variant.stockQuantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: variant.stockQuantity > 0
                            ? Colors.green[600]
                            : Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${variant.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              if (variant.stockQuantity == 0)
                Text(
                  'Out of Stock',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    // Get all variants from all products for individual display
    List<Map<String, dynamic>> allVariants = [];

    for (final product in products) {
      if (product.variants.isNotEmpty) {
        // Add each variant with product context
        for (final variant in product.variants) {
          allVariants.add({'product': product, 'variant': variant});
        }
      } else {
        // For products without variants, treat the product itself as a variant
        allVariants.add({
          'product': product,
          'variant': null, // No variant, use product data
        });
      }
    }

    return allVariants.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  'No Stock Available',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Add products to see stock information.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Inventory',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Individual Variants (${allVariants.length} items)',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  itemCount: allVariants.length,
                  itemBuilder: (context, index) {
                    final item = allVariants[index];
                    final product = item['product'] as Product;
                    final variant = item['variant'] as ProductVariant?;

                    return _buildStockVariantCard(product, variant);
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildStockVariantCard(Product product, ProductVariant? variant) {
    // Determine stock quantity and other details
    final stockQuantity = variant?.stockQuantity ?? product.stockQuantity;
    final variantName = variant?.name ?? 'Base Product';
    final price = variant?.price ?? product.basePrice;
    final image =
        variant?.image ??
        (product.images.isNotEmpty ? product.images.first : null);

    // Determine stock status color
    Color stockColor;
    if (stockQuantity > 10) {
      stockColor = Colors.green;
    } else if (stockQuantity > 0) {
      stockColor = Colors.orange;
    } else {
      stockColor = Colors.red;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            // Product/Variant Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.image, color: Colors.grey[600]),
                      ),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2, color: Colors.grey[600]),
                    ),
            ),
            SizedBox(width: 12),

            // Product and Variant Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variant != null) ...[
                    SizedBox(height: 2),
                    Text(
                      variantName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${product.brand}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '₹${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),

                  // Variant attributes (if any)
                  if (variant != null && variant.attributes.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: variant.attributes.entries
                          .take(2) // Show only first 2 attributes to save space
                          .map(
                            (attr) => Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Text(
                                '${attr.key}: ${attr.value}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Stock Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stockColor),
                  ),
                  child: Text(
                    '$stockQuantity',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: stockColor,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  stockQuantity == 0
                      ? 'Out of Stock'
                      : stockQuantity == 1
                      ? '1 left'
                      : 'in stock',
                  style: TextStyle(
                    fontSize: 10,
                    color: stockColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Orders Placed',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                print("🔄 Manual refresh triggered");
                loadOrders();
              },
            ),
          ],
        ),
        SizedBox(height: 10),

        // Debug info
        Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: orders.isEmpty
                ? Colors.yellow.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: orders.isEmpty ? Colors.yellow : Colors.green,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Debug Info:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "Current User: ${FirebaseAuth.instance.currentUser?.uid ?? 'Not logged in'}",
              ),
              Text("Orders loaded: ${orders.length}"),
              Text("Collection: user_orders"),
              Text("Filter: items array with sellerId"),
            ],
          ),
        ),

        if (orders.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No Orders Yet',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Orders will appear here once customers purchase your products.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      print("🔄 Manual refresh from button");
                      loadOrders();
                    },
                    child: Text("Refresh Orders"),
                  ),
                ],
              ),
            ),
          )
        else
          _buildOrdersList(),
      ],
    );
  }

  Widget _buildOrdersList() {
    if (orders.isEmpty) return SizedBox.shrink();

    // Group orders by date
    Map<String, List<Order>> ordersByDate = {};
    for (Order order in orders) {
      String dateKey = DateFormat('yyyy-MM-dd').format(order.orderDate);
      ordersByDate[dateKey] ??= [];
      ordersByDate[dateKey]!.add(order);
    }

    // Sort dates in descending order
    List<String> sortedDates = ordersByDate.keys.toList();
    sortedDates.sort((a, b) => b.compareTo(a));

    return Expanded(
      child: ListView.builder(
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          String dateKey = sortedDates[index];
          List<Order> dayOrders = ordersByDate[dateKey]!;
          DateTime date = DateTime.parse(dateKey);
          String formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              ...dayOrders.map((order) => _buildOrderCard(order)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    Color statusColor;
    switch (order.status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      case 'shipped':
        statusColor = Colors.purple;
        break;
      case 'delivered':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    order.productImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Order ID: ${order.orderId}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Qty: ${order.quantity}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            '\$${order.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Divider(height: 1),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  order.buyerName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  DateFormat('hh:mm a').format(order.orderDate),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home Page"),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Add products',
            onPressed: () async {
              try {
                await pickAndStoreExcel();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Products uploaded/updated successfully!'),
                  ),
                );
              } catch (e) {
                debugPrint("❌ Upload failed: $e");
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded),
              title: Text('Sign Out'),
              onTap: () {
                _authService.signOut();
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: IndexedStack(
          index: _selectedIndex,
          children: [_buildProductsTab(), _buildStockTab(), _buildOrdersTab()],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Stock Available',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Order Placed',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
