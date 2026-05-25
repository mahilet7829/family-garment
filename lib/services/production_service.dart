import '../core/database/database_helper.dart';
import '../models/production_log_model.dart';
import '../models/material_model.dart';

/// Handles recording production runs and deducting inventory.
class ProductionService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Record a production run. This deducts all materials atomically.
  Future<ProductionLogModel> recordProduction({
    required int productId,
    required String productName,
    required String sizeName,
    required int quantityProduced,
    required double totalRevenue,
    required double totalCost,
    required double netProfit,
    required Map<int, double> materialsToDeduct,
    required Map<int, String> materialNames,
    Map<int, String>? materialCategories,
  }) async {
    final db = await _db.database;

    return await db.transaction((txn) async {
      for (var entry in materialsToDeduct.entries) {
        final materialId = entry.key;
        final deductQty = entry.value;

        final result = await txn.query('materials',
            columns: ['currentStock'], where: 'id = ?', whereArgs: [materialId]);

        if (result.isEmpty) throw Exception('Material ID $materialId not found');

        final currentStock = (result.first['currentStock'] as num).toDouble();
        if (currentStock < deductQty) {
          throw Exception('Insufficient stock for ${materialNames[materialId]}. Need: ${deductQty.toStringAsFixed(2)}, Have: ${currentStock.toStringAsFixed(2)}');
        }
      }

      for (var entry in materialsToDeduct.entries) {
        final materialId = entry.key;
        final deductQty = entry.value;
        await txn.rawUpdate(
          'UPDATE materials SET currentStock = currentStock - ?, updatedAt = ? WHERE id = ?',
          [deductQty, DateTime.now().toIso8601String(), materialId],
        );
      }

      // Build materials used summary with categories
      final materialsSummary = materialsToDeduct.entries.map((e) {
        final name = materialNames[e.key] ?? 'Unknown';
        final cat = materialCategories?[e.key] ?? 'Unknown';
        return '$name|$cat|${e.value.toStringAsFixed(2)}';
      }).join(',');

      final log = ProductionLogModel(
        productId: productId,
        productName: productName,
        sizeName: sizeName,
        quantityProduced: quantityProduced,
        totalRevenue: totalRevenue,
        totalCost: totalCost,
        netProfit: netProfit,
        materialsUsedJson: materialsSummary,
      );

      final logId = await txn.insert('production_logs', log.toMap());
      return log.copyWith(id: logId);
    });
  }

  Future<List<ProductionLogModel>> getLogs({
    DateTime? from,
    DateTime? to,
    int? productId,
  }) async {
    final db = await _db.database;
    String? where;
    List<dynamic>? whereArgs;
    final conditions = <String>[];

    if (from != null) { conditions.add('producedAt >= ?'); whereArgs = (whereArgs ?? [])..add(from.toIso8601String()); }
    if (to != null) { conditions.add('producedAt <= ?'); whereArgs = (whereArgs ?? [])..add(to.toIso8601String()); }
    if (productId != null) { conditions.add('productId = ?'); whereArgs = (whereArgs ?? [])..add(productId); }

    if (conditions.isNotEmpty) where = conditions.join(' AND ');

    final maps = await db.query('production_logs', where: where, whereArgs: whereArgs, orderBy: 'producedAt DESC');
    return maps.map((map) => ProductionLogModel.fromMap(map)).toList();
  }

  Future<Map<String, double>> getProfitSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(totalRevenue), 0) as totalRevenue,
             COALESCE(SUM(totalCost), 0) as totalCost,
             COALESCE(SUM(netProfit), 0) as netProfit,
             COUNT(*) as totalBatches
      FROM production_logs WHERE producedAt >= ? AND producedAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalRevenue': (row['totalRevenue'] as num).toDouble(),
        'totalCost': (row['totalCost'] as num).toDouble(),
        'netProfit': (row['netProfit'] as num).toDouble(),
        'totalBatches': (row['totalBatches'] as num).toDouble(),
      };
    }
    return {'totalRevenue': 0, 'totalCost': 0, 'netProfit': 0, 'totalBatches': 0};
  }

  /// Get cost breakdown by material category for a date range
  Future<Map<String, double>> getCostBreakdown({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final logs = await getLogs(from: from, to: to);

    final breakdown = <String, double>{
      'Fabric': 0, 'Trim': 0, 'Thread': 0, 'Packaging': 0, 'Labor': 0, 'Other': 0,
    };

    for (var log in logs) {
      final materialsStr = log.materialsUsedJson;
      if (materialsStr.isEmpty) continue;

      final entries = materialsStr.split(',');
      // Get total product cost ratio
      final totalCost = log.totalCost;
      if (totalCost <= 0) continue;

      for (var entry in entries) {
        final parts = entry.split('|');
        if (parts.length >= 3) {
          final category = parts[1].trim();
          final qty = double.tryParse(parts[2]) ?? 0;

          // Estimate cost per material by looking up current cost
          final materialMaps = await db.query('materials', where: 'name = ?', whereArgs: [parts[0].trim()]);
          if (materialMaps.isNotEmpty) {
            final costPerUnit = (materialMaps.first['costPerUnit'] as num).toDouble();
            final itemCost = qty * costPerUnit;
            breakdown[category] = (breakdown[category] ?? 0) + itemCost;
          }
        }
      }
    }
    return breakdown;
  }
}

extension ProductionLogModelExtension on ProductionLogModel {
  ProductionLogModel copyWith({int? id}) {
    return ProductionLogModel(
      id: id ?? this.id,
      productId: productId,
      productName: productName,
      sizeName: sizeName,
      quantityProduced: quantityProduced,
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      netProfit: netProfit,
      materialsUsedJson: materialsUsedJson,
      producedAt: producedAt,
    );
  }
}