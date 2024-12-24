import 'package:finance_tracker/screens/expenses_view_screen.dart';
import 'package:finance_tracker/screens/profile_screen.dart';
import 'package:finance_tracker/screens/search_screen.dart';
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
    ProfilePage(),
  ];

  int _selectedIndex = 0; // Track selected tab index

  // Function to change the selected tab
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
      body: _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, // Set the current selected tab
        onTap: _onItemTapped, // Handle tab change
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
