// import 'dart:io';
// import 'dart:typed_data';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
// // import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// // import 'package:intl/intl.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:finance_tracker/utils/firebase_service.dart';

// class ProfilePage extends StatefulWidget {
//   const ProfilePage({super.key});

//   @override
//   State<ProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<ProfilePage> {
//   Map<String, String> currencySymbols = {
//     'USD': '\$', // US Dollar
//     'INR': '₹', // Indian Rupee
//     'EUR': '€', // Euro
//     'GBP': '£', // British Pound
//     'AUD': '\$', // Australian Dollar (same as USD)
//     'JPY': '¥', // Japanese Yen
//     // Add more as needed
//   };

//   Future<String> getUserCurrencyFormatter() async {
//     final userId = FirebaseAuth.instance.currentUser?.uid;
//     DocumentSnapshot userDoc =
//         await FirebaseFirestore.instance.collection('users').doc(userId).get();

//     if (userDoc.exists) {
//       String currencyCode = userDoc['defaultCurrency'] ?? 'INR';
//       String currencySymbol = currencySymbols[currencyCode] ?? '₹';
//       return currencySymbol;
//     } else {
//       return '₹';
//     }
//   }

//   final FirebaseService _firebaseService = FirebaseService();
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _budgetController = TextEditingController();

//   bool _isLoading = true;
//   bool _isEditing = false;
//   Map<String, dynamic>? _userProfile;
//   double _monthlyBudget = 0.0;
//   double _monthlySpending = 0.0;
//   late String _currencySymbol = '₹'; // Default to INR
//   String? _selectedCurrency;

//   @override
//   void initState() {
//     super.initState();
//     _loadProfileData();
//     _getCurrencySymbol();
//   }

