import '../core/database/database_helper.dart';
import '../models/product_model.dart';
import '../models/size_variant_model.dart';
import '../models/recipe_item_model.dart';

/// Handles all CRUD for products, size variants, and recipe items.
class ProductService {
  final DatabaseHelper _db = DatabaseHelper();

  // ========== PRODUCTS ==========

  Future<int> createProduct(ProductModel product) async {
    final db = await _db.database;
    return await db.insert('products', product.toMap());
  }

  Future<List<ProductModel>> getAllProducts() async {
    final db = await _db.database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  Future<ProductModel?> getProductById(int id) async {
    final db = await _db.database;
    final maps =
        await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return ProductModel.fromMap(maps.first);
    return null;
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await _db.database;
    return await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await _db.database;
    // Delete associated size variants and recipe items first (cascade)
    await db.delete('size_variants', where: 'productId = ?', whereArgs: [id]);
    await db.delete('recipe_items', where: 'productId = ?', whereArgs: [id]);
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ========== SIZE VARIANTS ==========

  Future<int> createSizeVariant(SizeVariantModel variant) async {
    final db = await _db.database;
    return await db.insert('size_variants', variant.toMap());
  }

  Future<List<SizeVariantModel>> getSizeVariants(int productId) async {
    final db = await _db.database;
    final maps = await db.query('size_variants',
        where: 'productId = ?', whereArgs: [productId]);
    return maps.map((map) => SizeVariantModel.fromMap(map)).toList();
  }

  Future<int> updateSizeVariant(SizeVariantModel variant) async {
    final db = await _db.database;
    return await db.update('size_variants', variant.toMap(),
        where: 'id = ?', whereArgs: [variant.id]);
  }

  Future<int> deleteSizeVariant(int id) async {
    final db = await _db.database;
    return await db.delete('size_variants', where: 'id = ?', whereArgs: [id]);
  }

  // ========== RECIPE ITEMS ==========

  Future<int> createRecipeItem(RecipeItemModel item) async {
    final db = await _db.database;
    return await db.insert('recipe_items', item.toMap());
  }

  Future<List<RecipeItemModel>> getRecipeItems(int productId) async {
    final db = await _db.database;
    final maps = await db.query('recipe_items',
        where: 'productId = ?',
        whereArgs: [productId],
        orderBy: 'sortOrder ASC');
    return maps.map((map) => RecipeItemModel.fromMap(map)).toList();
  }

  Future<int> updateRecipeItem(RecipeItemModel item) async {
    final db = await _db.database;
    return await db.update('recipe_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteRecipeItem(int id) async {
    final db = await _db.database;
    return await db.delete('recipe_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllRecipeItems(int productId) async {
    final db = await _db.database;
    await db
        .delete('recipe_items', where: 'productId = ?', whereArgs: [productId]);
  }
}