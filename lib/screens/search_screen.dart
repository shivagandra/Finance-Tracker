import 'package:finance_tracker/utils/expense_service.dart';
import 'package:finance_tracker/screens/expense_card.dart';
import 'package:finance_tracker/utils/firebase_service.dart';
import 'package:finance_tracker/utils/general_utilities.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _searchController = TextEditingController();
  RangeValues _amountRange = RangeValues(0, 1000000);
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  String? _selectedCurrency = 'INR';
  List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  bool _hasActiveFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty && !_hasActiveFilters) {
      setState(() {
        _expenses = [];
      });
    } else {
      _updateSearch();
    }
  }

  void _checkActiveFilters() {
    setState(() {
      _hasActiveFilters = _selectedCategory != null ||
          _selectedCurrency != null ||
          _dateRange != null ||
          _amountRange != const RangeValues(0, 1000000);
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedCurrency = 'INR';
      _dateRange = null;
      _amountRange = const RangeValues(0, 1000000);
      _hasActiveFilters = false;
      if (_searchController.text.isEmpty) {
        _expenses = [];
      } else {
        _updateSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //     title: Text(
        //   'Search Expenses',
        //   style: TextStyle(
        //     fontSize: 20,
        //     color: hexToColor('#FF6F61'),
        //     fontWeight: FontWeight.bold,
        //     fontStyle: FontStyle.italic,
        //     fontFamily: 'Times New Roman',
        //     textBaseline: TextBaseline.alphabetic,
        //   ),
        // )
        title: Text(
          'Search Expenses',
          style: TextStyle(
            fontSize: 20,
            color: hexToColor('#FF6F61'),
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontFamily: 'Times New Roman',
          ),
        ),
        actions: [
          if (_hasActiveFilters)
            // IconButton(
            //   icon: const Icon(Icons.clear_all),
            //   onPressed: _clearFilters,
            //   tooltip: 'Clear all filters',
            // ),
            ElevatedButton(
              onPressed: _clearFilters,
              child: Text('Clear Filters'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        if (!_hasActiveFilters) {
                          setState(
                            () {
                              _expenses = [];
                            },
                          );
                        }
                      },
                    ),
                  ),
                ),
                ExpansionTile(
                  title: Text('Filters'),
                  children: [
                    StreamBuilder<List<String>>(
                      stream: _firebaseService.getCategories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        return DropdownButton<String>(
                          value: _selectedCategory,
                          hint: const Text('Select Category'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ...snapshot.data!.map(
                              (category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              },
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                              _checkActiveFilters();
                              _updateSearch();
                            });
                          },
                        );
                      },
                    ),
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      hint: Text('Select Currency'),
                      items: ['USD', 'EUR', 'GBP', 'INR'].map((currency) {
                        return DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value;
                          _updateSearch();
                        });
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Min Amount',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              double minAmount = double.tryParse(value) ?? 0;
                              setState(() {
                                _amountRange =
                                    RangeValues(minAmount, _amountRange.end);
                                _updateSearch();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Max Amount',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              double maxAmount = double.tryParse(value) ?? 0;
                              setState(() {
                                _amountRange =
                                    RangeValues(_amountRange.start, maxAmount);
                                _updateSearch();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _dateRange = picked;
                            _updateSearch();
                          });
                        }
                      },
                      child: Text('Select Date Range'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(
                        child: Text('No expenses found'),
                      )
                    : ListView.builder(
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          return ExpenseCard(expense: expense);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _updateSearch() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await _firebaseService.searchExpenses(
        query: _searchController.text,
        category: _selectedCategory,
        currency: _selectedCurrency,
        minAmount: _amountRange.start,
        maxAmount: _amountRange.end,
        dateRange: _dateRange,
      );

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching expenses: $e')),
        );
      }
    }
  }
}
