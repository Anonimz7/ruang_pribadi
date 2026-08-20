import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;

  /// =========================== INISIALISASI ===========================
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, "data.db");

      if (!await File(path).exists()) {
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (e) {
          throw Exception("Gagal membuat direktori: ${e.toString()}");
        }
        ByteData data = await rootBundle.load("assets/database/data.db");
        List<int> bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return await openDatabase(path);
    } catch (e) {
      throw Exception("Gagal menginisialisasi database: ${e.toString()}");
    }
  }

  /// Menutup database (opsional)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
