import '../core/database/database_helper.dart';
import '../models/production_log_model.dart';
import '../models/material_model.dart';

/// Handles recording production runs, deducting inventory, and unified reporting.
class ProductionService {
  final DatabaseHelper _db = DatabaseHelper();

  /// Record a production run with atomic deductions.
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
            columns: ['currentStock', 'category'],
            where: 'id = ?', whereArgs: [materialId]);

        if (result.isEmpty) throw Exception('Material ID $materialId not found');

        final category = result.first['category'] as String? ?? '';
        if (category == 'Labor' || category == 'Other') continue;

        final currentStock = (result.first['currentStock'] as num).toDouble();
        if (currentStock < deductQty) {
          throw Exception('Insufficient stock for ${materialNames[materialId]}. Need: ${deductQty.toStringAsFixed(2)}, Have: ${currentStock.toStringAsFixed(2)}');
        }
      }

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

  /// REAL-TIME INTERCEPTION: Profit summary includes expense payments immediately.
  Future<Map<String, double>> getProfitSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await _db.database;

    // Production revenue and cost
    final prodResult = await db.rawQuery('''
      SELECT COALESCE(SUM(totalRevenue), 0) as totalRevenue,
             COALESCE(SUM(totalCost), 0) as totalCost,
             COUNT(*) as totalBatches
      FROM production_logs WHERE producedAt >= ? AND producedAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    // Expense payments intercept: directly add to totalCost
    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as expenseTotal
      FROM expense_payments WHERE paidAt >= ? AND paidAt <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    final prodRevenue = (prodResult.first['totalRevenue'] as num).toDouble();
    final prodCost = (prodResult.first['totalCost'] as num).toDouble();
    final expenseCost = (expenseResult.first['expenseTotal'] as num).toDouble();
    final totalBatches = (prodResult.first['totalBatches'] as num).toDouble();

    final totalCost = prodCost + expenseCost;
    final netProfit = prodRevenue - totalCost;

    return {
      'totalRevenue': prodRevenue,
      'totalCost': totalCost,
      'netProfit': netProfit,
      'totalBatches': totalBatches,
      'expenseCost': expenseCost,
      'productionCost': prodCost,
    };
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

    // Include expense payments
    final payments = await db.query('expense_payments', where: 'paidAt >= ? AND paidAt <= ?', whereArgs: [from.toIso8601String(), to.toIso8601String()]);
    for (var p in payments) {
      final cat = p['category'] as String;
      final amt = (p['amount'] as num).toDouble();
      breakdown[cat] = (breakdown[cat] ?? 0) + amt;
    }

    return breakdown;
  }

  /// UNIFIED CHRONOLOGICAL AUDIT TRAIL
  /// Combines material creation, production logs, and expense payments
  /// into a single date-sorted timeline of all financial activity.
  Future<List<AuditEntry>> getDetailedAuditTrail({DateTime? from, DateTime? to}) async {
    final db = await _db.database;
    final entries = <AuditEntry>[];

    // 1. Material creation logs (inventory additions)
    String matWhere = '1=1';
    List<dynamic> matArgs = [];
    if (from != null) { matWhere += ' AND createdAt >= ?'; matArgs.add(from.toIso8601String()); }
    if (to != null) { matWhere += ' AND createdAt <= ?'; matArgs.add(to.toIso8601String()); }
    final materials = await db.query('materials', where: matWhere, whereArgs: matArgs);
    for (var m in materials) {
      entries.add(AuditEntry(
        date: DateTime.parse(m['createdAt'] as String),
        type: 'Inventory',
        description: 'Material Added: ${m['name']}',
        amount: -((m['currentStock'] as num).toDouble() * (m['costPerUnit'] as num).toDouble()),
        category: m['category'] as String? ?? '',
        details: '${(m['currentStock'] as num).toDouble()} ${m['unit']} @ Br ${(m['costPerUnit'] as num).toDouble()}/${m['unit']}',
      ));
    }

    // 2. Production logs (manufacturing)
    String prodWhere = '1=1';
    List<dynamic> prodArgs = [];
    if (from != null) { prodWhere += ' AND producedAt >= ?'; prodArgs.add(from.toIso8601String()); }
    if (to != null) { prodWhere += ' AND producedAt <= ?'; prodArgs.add(to.toIso8601String()); }
    final productions = await db.query('production_logs', where: prodWhere, whereArgs: prodArgs);
    for (var p in productions) {
      entries.add(AuditEntry(
        date: DateTime.parse(p['producedAt'] as String),
        type: 'Production',
        description: 'Produced: ${p['productName']} (${p['sizeName']})',
        amount: (p['netProfit'] as num).toDouble(),
        category: 'Production',
        details: '${p['quantityProduced']} pcs | Rev: Br ${(p['totalRevenue'] as num).toDouble().toStringAsFixed(0)} | Cost: Br ${(p['totalCost'] as num).toDouble().toStringAsFixed(0)}',
      ));
    }

    // 3. Expense payments
    String expWhere = '1=1';
    List<dynamic> expArgs = [];
    if (from != null) { expWhere += ' AND paidAt >= ?'; expArgs.add(from.toIso8601String()); }
    if (to != null) { expWhere += ' AND paidAt <= ?'; expArgs.add(to.toIso8601String()); }
    final expenses = await db.query('expense_payments', where: expWhere, whereArgs: expArgs);
    for (var e in expenses) {
      final notes = e['notes'] as String? ?? '';
      entries.add(AuditEntry(
        date: DateTime.parse(e['paidAt'] as String),
        type: 'Expense',
        description: '${e['name']}${notes.isNotEmpty ? " - $notes" : ""}',
        amount: -((e['amount'] as num).toDouble()),
        category: e['category'] as String? ?? '',
        details: 'Br ${(e['amount'] as num).toDouble().toStringAsFixed(2)}',
      ));
    }

    // Sort descending by date
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }
}

/// Unified audit trail entry model
class AuditEntry {
  final DateTime date;
  final String type; // 'Inventory', 'Production', 'Expense'
  final String description;
  final double amount; // Positive for profit, negative for cost
  final String category;
  final String details;

  AuditEntry({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.category,
    required this.details,
  });
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