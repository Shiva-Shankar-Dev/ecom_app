import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

Future<void> signInUser(
  String email,
  String password,
  BuildContext context,
) async {
  try {
    // ignore: unused_local_variable
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Successful login
    Navigator.pushReplacementNamed(context, '/home'); // Update with your route
  } on FirebaseAuthException catch (e) {
    String message = '';
    if (e.code == 'user-not-found') {
      message = 'No user found for that email.';
    } else if (e.code == 'wrong-password') {
      message = 'Wrong password provided.';
    } else {
      message = 'An error occurred: ${e.message}';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

FirebaseAuth auth = FirebaseAuth.instance;

void verifyPhone({
  required String phoneNumber,
  required Function(String verificationId) onCodeSent,
  required Function(String error) onFailed,
}) async {
  await FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    timeout: const Duration(seconds: 60),
    verificationCompleted: (PhoneAuthCredential credential) async {
      await FirebaseAuth.instance.signInWithCredential(credential);
    },
    verificationFailed: (FirebaseAuthException e) {
      onFailed(e.message ?? "Verification failed");
    },
    codeSent: (String verificationId, int? resendToken) {
      onCodeSent(verificationId);
    },
    codeAutoRetrievalTimeout: (String verificationId) {},
  );
}

Future<void> signInWithOTP(String smsCode, String verificationId) async {
  PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: smsCode,
  );

  try {
    await FirebaseAuth.instance.signInWithCredential(credential);
    // Navigate or show success
  } catch (e) {
    print("OTP verification failed: $e");
  }
}
