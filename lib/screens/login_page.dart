import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:ecom_app/services/auth.dart';
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
  final AuthService _authService = AuthService();
  void loginhandle() async {
    String? result = await _authService.signInUser(
      email: emailController.text,
      password: passwordController.text,
    );
    if (result == null) {
      Navigator.pushNamed(context, '/home');
    } else {
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
      body: Container(
        //decoration: BoxDecoration(image: DecorationImage(image: AssetImage('./assets/background.jpg'), fit: BoxFit.cover)),
        height: double.infinity,
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30),
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
                            AuthButton(
                              hintText: 'Login',
                              onPressed: () {
                                loginhandle();
                              },
                            ),
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
                              style: TextStyle(color: colorPallete.color1),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.pushNamed(context, '/mobile');
                                },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 0),
                    ],
                  ),
                ),

                Container(
                  margin: EdgeInsets.only(top: 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(color: colorPallete.color1),
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
      // This trailing comma makes auto-formatting nicer for build methods.
    );
    // TRY THIS: Try changing the color here to a specific color (to
  }
}