//   Future<void> _getCurrencySymbol() async {
//     String symbol = await getUserCurrencyFormatter();
//     setState(() {
//       _currencySymbol = symbol;
//       _isLoading = false; // Once the data is fetched, stop loading
//     });
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _budgetController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadProfileData() async {
//     try {
//       final profile = await _firebaseService.getUserProfile();
//       final budgets = await _firebaseService.getBudgets().first;
//       final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
//       final monthEnd =
//           DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

//       final expenses = await _firebaseService.searchExpensesProfileScreen(
//         dateRange: DateTimeRange(start: monthStart, end: monthEnd),
//       );

//       if (mounted) {
//         setState(() {
//           _userProfile = profile;
//           _monthlyBudget = budgets.fold(
//               0.0, (sum, budget) => sum + (budget.amount as num).toDouble());
//           _monthlySpending = expenses.fold(
//               0.0, (sum, expense) => sum + (expense.amount as num).toDouble());
//           _nameController.text = profile['name'] ?? '';
//           _budgetController.text = _monthlyBudget.toString();
//           _selectedCurrency = profile['defaultCurrency'] ?? 'INR';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading profile: $e')),
//         );
//       }
//     }
//   }

//   Future<void> _saveProfile() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(FirebaseAuth.instance.currentUser!.uid)
//           .update({
//         'name': _nameController.text.trim(),
//         'defaultCurrency': _selectedCurrency, // Update the currency field here
//         'monthlyBudget': double.parse(_budgetController.text),
//       });

//       setState(() {
//         _isEditing = false;
//       });

//       // Reload profile data after update
//       await _loadProfileData();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Profile updated successfully')),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error updating profile: $e')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         actions: [
//           IconButton(
//             icon: Icon(_isEditing ? Icons.save : Icons.edit),
//             onPressed: _isEditing
//                 ? _saveProfile
//                 : () => setState(() => _isEditing = true),
//           ),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: _loadProfileData,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.all(16),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               children: [
//                 GestureDetector(
//                   onTap: _isEditing ? _updateProfileImage : null,
//                   child: Stack(
//                     alignment: Alignment.bottomRight,
//                     children: [
//                       CircleAvatar(
//                         radius: 50,
//                         backgroundColor: Colors.grey[200],
//                         backgroundImage: _userProfile?['profileImage'] != null
//                             ? NetworkImage(_userProfile!['profileImage'])
//                             : null,
//                         child: _userProfile?['profileImage'] == null
//                             ? const Icon(Icons.person,
//                                 size: 50, color: Colors.grey)
//                             : null,
//                       ),
//                       if (_isEditing)
//                         Container(
//                           padding: const EdgeInsets.all(4),
//                           decoration: BoxDecoration(
//                             color: Theme.of(context).primaryColor,
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(Icons.camera_alt,
//                               color: Colors.white, size: 20),
//                         ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       children: [
//                         _isEditing
//                             ? TextFormField(
//                                 controller: _nameController,
//                                 decoration: const InputDecoration(
//                                   labelText: 'Name',
//                                   border: OutlineInputBorder(),
//                                 ),
//                                 validator: (value) => value?.isEmpty ?? true
//                                     ? 'Name is required'
//                                     : null,
//                               )
//                             : ListTile(
//                                 title: const Text('Name'),
//                                 subtitle: Text(_userProfile?['name'] ?? ''),
//                                 leading: const Icon(Icons.person_outline),
//                               ),
//                         const SizedBox(height: 16),
//                         ListTile(
//                           title: const Text('Email'),
//                           subtitle: Text(_userProfile?['email'] ?? ''),
//                           leading: const Icon(Icons.email_outlined),
//                         ),
//                         const SizedBox(height: 16),
//                         _isEditing
//                             ? TextFormField(
//                                 controller: _budgetController,
//                                 decoration: InputDecoration(
//                                   labelText: 'Monthly Budget',
//                                   border: const OutlineInputBorder(),
//                                   prefixText: _currencySymbol,
//                                 ),
//                                 keyboardType: TextInputType.number,
//                                 validator: (value) {
//                                   if (value?.isEmpty ?? true) {
//                                     return 'Budget is required';
//                                   }
//                                   if (double.tryParse(value!) == null) {
//                                     return 'Please enter a valid number';
//                                   }
//                                   return null;
//                                 },
//                               )
//                             : ListTile(
//                                 title: const Text('Monthly Budget'),
//                                 subtitle: Text(
//                                   concatenateStringAndDouble(
//                                       _currencySymbol, _monthlyBudget),
//                                 ),
//                                 leading:
//                                     const Icon(Icons.account_balance_wallet),
//                               ),
//                         const SizedBox(height: 16),
//                         ListTile(
//                           title: const Text('Monthly Spending'),
//                           subtitle: Text(
//                             concatenateStringAndDouble(
//                               _currencySymbol,
//                               _monthlySpending,
//                             ),
//                           ),
//                           leading: const Icon(Icons.shopping_cart_outlined),
//                         ),
//                         const SizedBox(height: 16),
//                         _isEditing
//                             ? DropdownButtonFormField<String>(
//                                 value: _selectedCurrency,
//                                 onChanged: (String? newValue) {
//                                   setState(() {
//                                     _selectedCurrency = newValue;
//                                   });
//                                 },
//                                 decoration: const InputDecoration(
//                                   labelText: 'Currency',
//                                   border: OutlineInputBorder(),
//                                 ),
//                                 items:
//                                     currencySymbols.keys.map((defaultCurrency) {
//                                   return DropdownMenuItem<String>(
//                                     value: defaultCurrency,
//                                     child: Text(
//                                         '$defaultCurrency  - ${currencySymbols[defaultCurrency]}'),
//                                   );
//                                 }).toList(),
//                               )
//                             : ListTile(
//                                 title: const Text('Currency'),
//                                 subtitle: Text(
//                                     _userProfile?['defaultCurrency'] ?? 'INR'),
//                                 leading:
//                                     const Icon(Icons.monetization_on_outlined),
//                               ),
//                         const SizedBox(height: 16),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Future<void> _updateProfileImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? pickedFile =
//         await picker.pickImage(source: ImageSource.gallery);

//     if (pickedFile == null) return;

//     try {
//       setState(() {
//         _isLoading = true;
//       });

//       final String userId = FirebaseAuth.instance.currentUser!.uid;
//       final String fileName =
//           'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
//       final Reference storageRef =
//           FirebaseStorage.instance.ref().child(fileName);

//       UploadTask uploadTask;
//       if (kIsWeb) {
//         // Web: Use pickedFile.bytes
//         final Uint8List imageData = await pickedFile.readAsBytes();
//         uploadTask = storageRef.putData(imageData);
//       } else {
//         // Mobile: Use File
//         final File file = File(pickedFile.path);
//         uploadTask = storageRef.putFile(file);
//       }

//       final TaskSnapshot snapshot = await uploadTask;
//       final String downloadUrl = await snapshot.ref.getDownloadURL();

//       await FirebaseFirestore.instance.collection('users').doc(userId).update({
//         'profileImage': downloadUrl,
//       });

//       setState(() {
//         _userProfile?['profileImage'] = downloadUrl;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('Profile image updated successfully'),
//       ));
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text('Error updating profile image: $e'),
//         ));
//       }
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   String concatenateStringAndDouble(String str, double num) {
//     return '$str${num.toStringAsFixed(2)}';
//   }
// }
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finance_tracker/utils/firebase_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, String> currencySymbols = {
    'USD': '\$', // US Dollar
    'INR': '₹', // Indian Rupee
    'EUR': '€', // Euro
    'GBP': '£', // British Pound
    'AUD': '\$', // Australian Dollar (same as USD)
    'JPY': '¥', // Japanese Yen
  };

  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic>? _userProfile;
  double _monthlyBudget = 0.0;
  double _monthlySpending = 0.0;
  late String _currencySymbol = '₹'; // Default to INR
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _getCurrencySymbol();
  }

  Future<void> _getCurrencySymbol() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      String currencyCode = userDoc['defaultCurrency'] ?? 'INR';
      String currencySymbol = currencySymbols[currencyCode] ?? '₹';
      setState(() {
        _currencySymbol = currencySymbol;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadProfileData() async {
    try {
      final profile = await _firebaseService.getUserProfile();
      final budgets = await _firebaseService.getBudgets().first;
      final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final monthEnd =
          DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

      final expenses = await _firebaseService.searchExpensesProfileScreen(
        dateRange: DateTimeRange(start: monthStart, end: monthEnd),
      );

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _monthlyBudget = budgets.fold(
              0.0, (sum, budget) => sum + (budget.amount as num).toDouble());
          _monthlySpending = expenses.fold(
              0.0, (sum, expense) => sum + (expense.amount as num).toDouble());
          _nameController.text = profile['name'] ?? '';
          _budgetController.text = _monthlyBudget.toString();
          _selectedCurrency = profile['defaultCurrency'] ?? 'INR';
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'name': _nameController.text.trim(),
        'defaultCurrency': _selectedCurrency,
        'monthlyBudget': double.parse(_budgetController.text),
      });

      setState(() {
        _isEditing = false;
      });

      // Reload profile data after update
      await _loadProfileData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final String userId = FirebaseAuth.instance.currentUser!.uid;
      final String fileName =
          'profile_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        final Uint8List imageData = await pickedFile.readAsBytes();
        uploadTask = storageRef.putData(imageData);
      } else {
        final File file = File(pickedFile.path);
        uploadTask = storageRef.putFile(file);
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profileImage': downloadUrl,
      });

      setState(() {
        _userProfile?['profileImage'] = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile image updated successfully'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating profile image: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String concatenateStringAndDouble(String str, double num) {
    return '$str${num.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing
                ? _saveProfile
                : () => setState(() => _isEditing = true),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'Sign Out') {
                await _firebaseService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'Sign Out',
                  child: Text('Sign Out'),
                ),
              ];
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isEditing ? _updateProfileImage : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _userProfile?['profileImage'] != null
                            ? NetworkImage(_userProfile!['profileImage'])
                            : null,
                        child: _userProfile?['profileImage'] == null
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.grey)
                            : null,
                      ),
                      if (_isEditing)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _isEditing
                            ? TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.isEmpty ?? true
                                    ? 'Name is required'
                                    : null,
                              )
                            : ListTile(
                                title: const Text('Name'),
                                subtitle: Text(_userProfile?['name'] ?? ''),
                                leading: const Icon(Icons.person_outline),
                              ),
                        const SizedBox(height: 16),
                        _isEditing
                            ? DropdownButtonFormField<String>(
                                value: _selectedCurrency,
                                decoration: const InputDecoration(
                                  labelText: 'Default Currency',
                                  border: OutlineInputBorder(),
                                ),
                                items: currencySymbols.keys.map((currency) {
                                  return DropdownMenuItem<String>(
                                    value: currency,
                                    child: Text(
                                      '$currency (${currencySymbols[currency]})',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCurrency = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select a currency'
                                    : null,
                              )
                            : ListTile(
                                title: const Text('Default Currency'),
                                subtitle: Text(
                                  '${_selectedCurrency ?? 'INR'} ($_currencySymbol)',
                                ),
                                leading: const Icon(Icons.attach_money),
                              ),
                        const SizedBox(height: 16),
                        _isEditing
                            ? TextFormField(
                                controller: _budgetController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText:
                                      'Monthly Budget ($_currencySymbol)',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Monthly budget is required';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid number';
                                  }
                                  return null;
                                },
                              )
                            : ListTile(
                                title: const Text('Monthly Budget'),
                                subtitle: Text(
                                  concatenateStringAndDouble(
                                    _currencySymbol,
                                    _monthlyBudget,
                                  ),
                                ),
                                leading: const Icon(Icons.pie_chart_outline),
                              ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Monthly Spending'),
                          subtitle: Text(
                            concatenateStringAndDouble(
                              _currencySymbol,
                              _monthlySpending,
                            ),
                          ),
                          leading: const Icon(Icons.money_off_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
