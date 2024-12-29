import 'package:finance_tracker/screens/expense_edit_screen.dart';
import 'package:finance_tracker/utils/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:finance_tracker/utils/expense_service.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/screens/add_expense_screen.dart';
import 'package:transparent_image/transparent_image.dart';

class ExpenseViewScreen extends StatefulWidget {
  const ExpenseViewScreen({super.key});

  @override
  State<ExpenseViewScreen> createState() => _ExpenseViewScreenState();
}

class _ExpenseViewScreenState extends State<ExpenseViewScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final FirebaseService _firebaseService = FirebaseService();
  final List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _selectedCategory;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final newExpenses = await _expenseService.getExpensesByCategory(
        category: _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _expenses.addAll(newExpenses);
          //add filter to display only expenses from current month
          _expenses.removeWhere(
              (element) => element.date.month != DateTime.now().month);
          _hasMore = newExpenses.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load expenses: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _refreshExpenses() async {
    setState(() {
      _expenses.clear();
      _hasMore = true;
    });
    await _loadExpenses();
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    try {
      await _expenseService.deleteExpense(expense.id);
      setState(() {
        _expenses.removeWhere((e) => e.id == expense.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
    } catch (e) {
      _showError('Failed to delete expense: <span class="math-inline">e');
    }
  }

  void _viewExpenseDetails(ExpenseModel expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseDetailScreen(
          expense: expense,
          onExpenseUpdated: _refreshExpenses,
          onExpenseDeleted: () => _deleteExpense(expense),
        ),
      ),
    );
    if (result != null && result) {
      _refreshExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshExpenses,
              child: _buildExpensesList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddExpenseScreen(),
            ),
          ).then((_) => _refreshExpenses());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<List<String>>(
        stream: _firebaseService.getCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 48);
          }
          return DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category Filter',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...snapshot.data!.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _expenses.clear();
                _hasMore = true;
              });
              _loadExpenses();
            },
          );
        },
      ),
    );
  }

  // Widget _buildExpensesList() {
  //   if (_expenses.isEmpty) {
  //     return _isLoading
  //         ? const Center(child: CircularProgressIndicator())
  //         : const Center(child: Text('No expenses found'));
  //   }
  //   return ListView.builder(
  //     padding: const EdgeInsets.all(8),
  //     itemCount: _expenses.length + (_hasMore ? 1 : 0),
  //     itemBuilder: (context, index) {
  //       if (index == _expenses.length) {
  //         _loadExpenses();
  //         return const Center(
  //           child: Padding(
  //             padding: EdgeInsets.all(16),
  //             child: CircularProgressIndicator(),
  //           ),
  //         );
  //       }
  //       final expense = _expenses[index];
  //       return Dismissible(
  //         key: Key(expense.id),
  //         direction: DismissDirection.endToStart,
  //         background: Container(
  //           color: Colors.red,
  //           alignment: Alignment.centerRight,
  //           padding: const EdgeInsets.only(right: 16),
  //           child: const Icon(Icons.delete, color: Colors.white),
  //         ),
  //         onDismissed: (_) => _deleteExpense(expense),
  //         child: Card(
  //           elevation: 2,
  //           margin: const EdgeInsets.symmetric(vertical: 4),
  //           child: ListTile(
  //             onTap: () => _viewExpenseDetails(expense),
  //             leading: CircleAvatar(
  //               backgroundColor: Theme.of(context).primaryColor,
  //               child: Text(
  //                 expense.category[0].toUpperCase(),
  //                 style: const TextStyle(color: Colors.white),
  //               ),
  //             ),
  //             title: Text(
  //               expense.description,
  //               style: const TextStyle(fontWeight: FontWeight.bold),
  //             ),
  //             subtitle: Text(
  //               DateFormat('MMM dd, yyyy').format(expense.date),
  //             ),
  //             trailing: Text(
  //               '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
  //               style: const TextStyle(
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 16,
  //               ),
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
  Widget _buildExpensesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return const Center(child: Text('No expenses found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Dismissible(
          key: Key(expense.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: Text(
                      'Are you sure you want to delete ${expense.description}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('DELETE'),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (_) => _deleteExpense(expense),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              onTap: () => _viewExpenseDetails(expense),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  expense.category[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                expense.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                DateFormat('MMM dd, yyyy').format(expense.date),
              ),
              trailing: Text(
                '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ExpenseDetailScreen extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onExpenseUpdated;
  final VoidCallback onExpenseDeleted;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
    required this.onExpenseUpdated,
    required this.onExpenseDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpenseEditScreen(expense: expense),
                ),
              ).then((updated) {
                if (updated == true) {
                  onExpenseUpdated();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Expense'),
                  content: const Text(
                      'Are you sure you want to delete this expense?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        onExpenseDeleted();
                        Navigator.pop(context); // Return to list
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expense.imagePath != null) // Only show if image path exists
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ImageDetailsScreen(expense: expense),
                      ),
                    );
                  },
                  child: Center(
                    child: FadeInImage.assetNetwork(
                      placeholder: 'assets/images/demo_bill.jpg',
                      image: expense.imagePath!,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/demo_bill.jpg',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAmountSection(context),
                  const SizedBox(height: 24),
                  _buildDetailsSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM dd, yyyy').format(expense.date),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailItem(
          context,
          icon: Icons.description,
          label: 'Description',
          value: expense.description,
        ),
        const SizedBox(height: 16),
        _buildDetailItem(
          context,
          icon: Icons.category,
          label: 'Category',
          value: expense.category,
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageDetailsScreen extends StatelessWidget {
  final ExpenseModel expense;

  const ImageDetailsScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Image'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: FadeInImage.memoryNetwork(
            placeholder: kTransparentImage,
            image: expense.imagePath!,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
