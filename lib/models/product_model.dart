/// Represents a finished garment product.
/// Example: "Classic Boxer", "Women's T-Shirt"
class ProductModel {
  final int? id;
  final String name;
  final String category; // 'Men\'s Wear', 'Women\'s Wear', 'Kids Wear'
  final double sellingPrice;
  final List<String> imagePaths;
  final String soldAs; // e.g. "Package of 12"
  final int piecesPerPackage; // e.g. 12
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.sellingPrice,
    this.imagePaths = const [],
    this.soldAs = '',
    this.piecesPerPackage = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'sellingPrice': sellingPrice,
      'imagePaths': imagePaths.join(','),
      'soldAs': soldAs,
      'piecesPerPackage': piecesPerPackage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      imagePaths: (map['imagePaths'] as String?)?.isNotEmpty == true
          ? (map['imagePaths'] as String).split(',')
          : [],
      soldAs: map['soldAs'] as String? ?? '',
      piecesPerPackage: map['piecesPerPackage'] as int? ?? 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? category,
    double? sellingPrice,
    List<String>? imagePaths,
    String? soldAs,
    int? piecesPerPackage,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      imagePaths: imagePaths ?? this.imagePaths,
      soldAs: soldAs ?? this.soldAs,
      piecesPerPackage: piecesPerPackage ?? this.piecesPerPackage,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() => name;
}