import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openDatabaseFromAsset() async {
  final databasesPath = await getDatabasesPath();
  final dbPath = join(databasesPath, 'expenses.db');

  // Check if database already exists
  var exists = await databaseExists(dbPath);

  if (!exists) {
    // Copy from asset
    ByteData data = await rootBundle.load('assets/db/expenses.db');
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Save copied asset to documents directory
    await File(dbPath).writeAsBytes(bytes);
  }

  return openDatabase(dbPath);
}
