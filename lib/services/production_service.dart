import '../core/database/database_helper.dart';
import '../models/production_log_model.dart';
import '../models/material_model.dart';

/// Handles recording production runs, deducting inventory, and reporting financial summaries.
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
      // Fetch all material categories for stock check
      for (var entry in materialsToDeduct.entries) {
        final materialId = entry.key;
        final deductQty = entry.value;

        final result = await txn.query('materials',
            columns: ['currentStock', 'category'],
            where: 'id = ?',
            whereArgs: [materialId]);

        if (result.isEmpty) throw Exception('Material ID $materialId not found');

        final category = result.first['category'] as String? ?? '';

        // Skip stock check for Labor and Other (they are monthly expenses, not physical stock)
        if (category == 'Labor' || category == 'Other') continue;

        final currentStock = (result.first['currentStock'] as num).toDouble();
        if (currentStock < deductQty) {
          throw Exception('Insufficient stock for ${materialNames[materialId]}. Need: ${deductQty.toStringAsFixed(2)}, Have: ${currentStock.toStringAsFixed(2)}');
        }
      }

      // Deduct all materials (skip Labor/Other)
      for (var entry in materialsToDeduct.entries) {
        final materialId = entry.key;
        final deductQty = entry.value;

        final catResult = await txn.query('materials',
            columns: ['category'], where: 'id = ?', whereArgs: [materialId]);
        final category = catResult.isNotEmpty ? (catResult.first['category'] as String? ?? '') : '';

        if (category == 'Labor' || category == 'Other') continue;

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

  /// Get profit summary factoring in both production metrics and separate operational expense payments.
  Future<Map<String, double>> getProfitSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    
    // 1. Get raw manufacturing totals
    final productionResult = await db.rawQuery('''
      SELECT COALESCE(SUM(totalRevenue), 0) as totalRevenue,
             COALESCE(SUM(totalCost), 0) as productionCost,
             COUNT(*) as totalBatches
      FROM production_logs WHERE producedAt >= ? AND producedAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // 2. Get independent operational expense payments total
    final expensesResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as totalExpenses
      FROM expense_payments WHERE paidAt >= ? AND paidAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    double totalRevenue = 0;
    double productionCost = 0;
    double totalBatches = 0;
    double totalExpenses = 0;

    if (productionResult.isNotEmpty) {
      final row = productionResult.first;
      totalRevenue = (row['totalRevenue'] as num).toDouble();
      productionCost = (row['productionCost'] as num).toDouble();
      totalBatches = (row['totalBatches'] as num).toDouble();
    }

    if (expensesResult.isNotEmpty) {
      totalExpenses = (expensesResult.first['totalExpenses'] as num).toDouble();
    }

    // Combined financial metrics
    final totalCost = productionCost + totalExpenses;
    final netProfit = totalRevenue - totalCost;

    return {
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'netProfit': netProfit,
      'totalBatches': totalBatches,
      'operationalExpenses': totalExpenses,
    };
  }

  /// Get comprehensive cost breakdown by material category and operational expenses for a date range.
  Future<Map<String, double>> getCostBreakdown({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;
    final logs = await getLogs(from: from, to: to);

    // Initialize base categories map
    final breakdown = <String, double>{
      'Fabric': 0, 'Trim': 0, 'Thread': 0, 'Packaging': 0, 'Labor': 0, 'Other': 0,
    };

    // 1. Accumulate costs from historical production runs (materials used)
    for (var log in logs) {
      final materialsStr = log.materialsUsedJson;
      if (materialsStr.isEmpty) continue;

      final entries = materialsStr.split(',');
      for (var entry in entries) {
        final parts = entry.split('|');
        if (parts.length >= 3) {
          final category = parts[1].trim();
          final qty = double.tryParse(parts[2]) ?? 0;

          final materialMaps = await db.query('materials', where: 'name = ?', whereArgs: [parts[0].trim()]);
          if (materialMaps.isNotEmpty) {
            final costPerUnit = (materialMaps.first['costPerUnit'] as num).toDouble();
            final itemCost = qty * costPerUnit;
            breakdown[category] = (breakdown[category] ?? 0) + itemCost;
          }
        }
      }
    }

    // 2. Accumulate costs from operational expense payments
    final payments = await db.query(
      'expense_payments',
      where: 'paidAt >= ? AND paidAt <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
    );

    for (var p in payments) {
      final category = p['category'] as String;
      final amount = (p['amount'] as num).toDouble();
      
      // Aggregate into existing categories or dynamically add new ones (e.g. Rent, Utilities)
      breakdown[category] = (breakdown[category] ?? 0) + amount;
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
