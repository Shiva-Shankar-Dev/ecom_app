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
import 'stock_tab.dart';
import 'orders_tab.dart';

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
            keywords: List<String>.from(data['keywords'] ?? []),
            variants: variants,
            returnDays: data['returnDays'] is int ? data['returnDays'] : null,
            replacementDays: data['replacementDays'] is int
                ? data['replacementDays']
                : null,
            cancellationCharge: data['cancellationCharge'] is num
                ? (data['cancellationCharge'] as num).toDouble()
                : null,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint("Failed to load products: $e");
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
    }
  }

  Future<List<Map<String, dynamic>>> processExcelFile(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);

    // Get Products sheet (try different possible names)
    Sheet? productsSheet;
    final productSheetNames = [
      'Products',
      'Product',
      'products',
      'PRODUCTS',
      'Sheet1',
    ];
    for (String sheetName in productSheetNames) {
      if (excel.tables.containsKey(sheetName)) {
        productsSheet = excel.tables[sheetName];

        break;
      }
    }

    // If no "Products" sheet found, use the first sheet
    if (productsSheet == null && excel.tables.isNotEmpty) {
      final firstSheetName = excel.tables.keys.first;
      productsSheet = excel.tables[firstSheetName];
    }

    if (productsSheet == null || productsSheet.rows.isEmpty) {
      return [];
    }

    // Get Variants sheet (try different possible names)
    Sheet? variantsSheet;
    final variantSheetNames = [
      'Variants',
      'Variant',
      'variants',
      'VARIANTS',
      'Sheet2',
    ];
    for (String sheetName in variantSheetNames) {
      if (excel.tables.containsKey(sheetName)) {
        variantsSheet = excel.tables[sheetName];
        break;
      }
    }

    if (variantsSheet == null) {
      // No variants sheet found, products will be processed without variants
    } else if (variantsSheet.rows.isEmpty) {
      variantsSheet = null;
    }

    // Process Products sheet
    final products = await _processProductsSheet(productsSheet);

    // Process Variants sheet if available
    if (variantsSheet != null) {
      final variants = await _processVariantsSheet(variantsSheet);
      if (variants.isNotEmpty) {
        _attachVariantsToProducts(products, variants);
      }
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _processProductsSheet(Sheet sheet) async {
    if (sheet.rows.isEmpty) {
      return [];
    }

    // Extract headers from first row
    final headers = sheet.rows.first
        .map((cell) => _cleanString(cell?.value) ?? "")
        .where((header) => header.isNotEmpty)
        .toList();

    if (headers.isEmpty) {
      return [];
    }

    final products = <Map<String, dynamic>>[];

    // Process each row (skip header row)
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      final product = <String, dynamic>{};

      // Map each cell to its corresponding header
      for (var j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final cellValue = row[j]?.value;

        if (header.isNotEmpty && cellValue != null) {
          product[header] = cellValue;
        }
      }

      // Skip empty products
      if (product.isEmpty) continue;

      // Initialize variants list for this product
      product['variants'] = <Map<String, dynamic>>[];

      // Validate required fields
      final productId =
          _cleanString(product['PID']) ?? _cleanString(product['ID']);
      final productName =
          _cleanString(product['Name']) ?? _cleanString(product['ProductName']);

      if (productId == null || productName == null) {
        continue;
      }

      products.add(product);
    }

    return products;
  }

  Future<List<Map<String, dynamic>>> _processVariantsSheet(Sheet sheet) async {
    if (sheet.rows.isEmpty) {
      debugPrint("❌ Variants sheet is empty");
      return [];
    }

    // Extract headers from first row
    final headers = sheet.rows.first
        .map((cell) => _cleanString(cell?.value) ?? "")
        .where((header) => header.isNotEmpty)
        .toList();

    if (headers.isEmpty) {
      return [];
    }

    final variants = <Map<String, dynamic>>[];

    // Process each row (skip header row)
    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      final variant = <String, dynamic>{};

      // Map each cell to its corresponding header
      for (var j = 0; j < headers.length && j < row.length; j++) {
        final header = headers[j];
        final cellValue = row[j]?.value;

        if (header.isNotEmpty && cellValue != null) {
          variant[header] = cellValue;
        }
      }

      // Skip empty variants
      if (variant.isEmpty) continue;

      // Validate required fields for variants
      final parentId =
          _cleanString(variant['Parent_ID']) ??
          _cleanString(variant['ParentID']) ??
          _cleanString(variant['PID']);

      if (parentId == null) {
        continue;
      }

      variants.add(variant);
    }

    return variants;
  }

  void _attachVariantsToProducts(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> variants,
  ) {
    if (products.isEmpty || variants.isEmpty) {
      return;
    }

    // Create a map of products by PID for faster lookup
    final productMap = <String, Map<String, dynamic>>{};
    for (final product in products) {
      final productId =
          _cleanString(product['PID']) ?? _cleanString(product['ID']);
      if (productId != null) {
        productMap[productId] = product;
      }
    }

    for (final variant in variants) {
      // Try multiple possible parent ID field names
      final parentId =
          _cleanString(variant['Parent_ID']) ??
          _cleanString(variant['ParentID']) ??
          _cleanString(variant['PID']) ??
          _cleanString(variant['ProductID']);

      if (parentId != null && productMap.containsKey(parentId)) {
        // Found matching product
        final product = productMap[parentId]!;
        (product['variants'] as List<Map<String, dynamic>>).add(variant);
      }
    }
  }

  // Dynamic attribute extraction method
  Map<String, String> _extractDynamicAttributes(Map<String, dynamic> variant) {
    final attributes = <String, String>{};

    // Comprehensive system/reserved fields that should NOT be treated as attributes
    final systemFields = {
      // ID fields
      'Variant_ID',
      'VariantID',
      'variant_id',
      'variantid',
      'VARIANT_ID',
      'VARIANTID',
      'Parent_ID', 'ParentID', 'parent_id', 'parentid', 'PARENT_ID', 'PARENTID',
      'PID',
      'pid',
      'ID',
      'id',
      'ProductID',
      'productid',
      'product_id',
      'PRODUCTID',

      // Name fields (all variations)
      'Variant_Name',
      'VariantName',
      'variant_name',
      'variantname',
      'VARIANT_NAME',
      'VARIANTNAME',
      'Variant Name', 'variant name', 'VARIANT NAME',
      'Name', 'name', 'NAME', 'Title', 'title', 'TITLE',
      'Variant_Title', 'VariantTitle', 'variant_title', 'varianttitle',

      // Price fields
      'Price', 'price', 'PRICE',
      'Variant_Price',
      'VariantPrice',
      'variant_price',
      'variantprice',
      'VARIANT_PRICE',
      'VARIANTPRICE',
      'Price_Modifier', 'PriceModifier', 'price_modifier', 'pricemodifier',
      'PRICE_MODIFIER', 'PRICEMODIFIER', 'Modifier', 'modifier', 'MODIFIER',
      'BasePrice', 'base_price', 'baseprice', 'BASE_PRICE',

      // Stock/Quantity fields
      'Stock', 'stock', 'STOCK',
      'Quantity', 'quantity', 'QUANTITY',
      'Stock_Quantity', 'StockQuantity', 'stock_quantity', 'stockquantity',
      'STOCK_QUANTITY', 'STOCKQUANTITY',
      'Available', 'available', 'AVAILABLE',

      // Image fields
      'Image', 'image', 'IMAGE',
      'Images', 'images', 'IMAGES',
      'Photo', 'photo', 'PHOTO',
      'Picture', 'picture', 'PICTURE',

      // Other system fields
      'SKU', 'sku', 'Sku',
      'Barcode', 'barcode', 'BARCODE',
      'Description', 'description', 'DESCRIPTION',
    };

    // Convert any non-system field with a valid value into an attribute
    for (final entry in variant.entries) {
      final key = entry.key.toString();
      final keyLower = key.toLowerCase();
      final keyUpper = key.toUpperCase();
      final keyNormalized = key.replaceAll(' ', '_').toLowerCase();

      // Comprehensive system field check
      final isSystemField =
          systemFields.contains(key) ||
          systemFields.contains(keyLower) ||
          systemFields.contains(keyUpper) ||
          systemFields.contains(keyNormalized) ||
          // Pattern-based exclusions
          keyLower.startsWith('variant') &&
              (keyLower.contains('name') || keyLower.contains('id')) ||
          keyLower.startsWith('parent') && keyLower.contains('id') ||
          keyLower.endsWith('_id') ||
          keyLower.endsWith('id') ||
          keyLower.contains('price') ||
          keyLower.contains('stock') ||
          keyLower.contains('quantity') ||
          keyLower.contains('image');

      if (!isSystemField) {
        final cleanValue = _cleanString(entry.value);
        if (cleanValue != null && cleanValue.isNotEmpty) {
          // Format the attribute key nicely
          String attributeKey = _formatAttributeKey(key);
          attributes[attributeKey] = cleanValue;
        }
      }
    }

    return attributes;
  }

  // Helper method to format attribute keys nicely
  String _formatAttributeKey(String key) {
    // Handle underscores and capitalize properly
    if (key.contains('_')) {
      return key
          .split('_')
          .map(
            (word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '',
          )
          .where((word) => word.isNotEmpty)
          .join(' ');
    }

    // Handle camelCase
    if (key.length > 1 && key.contains(RegExp(r'[a-z][A-Z]'))) {
      return key
          .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                : '',
          )
          .where((word) => word.isNotEmpty)
          .join(' ');
    }

    // Default: capitalize first letter
    return key.isNotEmpty
        ? key[0].toUpperCase() + key.substring(1).toLowerCase()
        : key;
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

        // Extract new return/replacement/cancellation fields
        final returnDaysStr = _cleanString(productMap['Return']);
        final returnDays = returnDaysStr != null
            ? int.tryParse(returnDaysStr)
            : null;

        final replacementDaysStr = _cleanString(productMap['Replacement']);
        final replacementDays = replacementDaysStr != null
            ? int.tryParse(replacementDaysStr)
            : null;

        final cancellationChargeStr = _cleanString(
          productMap['Cancellation_Charge'],
        );
        final cancellationCharge = cancellationChargeStr != null
            ? _parsePrice(cancellationChargeStr)
            : null;

        // Calculate total stock from variants if available, otherwise use product stock
        int totalStock = 0;

        // Process variants to calculate total stock
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

            // Process variant images as array
            final variantImageField =
                _cleanString(variant['Images']) ??
                _cleanString(variant['Image']);
            final variantImages = <String>[];
            if (variantImageField != null && variantImageField.isNotEmpty) {
              variantImages.addAll(
                variantImageField
                    .split(' ')
                    .map((img) => img.trim())
                    .where((img) => img.isNotEmpty),
              );
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

            // Extract variant name - check multiple possible field names
            String variantName = '';

            // Try all possible variant name field variations
            final possibleVariantNameFields = [
              'Variant_Name',
              'VariantName',
              'variant_name',
              'variantname',
              'VARIANT_NAME',
              'VARIANTNAME',
              'Variant Name',
              'variant name',
              'VARIANT NAME',
              'Name',
              'name',
              'NAME',
              'Title',
              'title',
              'TITLE',
              'Variant_Title',
              'VariantTitle',
              'variant_title',
              'varianttitle',
            ];

            for (final fieldName in possibleVariantNameFields) {
              final value = _cleanString(variant[fieldName]);
              if (value != null && value.isNotEmpty) {
                variantName = value;

                break;
              }
            }

            if (variantName.isEmpty) {
              variantName = 'Unnamed Variant';
            }

            // Extract attributes from variant data
            final attrs = _extractDynamicAttributes(variant);

            variantsList.add({
              'variantId':
                  _cleanString(variant['Variant_ID']) ??
                  _cleanString(variant['VariantID']) ??
                  '',
              'name': variantName,
              'price': variantPrice,
              'basePrice': price,
              'priceModifier': priceModifier,
              'stockQuantity': variantStock,
              'attributes': attrs,
              'images': variantImages,
            });
          }
        } else {
          // No variants, use product-level stock
          totalStock = _parseInt(productMap['Stock Quantity']);
        }

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
          'variants': variantsList,
          'hasVariants': variantsList.isNotEmpty,
          'returnDays': returnDays,
          'replacementDays': replacementDays,
          'cancellationCharge': cancellationCharge,
        };

        // Check if product already exists
        if (existingProductMap.containsKey(pid)) {
          // Update existing product
          final existingDoc = existingProductMap[pid]!;
          await existingDoc.reference.update(productData);
        } else {
          // Add new product
          await FirebaseFirestore.instance
              .collection('products')
              .add(productData);
        }
      }
    } catch (e) {
      debugPrint("❌ Upload failed: $e");
      rethrow;
    }
  }

  Future<void> loadOrders() async {
    await loadOrdersFromFirestore();
  }

  Future<void> loadOrdersFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        debugPrint("User not logged in!");
        return;
      }

      debugPrint("🔍 Current user ID: $user");
      debugPrint(
        "🔍 Attempting to load orders from 'user_orders' collection...",
      );

      // Get all orders and filter by sellerId in items array
      final QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('user_orders')
          .get(); // Get all orders first, then filter

      debugPrint(
        "🔍 Raw query returned ${orderSnapshot.docs.length} documents",
      );

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
                // Extract variant details if available
                String variantName = '';
                Map<String, String> variantAttributes = {};

                debugPrint(
                  "🔍 Order item keys: ${item.keys.toList()}, Item data: $item",
                );

                // Try different possible variant field names
                final variantData =
                    item['variant'] ??
                    item['variantName'] ??
                    item['selectedVariant'] ??
                    item['selectedVariantName'];

                if (variantData != null) {
                  if (variantData is Map<String, dynamic>) {
                    final variant = variantData;
                    variantName =
                        variant['name']?.toString() ??
                        variant['variantName']?.toString() ??
                        '';
                    if (variant['attributes'] is Map<String, dynamic>) {
                      final attrs =
                          variant['attributes'] as Map<String, dynamic>;
                      attrs.forEach((key, value) {
                        variantAttributes[key] = value?.toString() ?? '';
                      });
                    }
                  } else if (variantData is String) {
                    variantName = variantData.toString();
                  }
                } else {
                  // First, try to find the variant name from direct fields
                  final variantNameCandidates = [
                    'variantName',
                    'variant_name',
                    'selectedVariant',
                    'selected_variant',
                    'selectedVariantName',
                    'selected_variant_name',
                    'variantTitle',
                    'variant_title',
                  ];

                  for (final fieldName in variantNameCandidates) {
                    if (item.containsKey(fieldName) &&
                        item[fieldName] != null) {
                      variantName = item[fieldName].toString();
                      debugPrint(
                        "🔍 Found variant name from field '$fieldName': $variantName",
                      );
                      break;
                    }
                  }

                  // Then, extract variant attributes from other fields
                  item.forEach((key, value) {
                    final lowerKey = key.toString().toLowerCase();

                    // Skip variant name fields - they should only be used for variantName
                    if (lowerKey == 'variantname' ||
                        lowerKey == 'variant_name' ||
                        lowerKey == 'selectedvariant' ||
                        lowerKey == 'selected_variant' ||
                        lowerKey == 'selectedvariantname' ||
                        lowerKey == 'selected_variant_name' ||
                        lowerKey == 'varianttitle' ||
                        lowerKey == 'variant_title') {
                      return; // Skip adding to attributes
                    }

                    // Now check for actual variant attributes
                    if (lowerKey.contains('color') ||
                        lowerKey.contains('size') ||
                        lowerKey.contains('storage') ||
                        lowerKey.contains('attribute')) {
                      if (!lowerKey.startsWith('variant_id') &&
                          !lowerKey.startsWith('variantid')) {
                        variantAttributes[key] = value?.toString() ?? '';
                        debugPrint("🔍 Found variant attribute: $key = $value");
                      }
                    }
                  });
                }

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
                  'variantName': variantName,
                  'variantAttributes': variantAttributes,
                };

                filteredOrders.add(Order.fromFirestore(orderData));
                debugPrint(
                  "🔍 Found order item for seller: ${item['productName']}",
                );
              } catch (e) {
                debugPrint("❌ Error parsing order item: $e");
                debugPrint("❌ Problematic item data: $item");
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

      debugPrint(
        "✅ Loaded ${orders.length} orders from Firestore for current seller",
      );

      // Debug: debugPrint first few orders
      for (int i = 0; i < orders.length && i < 3; i++) {
        final order = orders[i];
        debugPrint(
          "🔍 Order $i: ${order.orderId} - ${order.productName} - ${order.status}",
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to load orders from Firestore: $e");

      // Test basic collection access
      try {
        debugPrint("🔍 Testing basic collection access...");
        final testSnapshot = await FirebaseFirestore.instance
            .collection('user_orders')
            .limit(1)
            .get();
        debugPrint(
          "🔍 Basic collection test returned ${testSnapshot.docs.length} docs",
        );
        if (testSnapshot.docs.isNotEmpty) {
          debugPrint(
            "🔍 Sample document structure: ${testSnapshot.docs.first.data()}",
          );
        }
      } catch (testError) {
        debugPrint("❌ Basic collection test failed: $testError");
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
                      debugPrint("❌ Upload failed: $e");
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
    // Get the best image to display (use first variant image if available)
    String? displayImage;
    if (product.variants.isNotEmpty) {
      // Try to get image from first variant that has one
      for (final variant in product.variants) {
        if (variant.images.isNotEmpty) {
          displayImage = variant.images.first;
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
                  errorBuilder: (_, _, _) => Container(
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
            // Display return/replacement/cancellation info
            if (product.returnDays != null ||
                product.replacementDays != null ||
                product.cancellationCharge != null)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (product.returnDays != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue[300]!,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Return: ${product.returnDays}d',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                    if (product.replacementDays != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.green[300]!,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Replace: ${product.replacementDays}d',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[800],
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                    if (product.cancellationCharge != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.orange[300]!,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Cancel: ₹${product.cancellationCharge!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
          if (variant.images.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                variant.images.first,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
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
            child: Text(
              variant.name.isNotEmpty ? variant.name : 'Unnamed Variant',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Text(
            '₹${variant.price.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    return StockTab(products: products);
  }

  Widget _buildOrdersTab() {
    return OrdersTab(orders: orders, onRefresh: loadOrders);
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
