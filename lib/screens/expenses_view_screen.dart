import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_tracker/utils/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:finance_tracker/models/expense_model.dart';
import 'add_expense_screen.dart'; // Screen to add expenses

class ExpenseViewScreen extends StatefulWidget {
  const ExpenseViewScreen({super.key});

  @override
  State<ExpenseViewScreen> createState() => _ExpenseViewScreenState();
}

class _ExpenseViewScreenState extends State<ExpenseViewScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String? _selectedCategory;
  final List<ExpenseModel> _expenses = [];
  DocumentSnapshot? _lastDocument;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  void _fetchExpenses() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    // Fetch the next batch of expenses from Firebase
    final expenses = await _firebaseService.getMonthlyExpenses(
      category: _selectedCategory,
      lastDocument: _lastDocument,
    );

    setState(() {
      _loading = false;
      _expenses.addAll(expenses); // Add the fetched expenses to the list
      _hasMore =
          expenses.length == 10; // Check if there are more expenses to load

      // Update _lastDocument for pagination if there are more expenses
      if (_hasMore) {
        _lastDocument = expenses.last as DocumentSnapshot<
            Object?>; // Correctly assign the last document for pagination
      }
    });
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels == notification.metrics.maxScrollExtent) {
      _fetchExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Monthly Expenses')),
        actions: [
          StreamBuilder<List<String>>(
            stream: _firebaseService.getCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return DropdownButton<String>(
                value: _selectedCategory,
                hint: const Text(
                  'Filter by Category',
                  style: TextStyle(color: Colors.white),
                ),
                dropdownColor: Colors.blue,
                items: snapshot.data!.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _expenses.clear(); // Reset expenses list
                    _lastDocument = null;
                    _hasMore = true;
                  });
                  _fetchExpenses();
                },
              );
            },
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _onScrollNotification(notification);
          return false;
        },
        child: _expenses.isEmpty && !_loading
            ? const Center(child: Text('No expenses for this month.'))
            : ListView.builder(
                itemCount: _expenses.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_loading && index == _expenses.length) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final expense = _expenses[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(expense.description),
                      subtitle: Text(
                        "Category: ${expense.category}\n"
                        "Date: ${expense.date}\n"
                        "Amount: ${expense.currency} ${expense.amount}",
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddExpenseScreen(),
            ),
          ).then((_) {
            _fetchExpenses();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
