// import 'dart:io';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:finance_tracker/utils/expense_service.dart';
// import 'package:finance_tracker/utils/firebase_service.dart';

// class AddExpenseScreen extends StatefulWidget {
//   const AddExpenseScreen({super.key});

//   @override
//   State<AddExpenseScreen> createState() => _AddExpenseScreenState();
// }

// class _AddExpenseScreenState extends State<AddExpenseScreen> {
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _amountController = TextEditingController();
//   String? _selectedCategory;
//   String? _selectedCurrency = 'INR';
//   XFile? _selectedImage;
//   final FirebaseService _firebaseService = FirebaseService();
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   bool _isLoading = false;
//   String? _imageUrl;

//   Future<void> _saveExpense() async {
//     if (_descriptionController.text.isEmpty ||
//         _amountController.text.isEmpty ||
//         _selectedCategory == null ||
//         _selectedCurrency == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please fill out all fields')),
//       );
//       return;
//     }

//     // Use default asset image path if no image is selected
//     final imagePath = _imageUrl ?? 'assets/images/demo_bill.jpg';

//     ExpenseModel expense = ExpenseModel(
//       id: '',
//       amount: double.parse(_amountController.text),
//       category: _selectedCategory!,
//       description: _descriptionController.text,
//       date: DateTime.now(),
//       imagePath: imagePath,
//       currency: _selectedCurrency!,
//     );

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       await _firebaseService.addExpense(expense);
//       setState(() => _isLoading = false);
//       Navigator.pop(context);
//     } catch (e) {
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error saving expense: $e')),
//       );
//     }
//   }

//   Future<void> _pickImage() async {
//     try {
//       final ImagePicker picker = ImagePicker();
//       XFile? pickedImage = await picker.pickImage(
//         source: ImageSource.gallery,
//         imageQuality: 85,
//         maxWidth: 1024,
//         maxHeight: 1024,
//       );

//       if (pickedImage != null) {
//         setState(() {
//           _selectedImage = pickedImage;
//         });

//         if (kIsWeb) {
//           final Uint8List imageBytes = await pickedImage.readAsBytes();
//           Reference ref = _storage.ref().child(
//               'expense_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
//           UploadTask uploadTask = ref.putData(
//             imageBytes,
//             SettableMetadata(contentType: 'image/jpeg'),
//           );

//           await uploadTask;
//           _imageUrl = await ref.getDownloadURL();
//         } else {
//           File imageFile = File(pickedImage.path);
//           Reference ref = _storage.ref().child(
//               'expense_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
//           UploadTask uploadTask = ref.putFile(imageFile);

//           await uploadTask;
//           _imageUrl = await ref.getDownloadURL();
//         }

//         setState(() {}); // Refresh UI with new image
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error picking image: $e');
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error picking image: $e')),
//       );
//     }
//   }

//   Widget _buildImageSection() {
//     return Column(
//       children: [
//         Container(
//           height: 150,
//           width: 150,
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: _selectedImage != null
//               ? kIsWeb
//                   ? FutureBuilder<Uint8List>(
//                       future: _selectedImage!.readAsBytes(),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState == ConnectionState.done) {
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
//               : _imageUrl != null
//                   ? Image.network(
//                       _imageUrl!,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         return Image(
//                           image: AssetImage('assets/images/demo_bill.jpg'),
//                           fit: BoxFit.cover,
//                         );
//                       },
//                     )
//                   : Image(
//                       image: AssetImage('assets/images/demo_bill.jpg'),
//                       fit: BoxFit.cover,
//                     ),
//         ),
//         const SizedBox(height: 16),
//         ElevatedButton.icon(
//           onPressed: _pickImage,
//           icon: const Icon(Icons.photo_camera),
//           label: Text(_selectedImage == null ? 'Pick Image' : 'Change Image'),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Add Expense'),
//         actions: [
//           if (!_isLoading)
//             IconButton(
//               icon: const Icon(Icons.save),
//               onPressed: _saveExpense,
//             ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             TextField(
//               controller: _descriptionController,
//               decoration: const InputDecoration(
//                 labelText: 'Description',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 16),
//             TextField(
//               controller: _amountController,
//               decoration: const InputDecoration(
//                 labelText: 'Amount',
//                 border: OutlineInputBorder(),
//               ),
//               keyboardType: TextInputType.number,
//             ),
//             const SizedBox(height: 16),
//             StreamBuilder<List<String>>(
//               stream: _firebaseService.getCategories(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const CircularProgressIndicator();
//                 } else if (snapshot.hasError) {
//                   return Text('Error: ${snapshot.error}');
//                 } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Text('No categories available');
//                 }

