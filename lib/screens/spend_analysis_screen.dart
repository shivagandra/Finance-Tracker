// import 'package:finance_tracker/utils/expense_service.dart';
// import 'package:finance_tracker/utils/firebase_service.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class SpendAnalysisScreen extends StatefulWidget {
//   const SpendAnalysisScreen({super.key});

//   @override
//   _SpendAnalysisScreenState createState() => _SpendAnalysisScreenState();
// }

// class _SpendAnalysisScreenState extends State<SpendAnalysisScreen> {
//   final ExpenseService _expenseService = ExpenseService();
//   final FirebaseService _firebaseService = FirebaseService();
//   List<ExpenseModel> _expenses = [];
//   String? _selectedMonth;
//   List<String> _months = [];
//   Map<String, double> _categoryData = {};
//   double _monthlyBudget = 25000.00;
//   String _currencySymbol = '₹'; // Default currency symbol
//   bool _isLoading = true;

//   Map<String, String> currencySymbols = {
//     'USD': '\$',
//     'INR': '₹',
//     'EUR': '€',
//     'GBP': '£',
//     'AUD': '\$',
//     'JPY': '¥',
//   };

//   Future<void> _getUserCurrencySymbol() async {
//     try {
//       final userId = FirebaseAuth.instance.currentUser?.uid;
//       DocumentSnapshot userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(userId)
//           .get();

