import '../core/database/database_helper.dart';
import '../models/material_model.dart';

/// Handles all CRUD operations for materials.
class MaterialService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> create(MaterialModel material) async {
    final db = await _db.database;
    return await db.insert('materials', material.toMap());
  }

  Future<List<MaterialModel>> getAll({String? category}) async {
    final db = await _db.database;
    List<Map<String, dynamic>> maps;
    if (category != null && category.isNotEmpty) {
      maps = await db.query('materials', where: 'category = ?', whereArgs: [category]);
    } else {
      maps = await db.query('materials');
    }
    return maps.map((map) => MaterialModel.fromMap(map)).toList();
  }

  Future<MaterialModel?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('materials', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return MaterialModel.fromMap(maps.first);
    return null;
  }

  Future<int> update(MaterialModel material) async {
    final db = await _db.database;
    return await db.update('materials', material.toMap(), where: 'id = ?', whereArgs: [material.id]);
  }

  Future<int> updateStock(int id, double newStock) async {
    final db = await _db.database;
    return await db.update('materials', {'currentStock': newStock, 'updatedAt': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MaterialModel>> search(String query) async {
    final db = await _db.database;
    final maps = await db.query('materials', where: 'name LIKE ?', whereArgs: ['%$query%']);
    return maps.map((map) => MaterialModel.fromMap(map)).toList();
  }

  Future<List<String>> getCategories() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT DISTINCT category FROM materials ORDER BY category');
    return result.map((row) => row['category'] as String).toList();
  }

  Future<bool> nameExists(String name, {int? excludeId}) async {
    final db = await _db.database;
    String where = 'LOWER(name) = LOWER(?)';
    List<dynamic> args = [name.trim()];
    if (excludeId != null) { where += ' AND id != ?'; args.add(excludeId); }
    final result = await db.query('materials', where: where, whereArgs: args);
    return result.isNotEmpty;
  }
}