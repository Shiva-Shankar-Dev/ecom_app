import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dotted_border/dotted_border.dart';
import 'package:ecom_app/widgets/auth_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ecom_app/services/auth.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';

class Product {
  final String title, description, deliveryTime, ratings, pid;
  final double price;
  final List<String> images;
  final Map<String, dynamic> extraFields;

  Product({
    required this.title,
    required this.images,
    required this.description,
    required this.price,
    required this.deliveryTime,
    required this.ratings,
    required this.extraFields,
    required this.pid,
  });
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  AuthService _authService = AuthService();

  List<Product> products = [];
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

  double _parsePrice(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is DateTime) return 0.0; // Don't treat dates as price

    final str = value.toString().replaceAll(RegExp(r'[^\d.]'), '');

    return double.tryParse(str) ?? 0.0;
  }

  Future<void> loadProducts() async {
    final excelData = await readExcelFromHive();
    print("Excel rows loaded: $excelData");

    setState(() {
      products = excelData.map((productMap) {
        // Extract known fields
        final title = productMap['Title']?.toString() ?? 'No Title';
        final description = productMap['Description']?.toString() ?? '';
        final price = _parsePrice(productMap['Price']);
        final deliveryTime = productMap['DeliveryTime']?.toString() ?? 'N/A';
        final ratings = productMap['Rating']?.toString() ?? 'No Ratings';

        // Split images by comma if multiple provided
        final imageField = productMap['Images']?.toString() ?? '';
        final images = imageField.split(',').map((e) => e.trim()).toList();

        // Create extraFields by filtering out known ones
        final extraFieldsRaw = Map<String, dynamic>.from(productMap)
          ..remove('Title')
          ..remove('Images')
          ..remove('Description')
          ..remove('Price')
          ..remove('DeliveryTime')
          ..remove(
            'Ratings',
          ) // <- typo fix: your code says 'reviews', but Excel uses 'Ratings'
          // Optional: remove PID if you already extract it below
          ..remove('PID');

        final extraFields = extraFieldsRaw.map((key, value) {
          return MapEntry(key, value?.toString() ?? '');
        });
        final String pid = productMap['PID']?.toString() ?? 'No product ID';
        return Product(
          title: title,
          description: description,
          price: price,
          deliveryTime: deliveryTime,
          ratings: ratings,
          images: images,
          extraFields: extraFields,
          pid: pid,
        );
      }).toList();
    });

    print("Products after parsing: $products");
  }

  Future<void>? uploadProductsToFirestore() async {
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

      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        final cleanedExtraFields =
            Map<String, dynamic>.from(product.extraFields)..removeWhere(
              (key, value) => value == null || value.toString().isEmpty,
            );

        final productData = {
          'sellerId': user,
          'pid': product.pid,
          'title': product.title,
          'images': product.images,
          'ratings': product.ratings,
          'price': product.price,
          'delivery': product.deliveryTime,
          if (cleanedExtraFields.isNotEmpty)
            'extraFields': cleanedExtraFields, // Only add if not empty
        };

        // Check if product already exists
        if (existingProductMap.containsKey(product.pid)) {
          // Update existing product
          final existingDoc = existingProductMap[product.pid]!;
          await existingDoc.reference.update(productData);
          updatedCount++;
          print(
            "✅ Product '${product.title}' (PID: ${product.pid}) updated in Firestore.",
          );
        } else {
          // Add new product
          await FirebaseFirestore.instance
              .collection('products')
              .add(productData);
          addedCount++;
          print(
            "✅ Product '${product.title}' (PID: ${product.pid}) added to Firestore.",
          );
        }
      }

      print(
        "✅ Upload complete! Added: $addedCount, Updated: $updatedCount products.",
      );
    } catch (e) {
      print("❌ Upload failed: $e");
    }
  }

  Future<void> pickAndStoreExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.bytes != null) {
      final box = await Hive.openBox('filesBox');
      await box.put('excelFile', result.files.single.bytes);
      print("Excel file saved to Hive.");
      await loadProducts(); // Reload products after storing
    } else {
      print("File picking canceled or failed.");
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
              await pickAndStoreExcel();
              await loadProducts();

              try {
                await uploadProductsToFirestore();
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
                    Lottie.asset('assets/post.json', width: 300, height: 300),
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
                      onPressed: () {
                        pickAndStoreExcel().then((_) {
                          loadProducts().then((_) {
                            uploadProductsToFirestore();
                          });
                        });
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
                                      product.title,
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
                                        Text(
                                          '${product.ratings}',
                                          style: TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
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
