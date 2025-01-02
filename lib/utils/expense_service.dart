import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_tracker/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ExpenseModel {
  final String id;
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  String? imagePath;
  final String currency;

  static const Uuid _uuid = Uuid();

  String? modeOfPayment;

  ExpenseModel({
    String? id,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.imagePath,
    this.currency = 'USD',
    this.modeOfPayment = 'UPI',
  }) : id = id ?? _uuid.v1();

  // Create a copy of the expense with modified fields
  ExpenseModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    String? currency,
    String? imagePath,
    String? modeOfPayment,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      currency: currency ?? this.currency,
      imagePath: imagePath ?? this.imagePath,
      modeOfPayment: modeOfPayment ?? this.modeOfPayment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
      'imagePath': imagePath,
      'currency': currency,
      'modeOfPayment': modeOfPayment,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'],
      amount: map['amount'],
      category: map['category'],
      description: map['description'],
      date: map['date'],
      imagePath: map['imagePath'],
      currency: map['currency'] ?? 'USD',
      modeOfPayment: map['modeOfPayment'] ?? 'UPI',
    );
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    var date = data['date'];
    DateTime dateTime;

    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      dateTime = DateTime.parse(date);
    } else {
      dateTime = DateTime.now();
    }

    return ExpenseModel(
      id: doc.id,
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      currency: data['currency'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: dateTime,
      imagePath: data['imageUrl'],
      modeOfPayment: data['modeOfPayment'],
    );
  }
}

class ExpenseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateExpense(ExpenseModel expense) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .doc(expense.id);

    try {
      return await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        if (!docSnapshot.exists) {
          throw Exception('Expense document not found');
        }

        final oldData = docSnapshot.data() as Map<String, dynamic>;
        final String? imageUrl = await _handleImageUpdate(
          expense.imagePath,
          oldData['imageUrl'] as String?,
        );

        final updateData = _createUpdateData(expense, imageUrl);
        transaction.update(docRef, updateData);
      });
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      _handleGeneralError(e);
      rethrow;
    }
  }

  Future<String?> _handleImageUpdate(
      String? newImagePath, String? oldImageUrl) async {
    if (newImagePath == null) {
      await _deleteOldImage(oldImageUrl);
      return null;
    }

    if (newImagePath.startsWith('http')) {
      return newImagePath;
    }

    final imageUrl = await uploadExpenseImage(newImagePath);
    if (imageUrl == null) {
      throw Exception('Failed to upload image');
    }

    await _deleteOldImage(oldImageUrl);
    return imageUrl;
  }

  Future<void> _deleteOldImage(String? oldImageUrl) async {
    if (oldImageUrl != null && oldImageUrl.startsWith('http')) {
      try {
        final oldImageRef = FirebaseStorage.instance.refFromURL(oldImageUrl);
        await oldImageRef.delete();
      } catch (e) {
        if (kDebugMode) {
          print('Warning: Failed to delete old image: $e');
        }
      }
    }
  }

  Future<String?> uploadExpenseImage(String imagePath) async {
    try {
      final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('expense_images')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(imagePath));
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      return null;
    }
  }

  Map<String, dynamic> _createUpdateData(
      ExpenseModel expense, String? imageUrl) {
    return {
      'amount': expense.amount,
      'category': expense.category,
      'description': expense.description,
      'date': expense.date,
      'currency': expense.currency,
      'updatedAt': FieldValue.serverTimestamp(),
      if (imageUrl != null)
        'imageUrl': imageUrl
      else
        'imageUrl': FieldValue.delete(),
    };
  }

  Exception _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return Exception('You do not have permission to update this expense');
      case 'not-found':
        return Exception('The expense no longer exists');
      case 'unavailable':
        return Exception('Service temporarily unavailable. Please try again');
      case 'cancelled':
        return Exception('Operation cancelled. Please try again');
      default:
        return Exception('Firebase error: ${e.message}');
    }
  }

  void _handleGeneralError(Object e, {BuildContext? context}) {
    if (e.toString() ==
            'Exception: Expense document was deleted during update' &&
        context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'The expense was deleted or no longer exists. Please refresh the list.'),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  Future<List<ExpenseModel>> getExpenses() async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<List<ExpenseModel>> getExpensesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
  }) async {
    Query query = _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ExpenseModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseModel>> getExpensesByCategory({String? category}) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('category', isEqualTo: category) // Add category filtering
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expenseId);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Expense document not found');
      }

      final data = docSnapshot.data();
      if (data != null && data['imageUrl'] != null) {
        await _deleteOldImage(data['imageUrl'] as String);
      }

      await docRef.delete();
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<List<ExpenseModel>> getExpensesByMonthAndCategory({
    required DateTime month,
    String? category,
  }) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Create date range for the selected month
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      // Start building the query
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      // Add category filter if provided
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      // Add ordering
      query = query.orderBy('date', descending: true);

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<Map<String, double>> getMonthlyTotals(DateTime month) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // Calculate totals by currency
      Map<String, double> totals = {};
      for (var doc in querySnapshot.docs) {
        final expense = ExpenseModel.fromFirestore(doc);
        totals[expense.currency] =
            (totals[expense.currency] ?? 0) + expense.amount;
      }

      return totals;
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<Map<String, double>> getMonthlyCategoryTotals(DateTime month) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // Calculate totals by category
      Map<String, double> categoryTotals = {};
      for (var doc in querySnapshot.docs) {
        final expense = ExpenseModel.fromFirestore(doc);
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      return categoryTotals;
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  Future<List<ExpenseModel>> getExpensesByFilters({
    required DateTime month,
    String? category,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'date',
    bool sortAscending = false,
  }) async {
    Query query = _firestore.collection('expenses');

    // Base date range for the selected month
    DateTime monthStart = DateTime(month.year, month.month, 1);
    DateTime monthEnd = DateTime(month.year, month.month + 1, 0);

    // Apply date filters
    DateTime effectiveStartDate = startDate ?? monthStart;
    DateTime effectiveEndDate = endDate ?? monthEnd;

    query = query.where('date', isGreaterThanOrEqualTo: effectiveStartDate);
    query = query.where('date', isLessThanOrEqualTo: effectiveEndDate);

    // Apply category filter
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    // Apply amount filters
    if (minAmount != null) {
      query = query.where('amount', isGreaterThanOrEqualTo: minAmount);
    }
    if (maxAmount != null) {
      query = query.where('amount', isLessThanOrEqualTo: maxAmount);
    }

    // Apply sorting
    switch (sortBy) {
      case 'date':
        query = query.orderBy('date', descending: !sortAscending);
        break;
      case 'amount':
        query = query.orderBy('amount', descending: !sortAscending);
        break;
      case 'category':
        query = query.orderBy('category', descending: !sortAscending);
        break;
    }

    final querySnapshot = await query.limit(10).get();
    return querySnapshot.docs
        .map((doc) => ExpenseModel.fromFirestore(doc))
        .toList();
  }
}
