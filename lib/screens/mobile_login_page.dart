// ignore_for_file: use_build_context_synchronously

import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  final mobileController = TextEditingController();
  bool _isSending = false;

  void _sendOtp() async {
    final phone = mobileController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid phone number with +countrycode')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in flow (optional)
          debugPrint("Auto verification completed");
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Verification failed: ${e.code} - ${e.message}");
          String errorMessage = e.message ?? 'Verification failed';

          // Handle specific reCAPTCHA errors
          if (e.code == 'invalid-app-credential') {
            errorMessage =
                'App verification failed. Please check your Firebase configuration.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many requests. Please try again later.';
          } else if (e.code == 'captcha-check-failed') {
            errorMessage = 'reCAPTCHA verification failed. Please try again.';
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
          setState(() => _isSending = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint("OTP sent successfully");
          setState(() => _isSending = false);
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: {'phone': phone, 'verificationId': verificationId},
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint("Auto retrieval timeout");
          setState(() => _isSending = false);
        },
        timeout: Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint("Error sending OTP: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP. Please try again.')),
      );
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: ColorPallete.color4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your Mobile',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 50),
              TextField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey, width: 3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: ColorPallete.color1,
                      width: 3,
                    ),
                  ),
                  hintText: 'Mobile (e.g., +1234567890)',
                  helperText: 'Include country code (+91 for India)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ColorPallete.color1, ColorPallete.color2],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(320, 55),
                    shadowColor: ColorPallete.color4,
                    backgroundColor: ColorPallete.color4,
                  ),
                  onPressed: _isSending ? null : _sendOtp,
                  child: _isSending
                      ? CircularProgressIndicator()
                      : Text(
                          'Send OTP',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
