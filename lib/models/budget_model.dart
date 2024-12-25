import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final int? id;
  // final String category;
  final double amount;
  final String period;
  final DateTime startDate;
  final String currency;

  Budget({
    this.id,
    // required this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    this.currency = 'INR',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // 'category': category,
      'amount': amount,
      'period': period,
      'startDate': startDate,
      'currency': currency,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> data) {
    return Budget(
      amount: (data['amount'] as num).toDouble(), // Explicit conversion
      period: data['period'] ?? '',
      currency: data['currency'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
    );
  }
}
