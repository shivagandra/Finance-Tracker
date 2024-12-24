class Budget {
  final int? id;
  final String category;
  final double amount;
  final String period;
  final String startDate;
  final String currency;

  Budget({
    this.id,
    required this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    this.currency = 'INR',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'period': period,
      'startDate': startDate,
      'currency': currency,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      amount: map['amount'],
      period: map['period'],
      startDate: map['startDate'],
      currency: map['currency'] ?? 'USD',
    );
  }
}
