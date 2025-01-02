import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedCategory;
  String? _selectedCurrency;
  String? _selectedPaymentMode;
  String? _imageUrl;
  XFile? _selectedImage;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isImageUploading = false;

  final String _defaultImageAsset = 'assets/images/demo_bill.jpg';
  final String _defaultImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/personal-finance-tracker-e8905.firebasestorage.app/o/default_images%2Fdemo_bill.jpg?alt=media&token=0db06daa-52e9-4df0-8c1a-cc6d38704a9c';

  @override
  void initState() {
    super.initState();
    _initializeExpenseData();
  }

  void _initializeExpenseData() {
    _descriptionController.text = widget.expense.description;
    _amountController.text = widget.expense.amount.toString();
    _selectedCategory = widget.expense.category;
    _selectedCurrency = widget.expense.currency;
    _selectedPaymentMode = widget.expense.modeOfPayment;
    _imageUrl = widget.expense.imagePath != _defaultImageUrl
        ? widget.expense.imagePath
        : null;
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
      setState(() => _isImageUploading = true);

      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage != null) {
        debugPrint('Image picked: ${pickedImage.path}');
        setState(() => _selectedImage = pickedImage);

        final String? downloadUrl =
            await _firebaseService.uploadExpenseImage(pickedImage.path);
        debugPrint('Download URL received: $downloadUrl');

        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          setState(() {
            _imageUrl = downloadUrl;
            _selectedImage = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image uploaded successfully')),
            );
          }
        } else {
          throw Exception('Failed to get download URL');
        }
      }
    } catch (e) {
      debugPrint('Error in _pickImage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImageUploading = false);
      }
    }
  }

  Widget _buildImageWidget() {
    if (_isImageUploading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedImage != null) {
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: _selectedImage!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
            }
            return const CircularProgressIndicator();
          },
        );
      }
      return Image.file(File(_selectedImage!.path), fit: BoxFit.cover);
    }

    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      debugPrint('Loading image from URL: $_imageUrl');
      return FadeInImage.assetNetwork(
        placeholder: _defaultImageAsset,
        image: _imageUrl!,
        fit: BoxFit.cover,
        imageErrorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading image: $error');
          return Image.asset(_defaultImageAsset, fit: BoxFit.cover);
        },
      );
    }

    return Image.asset(_defaultImageAsset, fit: BoxFit.cover);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final expenseId = widget.expense.id;
      if (expenseId.isEmpty) {
        throw Exception('Invalid expense ID');
      }

      final expenseExists =
          await _firebaseService.checkExpenseExists(expenseId);
      if (!expenseExists) {
        throw Exception('Expense no longer exists');
      }

      final imagePath = _imageUrl ?? _defaultImageUrl;
      final updatedExpense = ExpenseModel(
        id: expenseId,
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        category: _selectedCategory!,
        currency: _selectedCurrency!,
        date: _selectedDate,
        imagePath: imagePath,
        modeOfPayment: _selectedPaymentMode!,
      );

      await _firebaseService.updateExpense(updatedExpense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('no longer exists') ||
                e.toString().contains('not found')
            ? 'This expense has been deleted or no longer exists. Please go back and refresh your expense list.'
            : 'Error updating expense: ${e.toString()}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
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
                            setState(() => _selectedCategory = value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
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
                        setState(() => _selectedCurrency = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a currency';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'UPI',
                        'Cash',
                        'Cards',
                        'Net Banking',
                        'Wallets',
                        'Others'
                      ].map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPaymentMode = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a payment mode';
                        }
                        return null;
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
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildImageWidget(),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _isImageUploading ? null : _pickImage,
                            icon: const Icon(Icons.photo_camera),
                            label: Text(
                              _imageUrl == null ? 'Add Image' : 'Change Image',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
