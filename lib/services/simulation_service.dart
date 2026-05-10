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
  final Map<int, double> materialsNeeded; // materialId -> quantity needed
  final Map<int, bool> materialSufficiency; // materialId -> is enough?
  final double totalCost;
  final double totalRevenue;
  final double netProfit;
  final double costPerPiece;
  final String? limitingFactor; // Which material limits production

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

  /// Run a complete simulation.
  /// [materialId]: The main material the user is querying with
  /// [availableQuantity]: How much they have (in kg for fabric)
  /// [productId]: Which product they want to make
  /// [sizeVariantId]: Which size variant
  Future<SimulationResult> simulate({
    required int materialId,
    required double availableQuantity,
    required int productId,
    required int sizeVariantId,
  }) async {
    final db = await _db.database;

    // Fetch all data needed
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
      // Fabric: Convert kg to area, then divide by area per piece
      final areaPerPiece = sizeVariant.materialUsage[materialId] ?? 1.0;
      maxFromMain = YieldCalculator.calculateMaxPiecesFromFabric(
        availableWeightInKg: availableQuantity,
        fabricGsm: mainMaterial.gsm!,
        areaPerPieceInM2: areaPerPiece,
      );
    } else {
      // Non-fabric: Simple division
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

    // Step 2: Check ALL other materials for sufficiency
    int limitingPieces = maxFromMain;
    String? limitingFactor;
    final materialsNeeded = <int, double>{};
    final materialSufficiency = <int, bool>{};

    for (var item in recipeItems) {
      final qtyPerPiece = sizeVariant.materialUsage[item.materialId] ?? 0;
      final totalNeeded = qtyPerPiece * maxFromMain;
      materialsNeeded[item.materialId] = totalNeeded;

      // Find the actual material in inventory
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

      if (!isEnough) {
        // Calculate how many pieces this material can support
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
      // Calculate cost based on the material's cost per purchase unit
      double materialCost;
      if (item.isFabric && item.gsm != null && item.unit == 'kg') {
        // For fabric, cost is per kg. Convert needed m² back to kg.
        final weightInGrams = GsmCalculator.areaToWeight(
          areaInM2: totalNeeded,
          gsm: item.gsm!,
        );
        materialCost = (weightInGrams / 1000) * item.costPerUnit;
      } else {
        // For trims, direct multiplication
        materialCost = totalNeeded * item.costPerUnit;
      }
      totalCost += materialCost;
    }

    // Step 4: Calculate revenue and profit
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
      costPerPiece: costPerPiece,
      limitingFactor: limitingFactor,
    );
  }

  Future<MaterialModel?> _getMaterial(int id) async {
    final db = await _db.database;
    final maps =
        await db.query('materials', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return MaterialModel.fromMap(maps.first);
    return null;
  }

  Future<ProductModel?> _getProduct(int id) async {
    final db = await _db.database;
    final maps =
        await db.query('products', where: 'id = ?', whereArgs: [id]);
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