import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up
  Future<String?> signUpUser({
    required String name,
    required String email,
    required String password,
    required String mobile,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('sellers').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'mobile': mobile,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Login
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign out
  Future<void> signOut() => _auth.signOut();

  // Get current user ID
  String? getCurrentUID() => _auth.currentUser?.uid;

  // Get current user's username/name from Firestore
  Future<String?> getCurrentUsername() async {
    try {
      final uid = getCurrentUID();
      if (uid == null) return null;

      final doc = await _firestore.collection('sellers').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['name'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all current user details
  Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      final uid = getCurrentUID();
      if (uid == null) return null;

      final doc = await _firestore.collection('sellers').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
