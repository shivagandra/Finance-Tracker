import 'dart:io';
// import 'dart:typed_data';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finance_tracker/utils/expense_service.dart';
import 'package:finance_tracker/utils/firebase_service.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCurrency = 'INR'; // Default to INR, you can expand this
  XFile? _selectedImage;
  final FirebaseService _firebaseService = FirebaseService();
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false; // Added loading state
  String? _imageUrl;

  Future<void> _saveExpense() async {
    if (_descriptionController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    // Assign placeholder if no image is selected
    final imagePath = _imageUrl ??
        'https://via.placeholder.com/150'; // Replace with your placeholder URL.

    ExpenseModel expense = ExpenseModel(
      id: '',
      amount: double.parse(_amountController.text),
      category: _selectedCategory!,
      description: _descriptionController.text,
      date: DateTime.now(),
      imagePath: imagePath,
      currency: _selectedCurrency!,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      await _firebaseService.addExpense(expense);
      setState(() => _isLoading = false);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving expense: $e')),
      );
    }
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
        setState(() {
          _selectedImage = pickedImage;
        });

        if (kIsWeb) {
          final Uint8List imageBytes = await pickedImage.readAsBytes();
          Reference ref = _storage.ref().child(
              'expense_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
          UploadTask uploadTask = ref.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );

          await uploadTask;
          _imageUrl = await ref.getDownloadURL();
        } else {
          File imageFile = File(pickedImage.path);
          Reference ref = _storage.ref().child(
              'expense_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
          UploadTask uploadTask = ref.putFile(imageFile);

          await uploadTask;
          _imageUrl = await ref.getDownloadURL();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            StreamBuilder<List<String>>(
              stream: _firebaseService.getCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(); // While loading
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}'); // If error occurs
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No categories available'); // When no data
                }

                return DropdownButton<String>(
                  value: _selectedCategory,
                  hint: const Text('Select Category'),
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
            DropdownButton<String>(
              value: _selectedCurrency,
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value;
                });
              },
              items: ['USD', 'EUR', 'INR', 'GBP'].map((currency) {
                return DropdownMenuItem<String>(
                  value: currency,
                  child: Text(currency),
                );
              }).toList(),
              hint: const Text('Select Currency'),
            ),
            const SizedBox(height: 16),
            _selectedImage == null
                ? ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Image'),
                  )
                : kIsWeb
                    ? FutureBuilder<Uint8List>(
                        future: _selectedImage!.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            return Image.memory(
                              snapshot.data!,
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                            );
                          } else {
                            return const CircularProgressIndicator();
                          }
                        },
                      )
                    : Image.file(
                        File(_selectedImage!.path),
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveExpense,
                    child: const Text('Save Expense'),
                  ),
          ],
        ),
      ),
    );
  }
}
