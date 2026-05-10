/// Records every production run for history and reports.
class ProductionLogModel {
  final int? id;
  final int productId;
  final String productName;
  final String sizeName;
  final int quantityProduced;
  final double totalRevenue;
  final double totalCost;
  final double netProfit;
  final String materialsUsedJson; // Snapshot of what was deducted
  final DateTime producedAt;

  ProductionLogModel({
    this.id,
    required this.productId,
    required this.productName,
    required this.sizeName,
    required this.quantityProduced,
    required this.totalRevenue,
    required this.totalCost,
    required this.netProfit,
    required this.materialsUsedJson,
    DateTime? producedAt,
  }) : producedAt = producedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'productName': productName,
      'sizeName': sizeName,
      'quantityProduced': quantityProduced,
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'netProfit': netProfit,
      'materialsUsedJson': materialsUsedJson,
      'producedAt': producedAt.toIso8601String(),
    };
  }

  factory ProductionLogModel.fromMap(Map<String, dynamic> map) {
    return ProductionLogModel(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      sizeName: map['sizeName'] as String,
      quantityProduced: map['quantityProduced'] as int,
      totalRevenue: (map['totalRevenue'] as num).toDouble(),
      totalCost: (map['totalCost'] as num).toDouble(),
      netProfit: (map['netProfit'] as num).toDouble(),
      materialsUsedJson: map['materialsUsedJson'] as String,
      producedAt: DateTime.parse(map['producedAt'] as String),
    );
  }

  /// Decode the materials JSON into a displayable string
  String get materialsSummary {
    if (materialsUsedJson.isEmpty) return 'No materials recorded';
    final parts = materialsUsedJson.split(',');
    return parts.map((p) {
      final entry = p.split(':');
      return '${entry[0]}: ${entry[1]} units';
    }).join('\n');
  }
}