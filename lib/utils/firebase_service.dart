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
      if (kDebugMode) {
        print('Error during registration: $e');
      }
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
      if (kDebugMode) {
        print('Error uploading profile image: $e');
      }
      rethrow;
    }
  }

  // Expense methods
  // Future<void> addExpense(ExpenseModel expense) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   String? imageUrl;
  //   if (expense.imagePath != null) {
  //     imageUrl = await _uploadExpenseImage(File(expense.imagePath!));
  //   }

  //   await _firestore
  //       .collection('users')
  //       .doc(userId)
  //       .collection('expenses')
  //       .add({
  //     'amount': expense.amount,
  //     'category': expense.category,
  //     'description': expense.description,
  //     'date': expense.date,
  //     'imageUrl': imageUrl,
  //     'currency': expense.currency,
  //     'timestamp': FieldValue.serverTimestamp(),
  //   });
  // }
  Future<void> addExpense(ExpenseModel expense) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    String? imageUrl = expense.imagePath;
    if (expense.imagePath != null && !expense.imagePath!.startsWith('http')) {
      imageUrl = await uploadExpenseImage(expense.imagePath!);
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .add({
      'amount': expense.amount,
      'category': expense.category,
      'description': expense.description,
      'date': expense.date.toIso8601String(),
      'imageUrl': imageUrl ?? 'https://via.placeholder.com/150',
      'currency': expense.currency,
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

  // Future<String> _uploadExpenseImage(File imageFile) async {
  //   String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
  //   Reference ref = _storage.ref().child('expense_images/$fileName');
  //   await ref.putFile(imageFile);
  //   return await ref.getDownloadURL();
  // }

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

  Future<List<ExpenseModel>> searchExpenses({
    String? query,
    String? category,
    String? currency,
    double? minAmount,
    double? maxAmount,
    DateTimeRange? dateRange,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _firestore
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('expenses');

      if (query != null && query.isNotEmpty) {
        query = query.toLowerCase(); // Normalize the query
        queryRef = queryRef
            .orderBy('description')
            .where('description', isGreaterThanOrEqualTo: query)
            .where('description', isLessThanOrEqualTo: '$query\uf8ff');
      }

      if (category != null && category.isNotEmpty) {
        queryRef = queryRef.where('category', isEqualTo: category);
      }
      if (currency != null && currency.isNotEmpty) {
        queryRef = queryRef.where('currency', isEqualTo: currency);
      }
      if (minAmount != null) {
        queryRef = queryRef.where('amount', isGreaterThanOrEqualTo: minAmount);
      }
      if (maxAmount != null) {
        queryRef = queryRef.where('amount', isLessThanOrEqualTo: maxAmount);
      }
      if (dateRange != null) {
        queryRef = queryRef
            .where('date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
            .where('date',
                isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
      }

      // Fetch data from Firestore
      final snapshot = await queryRef.get();

      // Debugging: Log the results
      print('Query returned ${snapshot.docs.length} documents');
      for (var doc in snapshot.docs) {
        print(doc.data());
      }

      final expenses =
          snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();

      return expenses;
    } catch (e) {
      print('Error fetching expenses: $e');
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
      if (kDebugMode) {
        print("Error fetching expenses: $e");
      }
      rethrow;
    }
  }

  Future<void> updateProfileWithBudget({
    required String? imageUrl,
    required double monthlyBudget,
    required String currency,
  }) async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) throw Exception('User not authenticated');

      // Create a batch write
      WriteBatch batch = _firestore.batch();

      // Update profile document
      DocumentReference userRef = _firestore.collection('users').doc(userId);
      Map<String, dynamic> updateData = {
        'monthlyBudget': monthlyBudget,
        'defaultCurrency': currency,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        updateData['profileImage'] = imageUrl;
      }

      batch.update(userRef, updateData);

      // Update or create monthly budget document
      DocumentReference budgetRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc('monthly');

      batch.set(
          budgetRef,
          {
            'amount': monthlyBudget,
            'currency': currency,
            'period': 'monthly',
            'startDate': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true));

      // Commit the batch
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile and budget: $e');
      }
      rethrow;
    }
  }

  Future<double> getMonthlySpending() async {
    try {
      final String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) throw Exception('User not authenticated');

      // Get the start and end of the current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startOfMonth)
          .where('date', isLessThanOrEqualTo: endOfMonth)
          .get();

      double totalSpending = 0;
      for (var doc in querySnapshot.docs) {
        totalSpending += (doc.data()['amount'] as num).toDouble();
      }

      return totalSpending;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating monthly spending: $e');
      }
      rethrow;
    }
  }

  // Add this method to refresh expenses automatically
  Stream<List<ExpenseModel>> getExpensesStream() {
    final String userId = _auth.currentUser?.uid ?? '';
    if (userId.isEmpty) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromFirestore(doc))
            .toList());
  }

  Future<String?> uploadExpenseImage(String imagePath) async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Generate a unique filename using timestamp and random string
      final String fileName =
          'expense_${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      final Reference storageRef =
          _storage.ref().child('expense_images/$fileName');

      UploadTask uploadTask;

      if (kIsWeb) {
        // For web platform
        final XFile imageFile = XFile(imagePath);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // For mobile platforms
        final File imageFile = File(imagePath);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        uploadTask = storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      // Wait for the upload to complete and get URL
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      rethrow;
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Reference to the expense document
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expense.id);

      // Check if document exists
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Expense document not found');
      }

      String? imageUrl;
      // Handle image update
      if (expense.imagePath != null) {
        if (!expense.imagePath!.startsWith('http')) {
          // New image file to upload
          try {
            imageUrl = await uploadExpenseImage(expense.imagePath!);
            if (imageUrl == null) {
              throw Exception('Failed to upload image');
            }

            // If successful upload and there was an old image, delete it
            final oldData = docSnapshot.data() as Map<String, dynamic>;
            if (oldData['imageUrl'] != null &&
                oldData['imageUrl'].toString().startsWith('http')) {
              try {
                // Extract old image path from URL
                final oldImageRef =
                    FirebaseStorage.instance.refFromURL(oldData['imageUrl']);
                await oldImageRef.delete();
              } catch (e) {
                // Log error but don't fail the update
                if (kDebugMode) {
                  print('Warning: Failed to delete old image: $e');
                }
              }
            }
          } catch (uploadError) {
            throw Exception('Error uploading new image: $uploadError');
          }
        } else {
          // Existing image URL, keep it
          imageUrl = expense.imagePath;
        }
      } else {
        // If imagePath is null and there was an old image, delete it
        final oldData = docSnapshot.data() as Map<String, dynamic>;
        if (oldData['imageUrl'] != null &&
            oldData['imageUrl'].toString().startsWith('http')) {
          try {
            final oldImageRef =
                FirebaseStorage.instance.refFromURL(oldData['imageUrl']);
            await oldImageRef.delete();
          } catch (e) {
            if (kDebugMode) {
              print('Warning: Failed to delete old image: $e');
            }
          }
        }
      }

      // Create update data map
      Map<String, dynamic> updateData = {
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'date': expense.date.toIso8601String(),
        'currency': expense.currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Handle image URL in update data
      if (imageUrl != null) {
        updateData['imageUrl'] = imageUrl;
      } else {
        // If no image URL, remove the field from Firestore
        updateData['imageUrl'] = FieldValue.delete();
      }

      // Update the document with transaction to ensure atomicity
      await _firestore.runTransaction((transaction) async {
        final freshSnapshot = await transaction.get(docRef);
        if (!freshSnapshot.exists) {
          throw Exception('Expense document was deleted during update');
        }
        transaction.update(docRef, updateData);
      });
    } catch (e) {
      if (e is FirebaseException) {
        switch (e.code) {
          case 'permission-denied':
            throw Exception(
                'You do not have permission to update this expense');
          case 'not-found':
            throw Exception('The expense no longer exists');
          case 'unavailable':
            throw Exception(
                'Service temporarily unavailable. Please try again');
          case 'cancelled':
            throw Exception('Operation cancelled. Please try again');
          default:
            throw Exception('Firebase error: ${e.message}');
        }
      }
      // Re-throw the custom exceptions we created
      if (e is Exception) {
        rethrow;
      }
      // For any other errors
      throw Exception('Error updating expense: $e');
    }
  }

  Future<bool> checkExpenseExists(String expenseId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .get();
      return snapshot.exists; // Returns true if the document exists
    } catch (e) {
      debugPrint('Error checking expense existence: $e');
      return false; // Assume it doesn't exist if there's an error
    }
  }
}
