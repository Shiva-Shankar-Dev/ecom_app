import 'package:ecom_app/services/firebase_auth.dart';
import 'package:ecom_app/widgets/auth_button.dart';
import 'package:ecom_app/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import '../screens/otp_page.dart';

class MobileLoginPage extends StatefulWidget {
  @override
  State<MobileLoginPage> createState() => _MobileLoginPage();
}

class _MobileLoginPage extends State<MobileLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final mobileController = TextEditingController();
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
              AuthTextField(hintText: 'Mobile', controller: mobileController),
              SizedBox(height: 32),
              AuthButton(
                hintText: 'Get OTP',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    String number = mobileController.text.trim();

                    // Clean it up (India example)
                    number = number.replaceAll(
                      RegExp(r'\D'),
                      '',
                    ); // remove non-digits
                    if (number.startsWith('0')) {
                      number = number.substring(1);
                    }

                    final phone = '+91$number'; // E.164 format
                    print('Sending OTP to $phone');
                    print("Raw input: ${mobileController.text}");
                    print("Parsed phone: $phone");

                    verifyPhone(
                      phoneNumber: phone,
                      onCodeSent: (verificationId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OtpPage(verificationId: verificationId),
                          ),
                        );
                      },
                      onFailed: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("OTP Send Failed: $error")),
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
