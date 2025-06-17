import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:excel/excel.dart';
import 'package:firebase_storage/firebase_storage.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ecom_app/services/auth.dart';
class Product {
  final String title, image, description, deliveryTime, reviews;
  final double price;

  Product({
    required this.title,
    required this.image,
    required this.description,
    required this.price,
    required this.deliveryTime,
    required this.reviews,
  });
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  String? _excelContent;
  AuthService _authService = AuthService();
  List<Product> products = [];
  void pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      PlatformFile pickedFile = result.files.first;

      if (pickedFile.path != null) {
        File fileToUpload = File(pickedFile.path!);

        try {
          final storageRef = FirebaseStorage.instance.ref().child("uploads/${pickedFile.name}");
          final uploadTask = await storageRef.putFile(fileToUpload);
          final downloadUrl = await uploadTask.ref.getDownloadURL();

          print("File uploaded! URL: $downloadUrl");

          // Read Excel
          Uint8List bytes = await fileToUpload.readAsBytes();
          var excel = Excel.decodeBytes(bytes);

          List<Product> tempProducts = [];

          for (var table in excel.tables.keys) {
            var sheet = excel.tables[table]!;
            for (int i = 1; i < sheet.maxRows; i++) {
              var row = sheet.row(i);
              tempProducts.add(Product(
                title: row[0]?.value.toString() ?? "",
                image: row[1]?.value.toString() ?? "",
                description: row[2]?.value.toString() ?? "",
                price: double.tryParse(row[3]?.value.toString() ?? "0") ?? 0.0,
                deliveryTime: row[4]?.value.toString() ?? "",
                reviews: row[5]?.value.toString() ?? "",
              ));
            }
          }

          setState(() {
            products = tempProducts;
          });
        } catch (e) {
          print("Upload or Excel parsing failed! $e");
        }
      }
    } else {
      print("No file selected");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Home Page"),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(icon: Icon(Icons.add,),
            tooltip: 'Add products',
            onPressed: (){
              pickFile();
            },
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: (){
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap:(){
                Navigator.pop(context);
              }
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded),
              title: Text('Sign Out'),
              onTap: (){
                _authService.signOut();
                Navigator.pushNamed(context, '/login');
              },
            )
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: products.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Products', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
              Text('There are no products available to display!', style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
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
                          Image.network(product.image, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.image),),
                          SizedBox(width: 15,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.orange, size: 12,),
                                  SizedBox(width: 5,),
                                  Text('${product.reviews}', style: TextStyle(color: Colors.orange,),),
                                ],
                              ),
                              Text('${product.price}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),),
                              Text('Delivery Time | ${product.deliveryTime}', style: TextStyle(fontSize: 12),)
                            ],
                          )
                        ],
                      ),
                    )
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
