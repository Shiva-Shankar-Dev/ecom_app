import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../colorPallete/color_pallete.dart';
import '../../services/auth.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  void loginHandle() async {
    String? result = await _authService.loginUser(
      email: emailController.text,
      password: passwordController.text,
    );
    if (result == null) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/home');
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(5.0),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.shopping_cart, size: 60),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Text(
                    "Welcome to ECOM-APP",
                    style: TextStyle(
                      fontSize: 23,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "Login to your account with your Email and Password! "
                    "If you need to use mobile number use mobile number instead!",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AuthTextField(
                          hintText: 'Email',
                          controller: emailController,
                        ),
                        AuthTextFieldForPassword(
                          hintText: 'Password',
                          controller: passwordController,
                          hide: true,
                          onSubmitted: (val) {
                            loginHandle();
                          },
                        ),
                        SizedBox(height: 20),
                        AuthButton(
                          hintText: 'Login',
                          onPressed: () {
                            loginHandle();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13.0,
                    vertical: 2.0,
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 10,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: ColorPallete.color1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          text: 'Login using ',
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: 'Mobile instead?',
                              style: TextStyle(
                                color: ColorPallete.color1,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushNamed(context, '/mobile');
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 13.0, vertical: 2.0),
                  width: MediaQuery.of(context).size.width - 10,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorPallete.color1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: ColorPallete.color1,
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
    // TRY THIS: Try changing the color here to a specific color (to
  }
}
