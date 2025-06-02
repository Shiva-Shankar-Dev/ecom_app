import 'package:flutter/material.dart';

class MobileLoginPage extends StatefulWidget {
  @override
  State<MobileLoginPage> createState() => _MobileLoginPage();
}

class _MobileLoginPage extends State<MobileLoginPage> {
  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 300,
                child: Text(
                  'Login using Mobile Number',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 32),
              SizedBox(
                width: 300,
                child: TextFormField(
                  decoration: InputDecoration(labelText: 'Mobile'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(onPressed: () {}, child: Text('Get OTP')),
            ],
          ),
        ),
      ),
    );
  }
}
