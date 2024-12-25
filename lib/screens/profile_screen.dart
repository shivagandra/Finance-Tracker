import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/screens/login_screen.dart';
import 'package:finance_tracker/utils/firebase_service.dart';
import 'package:finance_tracker/utils/general_utilities.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final currencyFormatter = NumberFormat.currency(symbol: '\$');
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  double _monthlyBudget = 0.0;
  double _monthlySpending = 0.0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await _firebaseService.getUserProfile();
      final budgets = await _firebaseService.getBudgets().first;
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final monthEnd =
          DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      final expenses = await _firebaseService.searchExpenses(
        dateRange: DateTimeRange(start: monthStart, end: monthEnd),
      );

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _monthlyBudget =
              budgets.fold(0.0, (sum, budget) => sum + budget.amount);
          _monthlySpending =
              expenses.fold(0.0, (sum, expense) => sum + expense.amount);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      final imageUrl = await _firebaseService.updateProfileImage();
      if (imageUrl != null) {
        await _firebaseService.updateUserProfile({'profileImage': imageUrl});
        _loadProfileData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Prevent NaN calculation by ensuring monthlyBudget is not zero
    double monthlyProgress =
        _monthlyBudget > 0 ? (_monthlySpending / _monthlyBudget) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Profile',
            style: TextStyle(
              fontSize: 22,
              color: hexToColor('#FF6F61'),
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontFamily: 'Times New Roman',
              textBaseline: TextBaseline.alphabetic,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _firebaseService.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _updateProfileImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _userProfile?['profileImage'] ?? '',
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 50,
                        backgroundImage: imageProvider,
                      ),
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                      httpHeaders: {
                        'Access-Control-Allow-Origin': '*',
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  title: Text(_userProfile?['name'] ?? 'No name'),
                  subtitle: Text(_userProfile?['email'] ?? 'No email'),
                  leading: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Monthly Budget',
                      amount: _monthlyBudget,
                      icon: Icons.account_balance_wallet,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Monthly Spending',
                      amount: _monthlySpending,
                      icon: Icons.shopping_cart,
                      color: _monthlySpending > _monthlyBudget
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _monthlyBudget > 0
                            ? (_monthlySpending / _monthlyBudget)
                                .clamp(0.0, 1.0)
                            : 0,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _monthlySpending > _monthlyBudget
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monthly Progress: ${monthlyProgress.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              NumberFormat.currency(symbol: '\$').format(amount),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
