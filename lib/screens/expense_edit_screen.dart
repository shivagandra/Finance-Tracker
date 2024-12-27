import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:finance_tracker/utils/expense_service.dart';
import 'package:finance_tracker/utils/firebase_service.dart';

class ExpenseEditScreen extends StatefulWidget {
  final ExpenseModel expense;

  const ExpenseEditScreen({super.key, required this.expense});

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCurrency;
  XFile? _selectedImage;
  DateTime _selectedDate = DateTime.now();
  final FirebaseService _firebaseService = FirebaseService();
  // final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing expense data
    _descriptionController.text = widget.expense.description;
    _amountController.text = widget.expense.amount.toString();
    _selectedCategory = widget.expense.category;
    _selectedCurrency = widget.expense.currency;
    _imageUrl = widget.expense.imagePath;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage != null) {
        setState(() => _selectedImage = pickedImage);

        final String? downloadUrl =
            await _firebaseService.uploadExpenseImage(pickedImage.path);
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          setState(() => _imageUrl = downloadUrl);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateExpense() async {
    if (_descriptionController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Debugging: Check the expense ID
      final expenseId = widget.expense.id;
      if (expenseId.isEmpty) {
        throw Exception('Invalid expense ID');
      }

      // Verify the expense still exists in Firebase
      final expenseExists =
          await _firebaseService.checkExpenseExists(expenseId);
      if (!expenseExists) {
        throw Exception('Expense no longer exists');
      }

      // Create updated expense model
      ExpenseModel updatedExpense = ExpenseModel(
        id: expenseId,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory!,
        currency: _selectedCurrency!,
        date: _selectedDate,
        imagePath: _imageUrl,
      );

      // Update expense in Firebase
      await _firebaseService.updateExpense(updatedExpense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success to the previous screen
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;

        if (e.toString().contains('no longer exists') ||
            e.toString().contains('not found')) {
          errorMessage =
              'This expense has been deleted or no longer exists. Please go back and refresh your expense list.';
        } else {
          errorMessage = 'Error updating expense: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                Navigator.pop(context); // Return to previous screen
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateExpense,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<String>>(
                    stream: _firebaseService.getCategories(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: snapshot.data!.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: ['USD', 'EUR', 'GBP', 'INR'].map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Date'),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 16),
                  // Add the conditional rendering for placeholder and image
                  // Center(
                  //   child: Column(
                  //     children: [
                  //       if (_imageUrl != null || _selectedImage != null)
                  //         Container(
                  //           width: 200,
                  //           height: 200,
                  //           decoration: BoxDecoration(
                  //             border: Border.all(color: Colors.grey),
                  //             borderRadius: BorderRadius.circular(8),
                  //           ),
                  //           child: _selectedImage != null
                  //               ? kIsWeb
                  //                   ? FutureBuilder<Uint8List>(
                  //                       future: _selectedImage!.readAsBytes(),
                  //                       builder: (context, snapshot) {
                  //                         if (snapshot.hasData) {
                  //                           return Image.memory(
                  //                             snapshot.data!,
                  //                             fit: BoxFit.cover,
                  //                           );
                  //                         }
                  //                         return const CircularProgressIndicator();
                  //                       },
                  //                     )
                  //                   : Image.file(
                  //                       File(_selectedImage!.path),
                  //                       fit: BoxFit.cover,
                  //                     )
                  //               : Image.network(
                  //                   _imageUrl ??
                  //                       'https://via.placeholder.com/150',
                  //                   fit: BoxFit.cover,
                  //                 ),
                  //         ),
                  //       const SizedBox(height: 8),
                  //       ElevatedButton.icon(
                  //         onPressed: _pickImage,
                  //         icon: const Icon(Icons.photo_camera),
                  //         label: Text(
                  //           _imageUrl == null ? 'Add Image' : 'Change Image',
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  Center(
                    child: Column(
                      children: [
                        if (_imageUrl != null || _selectedImage != null)
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _selectedImage != null
                                ? kIsWeb
                                    ? FutureBuilder<Uint8List>(
                                        future: _selectedImage!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return const CircularProgressIndicator();
                                        },
                                      )
                                    : Image.file(
                                        File(_selectedImage!.path),
                                        fit: BoxFit.cover,
                                      )
                                : _imageUrl != null
                                    ? Image.network(
                                        _imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Image(
                                            image: AssetImage(
                                                'assets/images/demo_bill.jpg'),
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      )
                                    : Image(
                                        image: AssetImage(
                                            'assets/images/demo_bill.jpg'),
                                        fit: BoxFit.cover,
                                      ),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_camera),
                          label: Text(
                            _imageUrl == null ? 'Add Image' : 'Change Image',
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
