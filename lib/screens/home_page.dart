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

          return Product(
            pid: data['pid']?.toString() ?? 'No product ID',
            name: data['name']?.toString() ?? 'No name',
            brand: data['brand']?.toString() ?? 'No brand',
            category: data['category']?.toString() ?? 'No category',
            price: (data['price'] is num)
                ? (data['price'] as num).toDouble()
                : 0.0,
            description: data['description']?.toString() ?? 'No description',
            deliveryTime: data['deliveryTime']?.toString() ?? 'N/A',
            stockQuantity: data['stockQuantity'] ?? 0,
            images: List<String>.from(data['images'] ?? []),
            keywords: List<String>.from(data['keywords'] ?? []),
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
      }
    } else {
      debugPrint("File picking canceled or failed.");
    }
  }

  Future<List<Map<String, dynamic>>> processExcelFile(Uint8List bytes) async {
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
        // Extract known fields
        final pid = productMap['PID']?.toString() ?? 'No product ID';
        final name = productMap['Name']?.toString() ?? 'No Name';
        final brand = productMap['Brand']?.toString() ?? 'No Brand';
        final category = productMap['Category']?.toString() ?? 'No Category';
        final price = _parsePrice(productMap['Price']);
        final description =
            productMap['Description']?.toString() ?? 'No Description';
        final deliveryTime = productMap['Delivery Time']?.toString() ?? 'N/A';
        final stockQuantity = _parsePrice(productMap['Stock Quantity']);
        final imageField = productMap['Images']?.toString() ?? '';
        final images = imageField.split(',').map((e) => e.trim()).toList();
        final keywordsList = productMap['Keywords']?.toString() ?? '';
        final keywords = keywordsList.split(',').map((e) => e.trim()).toList();

        final productData = {
          'sellerId': user,
          'pid': pid,
          'name': name,
          'brand': brand,
          'category': category,
          'price': price,
          'description': description,
          'deliveryTime': deliveryTime,
          'stockQuantity': stockQuantity,
          'keywords': keywords,
          'images': images,
        };

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
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20, top: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              product.images.first,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.image),
                            ),
                            SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.orange,
                                      size: 12,
                                    ),
                                    SizedBox(width: 5),
                                  ],
                                ),
                                Text(
                                  '\$${product.price}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Delivery Time | ${product.deliveryTime}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildStockTab() {
    return products.isEmpty
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
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: product.stockQuantity > 10
                              ? Colors.green
                              : product.stockQuantity > 0
                              ? Colors.orange
                              : Colors.red,
                          child: Icon(Icons.inventory, color: Colors.white),
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Brand: ${product.brand}'),
                            Text('Category: ${product.category}'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${product.stockQuantity}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: product.stockQuantity > 10
                                    ? Colors.green
                                    : product.stockQuantity > 0
                                    ? Colors.orange
                                    : Colors.red,
                              ),
                            ),
                            Text('in stock', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
                if(!mounted) return;
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
        child: products.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Lottie.asset('assets/post.json', width: 200, height: 200),
                    SizedBox(height: 20),
                    Text(
                      'No Products Found',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 10),

                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20, top: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.network(
                                  product.images.first,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Icon(Icons.image),
                                ),
                                SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.orange,
                                          size: 12,
                                        ),
                                        SizedBox(width: 5),
                                      ],
                                    ),
                                    Text(
                                      '${product.price}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Delivery Time | ${product.deliveryTime}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