//                 return DropdownButtonFormField<String>(
//                   value: _selectedCategory,
//                   decoration: const InputDecoration(
//                     labelText: 'Category',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: snapshot.data!.map((category) {
//                     return DropdownMenuItem(
//                       value: category,
//                       child: Text(category),
//                     );
//                   }).toList(),
//                   onChanged: (value) {
//                     setState(() {
//                       _selectedCategory = value;
//                     });
//                   },
//                 );
//               },
//             ),
//             const SizedBox(height: 16),
//             DropdownButtonFormField<String>(
//               value: _selectedCurrency,
//               decoration: const InputDecoration(
//                 labelText: 'Currency',
//                 border: OutlineInputBorder(),
//               ),
//               items: ['USD', 'EUR', 'INR', 'GBP'].map((currency) {
//                 return DropdownMenuItem(
//                   value: currency,
//                   child: Text(currency),
//                 );
//               }).toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedCurrency = value;
//                 });
//               },
//             ),
//             const SizedBox(height: 24),
//             _buildImageSection(),
//             const SizedBox(height: 24),
//             if (_isLoading)
//               const Center(child: CircularProgressIndicator())
//             else

//               // ElevatedButton.icon(
//               //   onPressed: _saveExpense,
//               //   icon: const Icon(Icons.save),
//               //   label: const Text('Save Expense'),
//               //   style: ElevatedButton.styleFrom(
//               //     padding: const EdgeInsets.symmetric(vertical: 12),
//               //   ),
//               // ),
//               SizedBox(
//                 width: MediaQuery.of(context).size.width * 0.4,
//                 child: ElevatedButton.icon(
//                   onPressed: _saveExpense,
//                   icon: const Icon(Icons.save),
//                   label: const Text(
//                     'Save Expense',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 32, vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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
  String? _selectedCurrency = 'INR';
  XFile? _selectedImage;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  String? _imageUrl;
  DateTime _selectedDate = DateTime.now();
  final String _defaultImageAsset = 'assets/images/demo_bill.jpg';
  final String _defaultImageUrl =
      'https://firebasestorage.googleapis.com/v0/b/personal-finance-tracker-e8905.firebasestorage.app/o/default_images%2Fdemo_bill.jpg?alt=media&token=0db06daa-52e9-4df0-8c1a-cc6d38704a9c';
  String _selectedPaymentMode = 'UPI';

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

    // Use default asset image path if no image is selected
    final imagePath = _imageUrl ?? _defaultImageUrl;

    // Create DateTime with selected date but current time
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );

    ExpenseModel expense = ExpenseModel(
      id: '',
      amount: double.parse(_amountController.text),
      category: _selectedCategory!,
      description: _descriptionController.text,
      date: selectedDateTime,
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

        setState(() {});
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

  Widget _buildImageSection() {
    return Column(
      children: [
        Container(
          height: 150,
          width: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _selectedImage != null
              ? kIsWeb
                  ? FutureBuilder<Uint8List>(
                      future: _selectedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
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
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          _defaultImageAsset,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  : Image.asset(
                      _defaultImageAsset,
                      fit: BoxFit.cover,
                    ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_camera),
          label: Text(_selectedImage == null ? 'Pick Image' : 'Change Image'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveExpense,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              items: ['USD', 'EUR', 'INR', 'GBP'].map((currency) {
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
            DropdownButtonFormField<String>(
              value: _selectedPaymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment Mode',
                border: OutlineInputBorder(),
              ),
              items:
                  ['UPI', 'Cash', 'Card', 'Net Banking', 'Other'].map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMode = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildImageSection(),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: ElevatedButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Save Expense',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
