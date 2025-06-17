import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up
  Future<String?> signUpUser({
    required String name,
    required String email,
    required String password,
    required String mobile,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'mobile': mobile,
        'createdAt': Timestamp.now(),
      });

      return null; // success
    } catch (e) {
      print('Firebase SignUp error: $e');
      return e.toString(); // return error message
    }
  }

  // Login
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } catch (e) {
      return e.toString(); // return error message
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user ID
  String? getCurrentUID() {
    return _auth.currentUser?.uid;
  }

  // Get user details
  Future<DocumentSnapshot> getUserDetails() async {
    final uid = getCurrentUID();
    return _firestore.collection('users').doc(uid).get();
  }

  Future<String?> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // success
    } catch (e) {
      print('Login error: $e');
      return e.toString(); // return error string
    }
  }
}
