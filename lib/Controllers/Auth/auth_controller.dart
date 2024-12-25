import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthController {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Signs in a user using email and password
  Future<void> signInWithEmailAndPassword({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate using Firebase
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Login successful
      debugPrint('Login successful for user: ${userCredential.user!.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: $e');

      // Handle FirebaseAuth-specific errors
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found for the provided email.');
        case 'wrong-password':
          throw Exception('Incorrect password. Please try again.');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  /// Registers a new user using email and password
  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      debugPrint('User registered successfully: ${userCredential.user!.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: $e');

      // Handle FirebaseAuth-specific errors
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception(
              'This email is already in use. Please use a different email.');
        case 'weak-password':
          throw Exception(
              'Password is too weak. Please use a stronger password.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        default:
          throw Exception('Registration failed: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error during registration: $e');
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      debugPrint('User signed out successfully.');
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw Exception('Failed to sign out. Please try again.');
    }
  }

  /// Sends a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to: $email');
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      throw Exception('Failed to send password reset email. Please try again.');
    }
  }

  /// Retrieves the current authenticated user (if any)
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }
}
