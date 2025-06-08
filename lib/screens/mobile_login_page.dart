import 'package:ecom_app/widgets/auth_text_field.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({Key? key}) : super(key: key);

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  bool _isSending = false;
  final mobileController = TextEditingController();
  void _sendOtp() async {
    final phone = mobileController.text.trim();
    if (phone.isEmpty || !phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid phone number with country code'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);

      Navigator.pushNamed(context, '/otp', arguments: {'phone': phone});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }

    setState(() {
      _isSending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  'Enter your Mobile',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Mobile',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white70, width: 3),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.greenAccent,
                        width: 3,
                      ),
                    ),
                  ),
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                ),
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.greenAccent, Colors.green],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(280, 55),
                    shadowColor: Colors.transparent,
                    backgroundColor: Colors.transparent,
                  ),
                  child: _isSending
                      ? CircularProgressIndicator()
                      : Text(
                          'Send OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
