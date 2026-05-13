import '../core/database/database_helper.dart';
import '../core/utils/gsm_calculator.dart';
import '../core/utils/yield_calculator.dart';
import '../models/material_model.dart';
import '../models/product_model.dart';
import '../models/size_variant_model.dart';
import '../models/recipe_item_model.dart';

/// The complete simulation result.
class SimulationResult {
  final int maxPieces;
  final Map<int, double> materialsNeeded;
  final Map<int, bool> materialSufficiency;
  final double totalCost;
  final double totalRevenue;
  final double netProfit;
  final double costPerPiece;
  final String? limitingFactor;

  SimulationResult({
    required this.maxPieces,
    required this.materialsNeeded,
    required this.materialSufficiency,
    required this.totalCost,
    required this.totalRevenue,
    required this.netProfit,
    required this.costPerPiece,
    this.limitingFactor,
  });
}

/// The simulation engine that answers "How many can I make?"
class SimulationService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<SimulationResult> simulate({
    required int materialId,
    required double availableQuantity,
    required int productId,
    required int sizeVariantId,
  }) async {
    final db = await _db.database;

    final mainMaterial = await _getMaterial(materialId);
    final product = await _getProduct(productId);
    final sizeVariant = await _getSizeVariant(sizeVariantId);
    final recipeItems = await _getRecipeItems(productId);
    final allMaterials = await _getAllMaterials();

    if (mainMaterial == null || product == null || sizeVariant == null) {
      throw Exception('Required data not found');
    }

    // Step 1: Calculate max pieces from main material
    int maxFromMain;
    if (mainMaterial.isFabric && mainMaterial.gsm != null) {
      final areaPerPiece = sizeVariant.materialUsage[materialId] ?? 1.0;
      maxFromMain = YieldCalculator.calculateMaxPiecesFromFabric(
        availableWeightInKg: availableQuantity,
        fabricGsm: mainMaterial.gsm!,
        areaPerPieceInM2: areaPerPiece,
      );
    } else {
      final qtyPerPiece = sizeVariant.materialUsage[materialId] ?? 1.0;
      maxFromMain = (availableQuantity / qtyPerPiece).floor();
    }

    if (maxFromMain <= 0) {
      return SimulationResult(
        maxPieces: 0,
        materialsNeeded: {},
        materialSufficiency: {},
        totalCost: 0,
        totalRevenue: 0,
        netProfit: 0,
        costPerPiece: 0,
        limitingFactor: 'Not enough ${mainMaterial.name}',
      );
    }

    // Step 2: Check ALL other materials
    int limitingPieces = maxFromMain;
    String? limitingFactor;
    final materialsNeeded = <int, double>{};
    final materialSufficiency = <int, bool>{};

    for (var item in recipeItems) {
      final qtyPerPiece = sizeVariant.materialUsage[item.materialId] ?? 0;
      final totalNeeded = qtyPerPiece * maxFromMain;
      materialsNeeded[item.materialId] = totalNeeded;

      final material = allMaterials.firstWhere(
        (m) => m.id == item.materialId,
        orElse: () => MaterialModel(
          name: 'Unknown',
          category: 'Unknown',
          unit: 'pieces',
          currentStock: 0,
          costPerUnit: 0,
        ),
      );

      bool isEnough = material.currentStock >= totalNeeded;
      materialSufficiency[item.materialId] = isEnough;

      if (!isEnough && qtyPerPiece > 0) {
        int piecesFromThisMaterial =
            (material.currentStock / qtyPerPiece).floor();
        if (piecesFromThisMaterial < limitingPieces) {
          limitingPieces = piecesFromThisMaterial;
          limitingFactor = material.name;
        }
      }
    }

    // Step 3: Calculate costs
    double totalCost = 0;
    for (var item in recipeItems) {
      final qtyPerPiece = sizeVariant.materialUsage[item.materialId] ?? 0;
      final totalNeeded = qtyPerPiece * limitingPieces;

      double materialCost;
      if (item.isFabric && item.gsm != null && item.gsm > 0) {
        final weightInGrams = item.gsm! * totalNeeded;
        materialCost = (weightInGrams / 1000) * item.costPerUnit;
      } else {
        materialCost = totalNeeded * item.costPerUnit;
      }
      totalCost += materialCost;
    }

    final totalRevenue = product.sellingPrice * limitingPieces;
    final netProfit = totalRevenue - totalCost;
    final costPerPiece = limitingPieces > 0 ? totalCost / limitingPieces : 0;

    return SimulationResult(
      maxPieces: limitingPieces,
      materialsNeeded: materialsNeeded,
      materialSufficiency: materialSufficiency,
      totalCost: totalCost,
      totalRevenue: totalRevenue,
      netProfit: netProfit,
      costPerPiece: costPerPiece.toDouble(),
      limitingFactor: limitingFactor,
    );
  }

  Future<MaterialModel?> _getMaterial(int id) async {
    final db = await _db.database;
    final maps = await db.query('materials', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return MaterialModel.fromMap(maps.first);
    return null;
  }

  Future<ProductModel?> _getProduct(int id) async {
    final db = await _db.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return ProductModel.fromMap(maps.first);
    return null;
  }

  Future<SizeVariantModel?> _getSizeVariant(int id) async {
    final db = await _db.database;
    final maps = await db.query('size_variants',
        where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return SizeVariantModel.fromMap(maps.first);
    return null;
  }

  Future<List<RecipeItemModel>> _getRecipeItems(int productId) async {
    final db = await _db.database;
    final maps = await db.query('recipe_items',
        where: 'productId = ?', whereArgs: [productId]);
    return maps.map((map) => RecipeItemModel.fromMap(map)).toList();
  }

  Future<List<MaterialModel>> _getAllMaterials() async {
    final db = await _db.database;
    final maps = await db.query('materials');
    return maps.map((map) => MaterialModel.fromMap(map)).toList();
  }
}