import 'package:finance_tracker/utils/expense_service.dart';
import 'package:flutter/material.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;

  const ExpenseCard({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expense.description,
              style:
                  const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text("Category: ${expense.category}"),
            Text(
                "Amount: ${expense.currency} ${expense.amount.toStringAsFixed(2)}"),
            Text("Date: ${expense.date}"),
          ],
        ),
      ),
    );
  }
}
