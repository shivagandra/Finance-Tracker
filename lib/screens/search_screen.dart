import 'package:finance_tracker/models/expense_model.dart';
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
  RangeValues _amountRange = RangeValues(0, 1000);
  DateTimeRange? _dateRange;
  String? _selectedCategory;
  String? _selectedCurrency;
  List<ExpenseModel> _expenses = [];
  bool _isLoading = false; // Added loading state

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
          fontStyle: FontStyle.italic,
          fontFamily: 'Times New Roman',
          textBaseline: TextBaseline.alphabetic,
        ),
      )),
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
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: _updateSearch,
                ),
                ExpansionTile(
                  title: Text('Filters'),
                  children: [
                    StreamBuilder<List<String>>(
                      stream: _firebaseService.getCategories(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return CircularProgressIndicator();
                        }
                        return DropdownButton<String>(
                          value: _selectedCategory,
                          hint: Text('Select Category'),
                          items: snapshot.data!.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                              _updateSearch(); // Update search whenever a filter changes
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
                    RangeSlider(
                      values: _amountRange,
                      min: 0,
                      max: 1000,
                      divisions: 20,
                      labels: RangeLabels(
                        _amountRange.start.toString(),
                        _amountRange.end.toString(),
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _amountRange = values;
                          _updateSearch();
                        });
                      },
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
                ? Center(
                    child:
                        CircularProgressIndicator()) // Show loading indicator while fetching data
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

  void _updateSearch([String? query]) async {
    setState(() {
      _isLoading = true; // Set loading state to true before fetching data
    });

    final expenses = await _firebaseService.searchExpenses(
      query: _searchController.text,
      category: _selectedCategory,
      currency: _selectedCurrency,
      minAmount: _amountRange.start,
      maxAmount: _amountRange.end,
      dateRange: _dateRange,
    );

    setState(() {
      _expenses = expenses;
      _isLoading = false; // Set loading state to false after data is fetched
    });
  }
}
