import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_tracker/models/budget_model.dart';
import 'package:finance_tracker/utils/expense_service.dart';
// import 'package:finance_tracker/screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _defaultImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/personal-finance-tracker-e8905.firebasestorage.app/o/default_images%2Fdemo_bill.jpg?alt=media&token=2e945572-80ff-47ba-9b67-71ae5317f915';
  final String _profileImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/personal-finance-tracker-e8905.firebasestorage.app/o/default_images%2Fperson.png?alt=media&token=1c590bc6-6dd5-4abd-9ecc-2cb37d63569c';
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
      // 1. Create the user account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? imageUrl;

      // 2. Upload the profile image if provided
      if (profileImagePath != null) {
        final String fileName =
            'profile_${credential.user!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef =
            _storage.ref().child('profile_images/$fileName');

        final UploadTask uploadTask = kIsWeb
            ? storageRef.putData(await XFile(profileImagePath).readAsBytes(),
                SettableMetadata(contentType: 'image/jpeg'))
            : storageRef.putFile(File(profileImagePath));

        final TaskSnapshot taskSnapshot = await uploadTask;
        imageUrl = await taskSnapshot.ref.getDownloadURL();
      }

      // 3. Add user profile to Firestore
      final userId = credential.user!.uid;
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'profileImage': imageUrl,
        'defaultCurrency': 'INR',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Set a default budget with auto-generated ID
      final defaultBudget = Budget(
        amount: 25000.0, // Default budget amount
        period: 'monthly',
        startDate: DateTime.now(),
        currency: 'INR',
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .add(defaultBudget
              .toMap()); // Firestore auto-generates the document ID

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
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        throw Exception('User profile not found');
      }

      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user profile: $e');
      }
      rethrow;
    }
  }

  // Future<void> updateUserProfile(Map<String, dynamic> data) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   await _firestore.collection('users').doc(userId).update(data);
  // }

  Future<Object> updateProfileImage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        return Image.network(_profileImageUrl);
      }

      // Delete old profile image if it exists
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData != null && userData['profileImage'] != null) {
        final oldImageUrl = userData['profileImage'] as String;
        if (oldImageUrl.startsWith('http')) {
          try {
            await _storage.refFromURL(oldImageUrl).delete();
          } catch (e) {
            throw Exception('Failed to delete old profile image: $e');
          }
        }
      }

      // Generate a unique filename using user ID and timestamp
      final String fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final Reference storageRef =
          _storage.ref().child('profile_images/$fileName');

      // Upload new image
      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        final imageFile = File(image.path);
        uploadTask = storageRef.putFile(imageFile);
      }

      // Wait for upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Update user profile with new image URL
      await _firestore.collection('users').doc(user.uid).update({
        'profileImage': downloadUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile image: $e');
      }
      rethrow;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // If we're updating the profile image and it's being set to null or empty
    if (data.containsKey('profileImage') &&
        (data['profileImage'] == null ||
            data['profileImage'].toString().isEmpty)) {
      // Set it to the default asset path
      data['profileImage'] = _profileImageUrl;
    }

    await _firestore.collection('users').doc(userId).update(data);
  }

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
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Start with the base query
      Query<Map<String, dynamic>> queryRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .orderBy('date', descending: true);

      // Apply date range filter if provided
      if (dateRange != null) {
        queryRef = queryRef
            .where('date',
                isGreaterThanOrEqualTo: dateRange.start.toIso8601String())
            .where('date',
                isLessThanOrEqualTo: dateRange.end.toIso8601String());
      }

      // Execute the query
      final QuerySnapshot<Map<String, dynamic>> snapshot = await queryRef.get();

      // Convert to list of ExpenseModel
      List<ExpenseModel> expenses =
          snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();

      // Apply remaining filters in memory
      return expenses.where((expense) {
        // Text search in description
        bool matchesSearch = true;
        if (query != null && query.isNotEmpty) {
          matchesSearch =
              expense.description.toLowerCase().contains(query.toLowerCase());
        }

        // Category filter
        bool matchesCategory = true;
        if (category != null && category.isNotEmpty) {
          matchesCategory = expense.category == category;
        }

        // Currency filter
        bool matchesCurrency = true;
        if (currency != null && currency.isNotEmpty) {
          matchesCurrency = expense.currency == currency;
        }

        // Amount range filter
        bool matchesAmount = true;
        if (minAmount != null && maxAmount != null) {
          matchesAmount =
              expense.amount >= minAmount && expense.amount <= maxAmount;
        }

        return matchesSearch &&
            matchesCategory &&
            matchesCurrency &&
            matchesAmount;
      }).toList();
    } catch (e) {
      debugPrint('Error searching expenses: $e');
      rethrow;
    }
  }

  String? getUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user
        ?.uid; // Return the UID of the current user, or null if no user is signed in.
  }

  Future<List<ExpenseModel>> searchExpensesProfileScreen({
    required DateTimeRange dateRange,
  }) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(getUserId())
        .collection('expenses')
        .get(); // Get all expenses

    // Filter records based on the date in Dart code
    List<ExpenseModel> expenses = querySnapshot.docs
        .where((doc) {
          final dateString = doc['date']; // Assuming 'date' is a String
          final expenseDate =
              DateTime.parse(dateString); // Convert the string to DateTime

          // Compare the dates
          return expenseDate.isAfter(dateRange.start) &&
              expenseDate.isBefore(dateRange.end);
        })
        .map((doc) => ExpenseModel.fromFirestore(doc))
        .toList();

    return expenses;
  }

  // Budget methods
  // Future<void> setBudget(Budget budget) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   await _firestore
  //       .collection('users')
  //       .doc(userId)
  //       .collection('budgets')
  //       .doc(budget.category)
  //       .set({
  //     'amount': budget.amount,
  //     'period': budget.period,
  //     'currency': budget.currency,
  //   });
  // }

  Stream<List<Budget>> getBudgets() {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        return Budget(
          amount: (data['amount'] ?? 0.0).toDouble(),
          period: data['period'] ?? 'monthly',
          currency: data['currency'] ?? 'INR',
          startDate:
              (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
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

  // Add these methods to FirebaseService class

  Future<void> updateProfileWithBudget({
    String? imageUrl,
    required double monthlyBudget,
    required String currency,
    required String name,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      WriteBatch batch = _firestore.batch();
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);

      // Update profile
      Map<String, dynamic> profileUpdate = {
        'name': name,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Only update image if a new one is provided
      if (imageUrl != null) {
        profileUpdate['profileImage'] = imageUrl;
      }

      batch.update(userRef, profileUpdate);

      // Update or create budget
      QuerySnapshot budgetQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .limit(1)
          .get();

      if (budgetQuery.docs.isNotEmpty) {
        DocumentReference budgetRef = budgetQuery.docs.first.reference;
        batch.update(budgetRef, {
          'amount': monthlyBudget,
          'currency': currency,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        DocumentReference newBudgetRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .doc();
        batch.set(newBudgetRef, {
          'amount': monthlyBudget,
          'currency': currency,
          'period': 'monthly',
          'startDate': DateTime.now(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

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

  // Future<void> updateExpense(ExpenseModel expense) async {
  //   String? userId = _auth.currentUser?.uid;
  //   if (userId == null) throw Exception('User not authenticated');

  //   try {
  //     final docRef = _firestore
  //         .collection('users')
  //         .doc(userId)
  //         .collection('expenses')
  //         .doc(expense.id);

  //     final docSnapshot = await docRef.get();
  //     if (!docSnapshot.exists) {
  //       throw Exception('Expense document not found');
  //     }

  //     String? imageUrl;
  //     // Handle image update
  //     if (expense.imagePath != null) {
  //       if (!expense.imagePath!.startsWith('http')) {
  //         // New image file to upload
  //         try {
  //           imageUrl = await uploadExpenseImage(expense.imagePath!);
  //           if (imageUrl == null) {
  //             throw Exception('Failed to upload image');
  //           }

  //           // Delete old image only if it's not the placeholder
  //           final oldData = docSnapshot.data() as Map<String, dynamic>;
  //           if (oldData['imageUrl'] != null &&
  //               oldData['imageUrl'].toString().startsWith('http') &&
  //               !oldData['imageUrl'].toString().contains('placeholder.com')) {
  //             try {
  //               final oldImageRef =
  //                   FirebaseStorage.instance.refFromURL(oldData['imageUrl']);
  //               await oldImageRef.delete();
  //             } catch (e) {
  //               if (kDebugMode) {
  //                 print('Warning: Failed to delete old image: $e');
  //               }
  //             }
  //           }
  //         } catch (uploadError) {
  //           throw Exception('Error uploading new image: $uploadError');
  //         }
  //       } else {
  //         // If it's an existing image URL and not the placeholder, keep it
  //         imageUrl = expense.imagePath!.contains('placeholder.com')
  //             ? 'https://via.placeholder.com/150'
  //             : expense.imagePath;
  //       }
  //     } else {
  //       // If imagePath is null, use placeholder
  //       imageUrl = 'https://via.placeholder.com/150';
  //     }

  //     // Create update data map
  //     Map<String, dynamic> updateData = {
  //       'amount': expense.amount,
  //       'category': expense.category,
  //       'description': expense.description,
  //       'date': expense.date.toIso8601String(),
  //       'currency': expense.currency,
  //       'updatedAt': FieldValue.serverTimestamp(),
  //       'imageUrl': imageUrl, // Always include imageUrl in update
  //     };

  //     // Update the document with transaction to ensure atomicity
  //     await _firestore.runTransaction((transaction) async {
  //       final freshSnapshot = await transaction.get(docRef);
  //       if (!freshSnapshot.exists) {
  //         throw Exception('Expense document was deleted during update');
  //       }
  //       transaction.update(docRef, updateData);
  //     });
  //   } catch (e) {
  //     if (e is FirebaseException) {
  //       switch (e.code) {
  //         case 'permission-denied':
  //           throw Exception(
  //               'You do not have permission to update this expense');
  //         case 'not-found':
  //           throw Exception('The expense no longer exists');
  //         case 'unavailable':
  //           throw Exception(
  //               'Service temporarily unavailable. Please try again');
  //         case 'cancelled':
  //           throw Exception('Operation cancelled. Please try again');
  //         default:
  //           throw Exception('Firebase error: ${e.message}');
  //       }
  //     }
  //     if (e.toString() ==
  //         'Exception: Expense document was deleted during update') {
  //       ScaffoldMessenger.of(path.context as BuildContext).showSnackBar(
  //         const SnackBar(
  //           content: Text(
  //               'The expense was deleted or no longer exists. Please refresh the list.'),
  //         ),
  //       );
  //       MaterialPageRoute(builder: (context) => ProfilePage());
  //     } else {
  //       rethrow;
  //     }
  //   }
  // }
  Future<void> updateExpense(ExpenseModel expense) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expense.id);

      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Expense document not found');
      }

      String? imageUrl;
      // Handle image update
      if (expense.imagePath != null) {
        if (!expense.imagePath!.startsWith('http')) {
          // Delete old image if it exists
          final oldData = docSnapshot.data() as Map<String, dynamic>;
          if (oldData['imageUrl'] != null &&
              oldData['imageUrl'].toString().startsWith('http')) {
            try {
              final oldImageRef =
                  FirebaseStorage.instance.refFromURL(oldData['imageUrl']);
              await oldImageRef.delete();
            } catch (e) {
              throw Exception('Failed to delete old image: $e');
            }
          }

          // Upload new image
          imageUrl = await uploadExpenseImage(expense.imagePath!);
          if (imageUrl == null) {
            throw Exception('Failed to upload new image');
          }
        } else {
          // Keep existing Firebase URL, otherwise use asset path
          imageUrl = expense.imagePath!.startsWith('http')
              ? expense.imagePath
              : _defaultImageUrl;
        }
      } else {
        // If imagePath is null, use local asset path
        imageUrl = _defaultImageUrl;
      }

      // Create update data map
      Map<String, dynamic> updateData = {
        'amount': expense.amount,
        'category': expense.category,
        'description': expense.description,
        'date': expense.date.toIso8601String(),
        'currency': expense.currency,
        'updatedAt': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      };

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
      rethrow;
    }
  }

  Future<bool> checkExpenseExists(String expenseId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
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
