import 'package:finance_tracker/screens/expenses_view_screen.dart';
import 'package:finance_tracker/screens/profile_screen.dart';
import 'package:finance_tracker/screens/search_screen.dart';
import 'package:finance_tracker/screens/spend_analysis_screen.dart';
import 'package:finance_tracker/utils/general_utilities.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = [
    ExpenseViewScreen(),
    SearchScreen(),
    SpendAnalysisScreen(),
    ProfilePage(),
  ];

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        backgroundColor: hexToColor('#F9D1D3'),
        title: Center(
          child: Text(
            "Finance Tracker",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              color: hexToColor('#000000'),
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontFamily: 'Times New Roman',
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType
            .fixed, // Use fixed type for consistent icon colors
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home,
                color: _selectedIndex == 0 ? Colors.purple : Colors.black),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search,
                color: _selectedIndex == 1 ? Colors.purple : Colors.black),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights,
                color: _selectedIndex == 2 ? Colors.purple : Colors.black),
            label: 'Spend Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person,
                color: _selectedIndex == 3 ? Colors.purple : Colors.black),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
