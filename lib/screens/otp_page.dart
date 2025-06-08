import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpPage extends StatefulWidget {
  final String phone;
  const OtpPage({Key? key, required this.phone}) : super(key: key);

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phone,
        token: otp,
        type: OtpType.sms,
      );

      if (res.user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Verification failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }

    setState(() {
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Enter OTP\n',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            Text('sent to ${widget.phone}'),
            SizedBox(height: 28),
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'OTP',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white70, width: 3),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.greenAccent, width: 3),
                ),
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
                onPressed: _isVerifying ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(320, 55),
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                ),
                child: _isVerifying
                    ? CircularProgressIndicator()
                    : Text(
                        'Verify',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