//       if (userDoc.exists) {
//         String currencyCode = userDoc['defaultCurrency'] ?? 'INR';
//         setState(() {
//           _currencySymbol = currencySymbols[currencyCode] ?? '₹';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching currency symbol: $e');
//       }
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   void _fetchMonthlyBudget() async {
//     try {
//       final budgets = _firebaseService.getBudgets();
//       setState(() async {
//         final budgetList = await budgets.first;
//         _monthlyBudget =
//             budgetList.isNotEmpty ? budgetList.first.amount : 25000.00;
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching budget: $e');
//       }
//     }
//   }

//   int? _touchedIndex;

//   @override
//   void initState() {
//     super.initState();
//     _getUserCurrencySymbol();
//     _fetchExpenses();
//     _fetchMonthlyBudget();
//   }

//   void _fetchExpenses() async {
//     try {
//       final expenses = await _expenseService.getExpenses();
//       setState(() {
//         _expenses = expenses;
//         _populateMonths();
//         _generateCategoryData(DateTime.now().month);
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching expenses: $e');
//       }
//     }
//   }

//   void _populateMonths() {
//     final Set<String> monthsSet = _expenses.map((e) {
//       return '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
//     }).toSet();
//     setState(() {
//       _months = monthsSet.toList();
//       _selectedMonth = _months.isNotEmpty ? _months.first : null;
//     });
//   }

//   void _generateCategoryData(int month) {
//     final filteredExpenses = _expenses.where((expense) {
//       return expense.date.month == month;
//     }).toList();

//     final Map<String, double> categoryTotals = {};
//     for (var expense in filteredExpenses) {
//       categoryTotals.update(
//         expense.category,
//         (value) => value + expense.amount,
//         ifAbsent: () => expense.amount,
//       );
//     }

//     setState(() {
//       _categoryData = categoryTotals;
//     });
//   }

//   double _calculateRemainingBudget() {
//     final totalSpent =
//         _categoryData.values.fold(0.0, (sum, value) => sum + value);
//     return _monthlyBudget - totalSpent;
//   }

//   String _formatAmount(double amount) {
//     return '$_currencySymbol${amount.toStringAsFixed(2)}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     final remainingBudget = _calculateRemainingBudget();

//     return Scaffold(
//       body: Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: Card(
//           elevation: 4,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(height: 16),
//                   Row(
//                     children: [
//                       SizedBox(
//                         width: 200,
//                         child: DropdownButtonFormField<String>(
//                           value: _selectedMonth,
//                           decoration: InputDecoration(
//                             contentPadding: EdgeInsets.symmetric(
//                                 vertical: 5, horizontal: 10),
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(8),
//                               borderSide: BorderSide(color: Colors.grey),
//                             ),
//                             filled: true,
//                             fillColor: Colors.white,
//                           ),
//                           items: _months.map((month) {
//                             return DropdownMenuItem(
//                               value: month,
//                               child: Text(
//                                 _formatMonth(month),
//                                 style: TextStyle(fontSize: 16),
//                               ),
//                             );
//                           }).toList(),
//                           onChanged: (value) {
//                             setState(() {
//                               _selectedMonth = value;
//                               final month = int.parse(value!.split('-')[1]);
//                               _generateCategoryData(month);
//                             });
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 20),
//                   if (_categoryData.isNotEmpty)
//                     SingleChildScrollView(
//                       child: Expanded(
//                         child: Column(
//                           children: [
//                             SizedBox(
//                               height: 300,
//                               child: PieChart(
//                                 PieChartData(
//                                   pieTouchData: PieTouchData(
//                                     touchCallback:
//                                         (FlTouchEvent event, pieTouchResponse) {
//                                       setState(() {
//                                         if (!event
//                                                 .isInterestedForInteractions ||
//                                             pieTouchResponse == null ||
//                                             pieTouchResponse.touchedSection ==
//                                                 null) {
//                                           _touchedIndex = -1;
//                                           return;
//                                         }
//                                         _touchedIndex = pieTouchResponse
//                                             .touchedSection!
//                                             .touchedSectionIndex;
//                                       });
//                                     },
//                                   ),
//                                   sections: _getSections(),
//                                   centerSpaceRadius: 50,
//                                   sectionsSpace: 2,
//                                 ),
//                               ),
//                             ),
//                             SizedBox(height: 20),
//                             Wrap(
//                               spacing: 16,
//                               runSpacing: 16,
//                               children: _getLegendItems(),
//                             ),
//                             SizedBox(height: 20),
//                             Container(
//                               padding: EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[100],
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Column(
//                                 children: [
//                                   Text(
//                                     'Remaining Budget',
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                   Text(
//                                     _formatAmount(remainingBudget),
//                                     style: TextStyle(
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                       color: remainingBudget > 0
//                                           ? Colors.green
//                                           : Colors.red,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     )
//                   else
//                     Center(child: Text('No data available')),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   List<PieChartSectionData> _getSections() {
//     return _categoryData.entries.toList().asMap().entries.map((mapEntry) {
//       final index = mapEntry.key;
//       final entry = mapEntry.value;
//       final isTouched = index == _touchedIndex;
//       final color = Colors.primaries[index % Colors.primaries.length];

//       return PieChartSectionData(
//         color: color,
//         value: entry.value,
//         title: isTouched ? '${entry.key}\n${_formatAmount(entry.value)}' : '',
//         radius: isTouched ? 110 : 100,
//         titleStyle: TextStyle(
//           fontSize: 14,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//       );
//     }).toList();
//   }

//   List<Widget> _getLegendItems() {
//     return _categoryData.entries.toList().asMap().entries.map((mapEntry) {
//       final index = mapEntry.key;
//       final entry = mapEntry.value;
//       final color = Colors.primaries[index % Colors.primaries.length];
//       final isSelected = index == _touchedIndex;

//       return GestureDetector(
//         onTap: () {
//           setState(() {
//             _touchedIndex = isSelected ? -1 : index;
//           });
//         },
//         child: Container(
//           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             // ignore: deprecated_member_use
//             color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 12,
//                 height: 12,
//                 decoration: BoxDecoration(
//                   color: color,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//               SizedBox(width: 8),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     entry.key,
//                     style: TextStyle(
//                       fontSize: 14,
//                       fontWeight:
//                           isSelected ? FontWeight.bold : FontWeight.normal,
//                     ),
//                   ),
//                   Text(
//                     _formatAmount(entry.value),
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       );
//     }).toList();
//   }

//   String _formatMonth(String month) {
//     final parts = month.split('-');
//     final monthNumber = int.parse(parts[1]);
//     final monthNames = [
//       'January',
//       'February',
//       'March',
//       'April',
//       'May',
//       'June',
//       'July',
//       'August',
//       'September',
//       'October',
//       'November',
//       'December'
//     ];
//     return '${monthNames[monthNumber - 1]} ${parts[0]}';
//   }
// }
import 'package:finance_tracker/utils/expense_service.dart';
import 'package:finance_tracker/utils/firebase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SpendAnalysisScreen extends StatefulWidget {
  const SpendAnalysisScreen({super.key});

  @override
  _SpendAnalysisScreenState createState() => _SpendAnalysisScreenState();
}

