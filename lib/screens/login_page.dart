import 'package:ecom_app/widgets/auth_button.dart';
import 'package:ecom_app/widgets/auth_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPage();
}

class _LoginPage extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(0, 150, 0, 100),
                child: Column(
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          AuthTextField(
                            hintText: 'Email',
                            controller: emailController,
                          ),
                          AuthTextField(
                            hintText: 'Password',
                            controller: passwordController,
                            hide: true,
                          ),
                          SizedBox(height: 20),
                          AuthButton(hintText: 'Login', onPressed: () {}),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),
                    SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: 'Login using ',
                        children: [
                          TextSpan(
                            text: 'Mobile instead?',
                            style: TextStyle(color: Colors.greenAccent),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, '/mobile');
                              },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),

              Container(
                margin: EdgeInsets.only(top: 110),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Don\'t have an account? ',
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(color: Colors.greenAccent),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushNamed(context, '/signup');
                              },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
    // TRY THIS: Try changing the color here to a specific color (to
  }
}
