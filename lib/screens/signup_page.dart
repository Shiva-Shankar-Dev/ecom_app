import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

var uname = '';
var pass = '';

class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => _SignUpPage();
}

class _SignUpPage extends State<SignUpPage> {
  Future<void> signUp(String username, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: username,
        password: password,
      );
      print("Sign up successful");
    } catch (e) {
      print("Error: $e");
    }
  }

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sign Up',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                width: 300,
                child: TextFormField(
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    uname = value;
                    return null;
                  },
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 300,
                child: TextFormField(
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    pass = value;
                    return null;
                  },
                ),
              ),
              SizedBox(height: 36),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    signUp(uname, pass);
                    Navigator.pushNamed(context, '/home');
                  }
                },
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
