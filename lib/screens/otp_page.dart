import 'package:ecom_app/services/firebase_auth.dart';
import 'package:ecom_app/widgets/auth_button.dart';
import 'package:ecom_app/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';

class OtpPage extends StatefulWidget {
  final dynamic verificationId;

  const OtpPage({super.key, required this.verificationId});

  @override
  _OtpPageState createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the OTP',
              style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
            ),
            Text('The otp has been sent to your device'),
            AuthTextField(hintText: 'OTP', controller: otpController),
            AuthButton(
              hintText: 'Confirm',
              onPressed: () {
                signInWithOTP(otpController.text, widget.verificationId);
              },
            ),
          ],
        ),
      ),
    );
  }
}
