/// Links a material to a product in the recipe (Bill of Materials).
/// This is the denormalized display version for the UI.
class RecipeItemModel {
  final int? id;
  final int productId;
  final int materialId;
  final String materialName;
  final String category;
  final double? gsm;
  final String unit;
  final double costPerUnit;
  final String? imagePath;
  final int sortOrder;

  RecipeItemModel({
    this.id,
    required this.productId,
    required this.materialId,
    required this.materialName,
    required this.category,
    this.gsm,
    required this.unit,
    required this.costPerUnit,
    this.imagePath,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'productId': productId,
      'materialId': materialId,
      'materialName': materialName,
      'category': category,
      'gsm': gsm,
      'unit': unit,
      'costPerUnit': costPerUnit,
      'imagePath': imagePath,
      'sortOrder': sortOrder,
    };
  }

  factory RecipeItemModel.fromMap(Map<String, dynamic> map) {
    return RecipeItemModel(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      materialId: map['materialId'] as int,
      materialName: map['materialName'] as String,
      category: map['category'] as String,
      gsm: map['gsm'] as double?,
      unit: map['unit'] as String,
      costPerUnit: (map['costPerUnit'] as num).toDouble(),
      imagePath: map['imagePath'] as String?,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  bool get isFabric => category == 'Fabric';

  @override
  String toString() => '$materialName ($category)';
}