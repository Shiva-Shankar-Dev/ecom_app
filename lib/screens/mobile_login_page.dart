import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({Key? key}) : super(key: key);

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

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-sign in flow (optional)
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
      },
      codeSent: (String verificationId, int? resendToken) {
        Navigator.pushNamed(context, '/otp', arguments: {
          'phone': phone,
          'verificationId': verificationId,
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(foregroundColor: Colors.white, backgroundColor: colorPallete.color4,),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your Mobile', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
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
                    borderSide: BorderSide(color: colorPallete.color1, width: 3),
                  ),
                  hintText: 'Mobile',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorPallete.color1, colorPallete.color2],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(320, 55),
                    shadowColor: colorPallete.color4,
                    backgroundColor: colorPallete.color4,
                  ),
                  onPressed: _isSending ? null : _sendOtp,
                  child: _isSending
                      ? CircularProgressIndicator()
                      : Text('Send OTP', style: TextStyle(color: Colors.white,fontSize: 18)),
                ),

              ),
              SizedBox(height: 50,)
            ],
          ),
        ),
      ),
    );
  }
}
