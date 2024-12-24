import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ExpenseModel {
  final String id; // Changed type to String for UUID
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  String? imagePath;
  final String currency;

  // UUID generator instance
  static const Uuid _uuid = Uuid();

  ExpenseModel({
    String? id, // Make id optional in the constructor
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.imagePath,
    this.currency = 'USD',
  }) : id = id ?? _uuid.v1(); // Generate id if not provided

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
      'imagePath': imagePath,
      'currency': currency,
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
    );
  }

  // Convert Firestore document to ExpenseModel
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Check if the date is a Timestamp or String, then convert it
    var date = data['date'];
    DateTime dateTime;

    if (date is Timestamp) {
      dateTime = date.toDate(); // Convert Timestamp to DateTime
    } else if (date is String) {
      dateTime = DateTime.parse(date); // Parse the String to DateTime
    } else {
      dateTime = DateTime.now(); // Fallback in case of invalid date format
    }

    return ExpenseModel(
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      currency: data['currency'] ?? '',
      amount: data['amount'] ?? 0.0,
      date: dateTime,
    );
  }
}
