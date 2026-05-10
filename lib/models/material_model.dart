import '../core/utils/gsm_calculator.dart';
/// Represents a raw material in inventory.
/// Can be Fabric (with GSM), Trim, or Packaging.
class MaterialModel {
  final int? id;
  final String name;
  final String category; // 'Fabric', 'Trim', 'Packaging'
  final double? gsm; // Only for Fabric
  final String unit; // 'kg', 'meters', 'pieces'
  final double currentStock;
  final double costPerUnit;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialModel({
    this.id,
    required this.name,
    required this.category,
    this.gsm,
    required this.unit,
    required this.currentStock,
    required this.costPerUnit,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Convert to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'gsm': gsm,
      'unit': unit,
      'currentStock': currentStock,
      'costPerUnit': costPerUnit,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from SQLite Map
  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      gsm: map['gsm'] as double?,
      unit: map['unit'] as String,
      currentStock: (map['currentStock'] as num).toDouble(),
      costPerUnit: (map['costPerUnit'] as num).toDouble(),
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Create a copy with updated fields
  MaterialModel copyWith({
    int? id,
    String? name,
    String? category,
    double? gsm,
    bool removeGsm = false,
    String? unit,
    double? currentStock,
    double? costPerUnit,
    String? imagePath,
  }) {
    return MaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      gsm: removeGsm ? null : (gsm ?? this.gsm),
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Check if this is a fabric material
  bool get isFabric => category == 'Fabric';

  /// Get display string for stock
  String get stockDisplay {
    if (isFabric && gsm != null && unit == 'kg') {
      double areaM2 = GsmCalculator.weightToArea(
        weightInGrams: currentStock * 1000,
        gsm: gsm!,
      );
      return '${currentStock.toStringAsFixed(1)} kg (≈ ${areaM2.toStringAsFixed(1)} m²)';
    }
    return '${currentStock.toStringAsFixed(1)} $unit';
  }

  @override
  String toString() => '$name ($category)';
}

// Need to import this for the stockDisplay method
