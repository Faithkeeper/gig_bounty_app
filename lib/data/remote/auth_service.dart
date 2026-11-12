import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_profile.dart';
import '../local/sqlite_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email, password, name, and role
  Future<UserProfile?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userProfile = UserProfile(
        uid: credential.user!.uid,
        email: email,
        fullName: fullName,
        role: role,
      );

      // Save user profile to Firestore 'users' collection
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userProfile.toMap());

      return userProfile;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Fetch user profile data from Firestore, falling back to the local cache.
  Future<UserProfile> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        await SqliteHelper.instance.cacheUserProfile(profile);
        return profile;
      }
    } catch (e) {
      debugPrint('Network fetch failed, falling back to local cache: $e');
    }

    final cachedProfile = await SqliteHelper.instance.getCachedUserProfile(uid);
    if (cachedProfile != null) {
      return cachedProfile;
    }

    throw Exception('No profile found online or in local cache.');
  }

  Future<void> updateUserProfile({
  required String uid,
  required String fullName,
  required String role,
}) async {
  try {
    await _firestore.collection('users').doc(uid).update({
      'fullName': fullName,
      'role': role,
    });
  } catch (e) {
    throw Exception('Failed to update profile: ${e.toString()}');
  }
}
}