class _SpendAnalysisScreenState extends State<SpendAnalysisScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final FirebaseService _firebaseService = FirebaseService();
  List<ExpenseModel> _expenses = [];
  String? _selectedMonth;
  List<String> _months = [];
  Map<String, double> _categoryData = {};
  double _monthlyBudget = 25000.00;
  String _currencySymbol = '₹'; // Default currency symbol
  bool _isLoading = true;

  Map<String, String> currencySymbols = {
    'USD': '\$',
    'INR': '₹',
    'EUR': '€',
    'GBP': '£',
    'AUD': '\$',
    'JPY': '¥',
  };

  Future<void> _getUserCurrencySymbol() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        String currencyCode = userDoc['defaultCurrency'] ?? 'INR';
        setState(() {
          _currencySymbol = currencySymbols[currencyCode] ?? '₹';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching currency symbol: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _fetchMonthlyBudget() async {
    try {
      final budgets = await _firebaseService.getBudgets().first;
      setState(() {
        _monthlyBudget = budgets.isNotEmpty ? budgets.first.amount : 25000.00;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching budget: $e');
      }
    }
  }

  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _getUserCurrencySymbol();
    _fetchExpenses();
    _fetchMonthlyBudget();
  }

  void _fetchExpenses() async {
    try {
      final expenses = await _expenseService.getExpenses();
      setState(() {
        _expenses = expenses;
        _populateMonths();
        _generateCategoryData(DateTime.now().month);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching expenses: $e');
      }
    }
  }

  void _populateMonths() {
    final Set<String> monthsSet = _expenses.map((e) {
      return '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
    }).toSet();
    setState(() {
      _months = monthsSet.toList();
      _selectedMonth = _months.isNotEmpty ? _months.first : null;
    });
  }

  void _generateCategoryData(int month) {
    final filteredExpenses = _expenses.where((expense) {
      return expense.date.month == month;
    }).toList();

    final Map<String, double> categoryTotals = {};
    for (var expense in filteredExpenses) {
      categoryTotals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    setState(() {
      _categoryData = categoryTotals;
    });
  }

  double _calculateRemainingBudget() {
    final totalSpent =
        _categoryData.values.fold(0.0, (sum, value) => sum + value);
    return _monthlyBudget - totalSpent;
  }

  String _formatAmount(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final remainingBudget = _calculateRemainingBudget();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _months.map((month) {
                            return DropdownMenuItem(
                              value: month,
                              child: Text(
                                _formatMonth(month),
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value;
                              final month = int.parse(value!.split('-')[1]);
                              _generateCategoryData(month);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_categoryData.isNotEmpty)
                    Column(
                      children: [
                        SizedBox(
                          height: 300,
                          child: PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
                                      _touchedIndex = -1;
                                      return;
                                    }
                                    _touchedIndex = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
                                  });
                                },
                              ),
                              sections: _getSections(),
                              centerSpaceRadius: 50,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _getLegendItems(),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Remaining Budget',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatAmount(remainingBudget),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: remainingBudget > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    const Center(child: Text('No data available')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    return _categoryData.entries.toList().asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final entry = mapEntry.value;
      final isTouched = index == _touchedIndex;
      final color = Colors.primaries[index % Colors.primaries.length];

      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: isTouched ? '${entry.key}\n${_formatAmount(entry.value)}' : '',
        radius: isTouched ? 110 : 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _getLegendItems() {
    return _categoryData.entries.toList().asMap().entries.map((mapEntry) {
      final index = mapEntry.key;
      final entry = mapEntry.value;
      final color = Colors.primaries[index % Colors.primaries.length];
      final isSelected = index == _touchedIndex;

      return GestureDetector(
        onTap: () {
          setState(() {
            _touchedIndex = isSelected ? -1 : index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    _formatAmount(entry.value),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    final monthNumber = int.parse(parts[1]);
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${monthNames[monthNumber - 1]} ${parts[0]}';
  }
}
