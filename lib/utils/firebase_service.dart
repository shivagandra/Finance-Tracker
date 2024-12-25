import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_tracker/models/budget_model.dart';
import 'package:finance_tracker/models/expense_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:typed_data';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Auth methods
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    String? profileImagePath,
  }) async {
    try {
      // 1. First create the user account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? imageUrl;

      // 2. If there's a profile image, upload it
      if (profileImagePath != null) {
        final String fileName =
            'profile_${credential.user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef =
            _storage.ref().child('profile_images/$fileName');

        UploadTask uploadTask;

        if (kIsWeb) {
          // For web platform
          final XFile imageFile = XFile(profileImagePath);
          final Uint8List imageBytes = await imageFile.readAsBytes();
          uploadTask = storageRef.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // For mobile platforms
          final File imageFile = File(profileImagePath);
          uploadTask = storageRef.putFile(imageFile);
        }

        // Wait for upload to complete and get URL
        final TaskSnapshot taskSnapshot = await uploadTask;
        imageUrl = await taskSnapshot.ref.getDownloadURL();
      }

      // 3. Create the user profile in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'profileImage': imageUrl,
        'defaultCurrency': 'USD',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } catch (e) {
      print('Error during registration: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Profile methods
  Future<Map<String, dynamic>> getUserProfile() async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    DocumentSnapshot doc =
        await _firestore.collection('users').doc(userId).get();
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore.collection('users').doc(userId).update(data);
  }

  // Future<String?> updateProfileImage() async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   final ImagePicker picker = ImagePicker();
  //   final XFile? image = await picker.pickImage(
  //     source: ImageSource.gallery,
  //     maxWidth: 1024,
  //     maxHeight: 1024,
  //     imageQuality: 85,
  //   );

  //   if (image == null) return null;

  //   return await _uploadProfileImage(File(image.path), userId);
  // }

  // Future<String> _uploadProfileImage(File imageFile, String userId) async {
  //   String fileName = 'profile_$userId.jpg';
  //   Reference ref = _storage.ref().child('profile_images/$fileName');

  //   try {
  //     await ref.delete();
  //   } catch (_) {}

  //   await ref.putFile(imageFile);
  //   return await ref.getDownloadURL();
  // }
  Future<String?> updateProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return null;

      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) throw Exception('User not authenticated');

      // Generate a unique filename
      final String fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          _storage.ref().child('profile_images/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        // Handle web platform
        final Uint8List imageBytes = await image.readAsBytes();
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // Handle mobile platforms
        final File imageFile = File(image.path);
        uploadTask = storageRef.putData(
          await imageFile.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for the upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Update user profile with new image URL
      await updateUserProfile({'profileImage': downloadUrl});

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Future<void> updateUserProfile(Map<String, dynamic> data) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   await _firestore.collection('users').doc(userId).update(data);
  // }

  // Expense methods
  Future<void> addExpense(ExpenseModel expense) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    String? imageUrl;
    if (expense.imagePath != null) {
      imageUrl = await _uploadExpenseImage(File(expense.imagePath!));
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .add({
      'amount': expense.amount,
      'category': expense.category,
      'description': expense.description,
      'date': expense.date,
      'imageUrl': imageUrl,
      'currency': expense.currency,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Add a new expense
  Future<void> addExpenseNew({
    required String description,
    required double amount,
    required String category,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('expenses').add({
      'description': description,
      'amount': amount,
      'category': category,
      'date': now.toIso8601String(),
      'currency': 'USD',
    });
  }

  Future<String> _uploadExpenseImage(File imageFile) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference ref = _storage.ref().child('expense_images/$fileName');
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  Stream<List<ExpenseModel>> getExpenses() {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              return ExpenseModel(
                id: doc.id,
                amount: data['amount'],
                category: data['category'],
                description: data['description'],
                date: data['date'],
                imagePath: data['imageUrl'],
                currency: data['currency'],
              );
            }).toList());
  }

  // Search Expenses methods
  // Future<List<ExpenseModel>> searchExpenses({
  //   String? query,
  //   String? category,
  //   String? currency,
  //   double? minAmount,
  //   double? maxAmount,
  //   DateTimeRange? dateRange,
  // }) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   Query expensesQuery =
  //       _firestore.collection('users').doc(userId).collection('expenses');

  //   if (category != null) {
  //     expensesQuery = expensesQuery.where('category', isEqualTo: category);
  //   }
  //   if (currency != null) {
  //     expensesQuery = expensesQuery.where('currency', isEqualTo: currency);
  //   }
  //   if (dateRange != null) {
  //     expensesQuery = expensesQuery
  //         .where('date',
  //             isGreaterThanOrEqualTo: dateRange.start.toIso8601String())
  //         .where('date', isLessThanOrEqualTo: dateRange.end.toIso8601String());
  //   }

  //   QuerySnapshot snapshot = await expensesQuery.get();

  //   return snapshot.docs.map((doc) {
  //     Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  //     return ExpenseModel.fromMap(data);
  //   }).where((expense) {
  //     if (minAmount != null && expense.amount < minAmount) return false;
  //     if (maxAmount != null && expense.amount > maxAmount) return false;
  //     if (query != null && query.isNotEmpty) {
  //       return expense.description
  //               .toLowerCase()
  //               .contains(query.toLowerCase()) ||
  //           expense.category.toLowerCase().contains(query.toLowerCase());
  //     }
  //     return true;
  //   }).toList();
  // }
  Future<List<ExpenseModel>> searchExpenses({
    String? query,
    String? category,
    String? currency,
    double? minAmount,
    double? maxAmount,
    DateTimeRange? dateRange,
  }) async {
    try {
      // Build Firestore query
      var querySnapshot = _firestore
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('expenses')
          .orderBy('date') // Order by date for better performance
          .limit(10); // Limit to 10 for pagination

      // Add filters based on user input
      if (query != null && query.isNotEmpty) {
        querySnapshot = querySnapshot
            .where('description', isGreaterThanOrEqualTo: query)
            .where('description', isLessThanOrEqualTo: '$query\uf8ff');
      }
      if (category != null && category.isNotEmpty) {
        querySnapshot = querySnapshot.where('category', isEqualTo: category);
      }
      if (currency != null && currency.isNotEmpty) {
        querySnapshot = querySnapshot.where('currency', isEqualTo: currency);
      }
      if (minAmount != null) {
        querySnapshot =
            querySnapshot.where('amount', isGreaterThanOrEqualTo: minAmount);
      }
      if (maxAmount != null) {
        querySnapshot =
            querySnapshot.where('amount', isLessThanOrEqualTo: maxAmount);
      }
      if (dateRange != null) {
        querySnapshot = querySnapshot
            .where('date', isGreaterThanOrEqualTo: dateRange.start)
            .where('date', isLessThanOrEqualTo: dateRange.end);
      }

      // Fetch documents from Firestore
      final snapshot = await querySnapshot.get();
      final expenses =
          snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();

      return expenses;
    } catch (e) {
      print("Error fetching expenses: $e");
      return [];
    }
  }

  Future<List<ExpenseModel>> searchExpensesProfileScreen(
      {required DateTimeRange dateRange}) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: dateRange.start)
        .where('date', isLessThanOrEqualTo: dateRange.end)
        .get();

    return querySnapshot.docs.map((doc) {
      return ExpenseModel.fromFirestore(doc);
    }).toList();
  }

  // Budget methods
  Future<void> setBudget(Budget budget) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .doc(budget.category)
        .set({
      'amount': budget.amount,
      'period': budget.period,
      'currency': budget.currency,
    });
  }

  Stream<List<Budget>> getBudgets() {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              return Budget(
                category: doc.id,
                amount: data['amount'],
                period: data['period'],
                currency: data['currency'],
                startDate: DateTime.now().toIso8601String(),
              );
            }).toList());
  }

  // Category methods
  Future<void> addCategory(String name, int color) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .add({
      'name': name,
      'color': color,
    });
  }

  Stream<List<String>> getCategories() {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore.collection('categories').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
    });
  }

  // Fetch monthly expenses with pagination
  Future<List<ExpenseModel>> getMonthlyExpenses({
    String? category,
    DocumentSnapshot?
        lastDocument, // This will be the last document to paginate
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .collection('expenses') // CollectionGroup to search in subcollections
          .orderBy('date',
              descending: true) // Order by date for better chronology
          .limit(10); // Limit to 10 results per page

      // Apply pagination if there is a last document
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      QuerySnapshot querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error fetching expenses: $e");
      rethrow;
    }
  }

  // // Add multiple categories to the "categories" collection
  // Future<void> addCategories() async {
  //   try {
  //     // List of categories to add
  //     List<Map<String, dynamic>> categories = [
  //       {'name': 'Food', 'color': 0xFFFF0000}, // Example color value (red)
  //       {'name': 'Transportation', 'color': 0xFF00FF00}, // Green
  //       {'name': 'Utilities', 'color': 0xFF0000FF}, // Blue
  //       {'name': 'Health', 'color': 0xFF00FFFF}, // Cyan
  //       {'name': 'Entertainment', 'color': 0xFFFF00FF}, // Magenta
  //     ];
  //
  //     // Create a batch write to add all categories in a single operation
  //     WriteBatch batch = _firestore.batch();
  //
  //     for (var category in categories) {
  //       // Use category name as document ID
  //       DocumentReference categoryRef =
  //           _firestore.collection('categories').doc(category['name']);
  //       batch.set(categoryRef, {
  //         'name': category['name'],
  //         'color': category['color'],
  //       });
  //     }
  //
  //     // Commit the batch write
  //     await batch.commit();
  //     // print('Categories added successfully');
  //   } catch (e) {
  //     // print('Error adding categories: $e');
  //   }
  // }
}
