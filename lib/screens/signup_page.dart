import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_button.dart';

var uname = '';
var pass = '';

class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => _SignUpPage();
}

class _SignUpPage extends State<SignUpPage> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  void dispose() {
    super.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    mobileController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          alignment: Alignment.center,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sign Up.',
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 27),
                Form(
                  child: Column(
                    children: [
                      AuthTextField(
                        hintText: 'User name',
                        controller: fullNameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Username cannot be empty';
                          }
                          return null;
                        },
                      ),
                      AuthTextField(
                        hintText: 'Email',
                        controller: emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email cannot be empty';
                          }
                          return null;
                        },
                      ),
                      AuthTextField(
                        hintText: 'Password',
                        controller: passwordController,
                        hide: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password cannot be empty';
                          }
                          return null;
                        },
                      ),
                      AuthTextField(
                        hintText: 'Mobile',
                        controller: mobileController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Mobile cannot be empty';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),
                AuthButton(
                  hintText: 'Sign Up',
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pushNamed(context, '/home');
                    }
                  },
                ),
                SizedBox(height: 36),
                RichText(
                  text: TextSpan(
                    text: 'Already have an account? ',
                    children: [
                      TextSpan(
                        text: 'Login',
                        style: TextStyle(color: Colors.greenAccent),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pushNamed(context, '/');
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
