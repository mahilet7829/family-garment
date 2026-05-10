/// Represents a size variant of a product.
/// Example: "Adult XL" version of "Classic Boxer"
class SizeVariantModel {
  final int? id;
  final int productId;
  final String sizeName; // 'Kids', 'Adult S', 'Adult M', 'Adult L', 'Adult XL'
  final Map<int, double> materialUsage; // materialId -> quantity needed
  final DateTime createdAt;

  SizeVariantModel({
    this.id,
    required this.productId,
    required this.sizeName,
    required this.materialUsage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'sizeName': sizeName,
      'materialUsage': _encodeMaterialUsage(materialUsage),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SizeVariantModel.fromMap(Map<String, dynamic> map) {
    return SizeVariantModel(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      sizeName: map['sizeName'] as String,
      materialUsage: _decodeMaterialUsage(map['materialUsage'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  // Encode Map<int, double> to JSON string for SQLite
  static String _encodeMaterialUsage(Map<int, double> usage) {
    return usage.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  // Decode JSON string back to Map<int, double>
  static Map<int, double> _decodeMaterialUsage(String encoded) {
    if (encoded.isEmpty) return {};
    final map = <int, double>{};
    for (var entry in encoded.split(',')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[int.parse(parts[0])] = double.parse(parts[1]);
      }
    }
    return map;
  }

  SizeVariantModel copyWith({
    int? id,
    int? productId,
    String? sizeName,
    Map<int, double>? materialUsage,
  }) {
    return SizeVariantModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sizeName: sizeName ?? this.sizeName,
      materialUsage: materialUsage ?? Map.from(this.materialUsage),
      createdAt: createdAt,
    );
  }

  @override
  String toString() => '$sizeName';
}