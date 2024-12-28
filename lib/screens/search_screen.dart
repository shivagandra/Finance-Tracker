import 'dart:async';

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
  bool _isFiltersExpanded = false;

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
    if (_searchController.text.isNotEmpty || _hasActiveFilters) {
      _debounceSearch();
    } else {
      setState(() {
        _expenses = [];
      });
    }
  }

  Future<void> _debounceSearch() async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateSearch();
    });
  }

  Timer? _debounceTimer;

  void _checkActiveFilters() {
    setState(() {
      _hasActiveFilters = _selectedCategory != null ||
          _selectedCurrency != 'INR' ||
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
      _updateSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Expenses',
          style: TextStyle(
            fontSize: 20,
            color: hexToColor('#FF6F61'),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Search TextField with improved styling
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by description...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Filters section with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isFiltersExpanded = !_isFiltersExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Filters',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Icon(
                                _isFiltersExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isFiltersExpanded) ...[
                        const SizedBox(height: 16),
                        // Category Dropdown
                        StreamBuilder<List<String>>(
                          stream: _firebaseService.getCategories(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCategory,
                                  hint: const Text('Select Category'),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Categories'),
                                    ),
                                    ...snapshot.data!.map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCategory = value;
                                      _checkActiveFilters();
                                      _updateSearch();
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Currency Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              hint: const Text('Select Currency'),
                              isExpanded: true,
                              items:
                                  ['INR', 'USD', 'EUR', 'GBP'].map((currency) {
                                return DropdownMenuItem(
                                  value: currency,
                                  child: Text(currency),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCurrency = value;
                                  _checkActiveFilters();
                                  _updateSearch();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Amount Range Fields
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Min Amount',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  double minAmount =
                                      double.tryParse(value) ?? 0;
                                  setState(() {
                                    _amountRange = RangeValues(
                                        minAmount, _amountRange.end);
                                    _checkActiveFilters();
                                    _updateSearch();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Max Amount',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  double maxAmount =
                                      double.tryParse(value) ?? 0;
                                  setState(() {
                                    _amountRange = RangeValues(
                                        _amountRange.start, maxAmount);
                                    _checkActiveFilters();
                                    _updateSearch();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Date Range Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _dateRange = picked;
                                _checkActiveFilters();
                                _updateSearch();
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(_dateRange == null
                              ? 'Select Date Range'
                              : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses found',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        itemBuilder: (context, index) {
                          final expense = _expenses[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ExpenseCard(expense: expense),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // void _updateSearch() async {
  //   if (!mounted) return;

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   try {
  //     final expenses = await _firebaseService.searchExpenses(
  //       query: _searchController.text,
  //       category: _selectedCategory,
  //       currency: _selectedCurrency,
  //       minAmount: _amountRange.start,
  //       maxAmount: _amountRange.end,
  //       dateRange: _dateRange,
  //     );

  //     if (mounted) {
  //       setState(() {
  //         _expenses = expenses;
  //         _isLoading = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() {
  //         _isLoading = false;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error searching expenses: $e'),
  //           behavior: SnackBarBehavior.floating,
  //         ),
  //       );
  //     }
  //   }
  // }
  void _updateSearch() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await _firebaseService.searchExpenses(
        query: _searchController.text.trim(), // Trim whitespace
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
          SnackBar(
            content: Text('Error searching expenses: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
