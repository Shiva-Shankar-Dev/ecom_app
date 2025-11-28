import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ecom_app/widgets/auth_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ecom_app/services/auth.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';

import '../models/product.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  final AuthService _authService = AuthService();

  List<Product> products = [];

  //reading excel
  Future<List<Map<String, dynamic>>> readExcelFromHive() async {
    final box = Hive.box('filesBox');
    final Uint8List? bytes = box.get('excelFile');

    if (bytes == null) {
      print("No Excel file found in Hive.");
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
  }

  // Load products directly from Firestore since that's where the actual products are stored
  Future<void> loadProducts() async {
    await loadProductsFromFirestore();
    print("Products loaded from Firestore: ${products.length}");
  }

  Future<void> loadProductsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        print("User not logged in!");
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
            price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
            description: data['description']?.toString() ?? 'No description',
            deliveryTime: data['deliveryTime']?.toString() ?? 'N/A',
            stockQuantity: data['stockQuantity'] ?? 0,
            images: List<String>.from(data['images'] ?? []),
            keywords: List<String>.from(data['keywords'] ?? []),
          );
        }).toList();
      });

      print("✅ Loaded ${products.length} products from Firestore");
    } catch (e) {
      print("❌ Failed to load products from Firestore: $e");
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
      print("File picking canceled or failed.");
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

  Future<void> uploadExcelProductsToFirestore(List<Map<String, dynamic>> excelData,) async {
    try {
      final user = FirebaseAuth.instance.currentUser?.uid;
      if (user == null) {
        print("User not logged in!");
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
        final description = productMap['Description']?.toString() ?? 'No Description';
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
          'keywords' : keywords,
          'images': images,
        };

        // Check if product already exists
        if (existingProductMap.containsKey(pid)) {
          // Update existing product
          final existingDoc = existingProductMap[pid]!;
          await existingDoc.reference.update(productData);
          updatedCount++;
          print("✅ Product '$name' (PID: $pid) updated in Firestore.");
        } else {
          // Add new product
          await FirebaseFirestore.instance.collection('products').add(productData);
          addedCount++;
          print("✅ Product '$name' (PID: $pid) added to Firestore.");
        }
      }

      print(
        "✅ Upload complete! Added: $addedCount, Updated: $updatedCount products.",
      );
    } catch (e) {
      print("❌ Upload failed: $e");
      rethrow;
    }
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
                print("❌ Upload failed: $e");
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
                                  errorBuilder: (_, __, ___) =>
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
