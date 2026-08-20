import 'package:sqflite/sqflite.dart';
import '../database.dart';

class AdvancedDao {
  Future<List<Map<String, dynamic>>> getDataByType(
    String type,
    bool acak, {
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    final db = await DatabaseHelper.database;
    try {
      String query = "SELECT * FROM $type";
      List<dynamic> args = [];

      if (jlptLevel != null && jlptLevel != "Semua") {
        query += " WHERE jlpt_level = ?";
        args.add(jlptLevel);
      }

      if (acak) {
        query += " ORDER BY RANDOM()";
      }

      if (limit != null) {
        query += " LIMIT $limit";
      }
      if (offset != null) {
        query += " OFFSET $offset";
      }
      return await db.rawQuery(query, args);
    } catch (e) {
      throw Exception("Gagal mengambil data: ${e.toString()}");
    }
  }

  Future<int> getCountByType(String type, {String? jlptLevel}) async {
    final db = await DatabaseHelper.database;
    try {
      String query = "SELECT COUNT(*) as count FROM $type";
      List<dynamic> args = [];
      if (jlptLevel != null && jlptLevel != "Semua") {
        query += " WHERE jlpt_level = ?";
        args.add(jlptLevel);
      }
      var result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw Exception("Gagal mengambil count data: ${e.toString()}");
    }
  }
}
