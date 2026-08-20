import '../database.dart';

class HirakanaDao {
  Future<List<Map<String, dynamic>>> getData(
      String jenis, String kategori, bool acak) async {
    final db = await DatabaseHelper.database;
    try {
      String query = "SELECT * FROM hirakana WHERE jenis = ? AND kategori = ?";
      List<dynamic> args = [jenis, kategori];
      if (acak) {
        query += " ORDER BY RANDOM()";
      }
      return await db.rawQuery(query, args);
    } catch (e) {
      throw Exception("Gagal mengambil data: ${e.toString()}");
    }
  }

  Future<Map<String, List<String>>> getKategoriOptions() async {
    final db = await DatabaseHelper.database;
    try {
      final result = await db.rawQuery("""
        SELECT DISTINCT jenis, kategori 
        FROM hirakana
      """);
      Map<String, List<String>> kategoriMap = {};
      for (var row in result) {
        final jenis = row['jenis'] as String;
        final kategori = row['kategori'] as String;
        if (kategoriMap.containsKey(jenis)) {
          if (!kategoriMap[jenis]!.contains(kategori)) {
            kategoriMap[jenis]!.add(kategori);
          }
        } else {
          kategoriMap[jenis] = [kategori];
        }
      }
      return kategoriMap;
    } catch (e) {
      throw Exception("Gagal mengambil kategori: ${e.toString()}");
    }
  }
}
