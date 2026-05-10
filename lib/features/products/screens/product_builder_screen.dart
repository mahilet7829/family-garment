import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../models/material_model.dart';
import '../../../models/size_variant_model.dart';
import '../../../models/recipe_item_model.dart';
import '../../../services/product_service.dart';
import '../../../services/material_service.dart';

class ProductBuilderScreen extends StatefulWidget {
  const ProductBuilderScreen({super.key});

  @override
  State<ProductBuilderScreen> createState() => _ProductBuilderScreenState();
}

class _ProductBuilderScreenState extends State<ProductBuilderScreen> {
  final ProductService _productService = ProductService();
  final MaterialService _materialService = MaterialService();
  List<ProductModel> _products = [];
  List<MaterialModel> _allMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final products = await _productService.getAllProducts();
    final materials = await _materialService.getAll();
    setState(() {
      _products = products;
      _allMaterials = materials;
      _isLoading = false;
    });
  }

  void _showAddProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductSheet(
        allMaterials: _allMaterials,
        onSaved: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PRODUCTS'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddProductDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checkroom,
                          size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No products yet.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showAddProductDialog,
                        child: const Text('CREATE FIRST PRODUCT'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => _productCard(_products[i]),
                ),
    );
  }

  Widget _productCard(ProductModel product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.navy.withOpacity(0.1),
          child: const Icon(Icons.checkroom, color: AppColors.navy),
        ),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${product.category} • \$${product.sellingPrice.toStringAsFixed(2)}/pc'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
              onPressed: () async {
                await _productService.deleteProduct(product.id!);
                _loadData();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Add Product Bottom Sheet
class _AddProductSheet extends StatefulWidget {
  final List<MaterialModel> allMaterials;
  final VoidCallback onSaved;

  const _AddProductSheet({
    required this.allMaterials,
    required this.onSaved,
  });

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = "Men's Wear";

  // Recipe items being added
  final List<_RecipeItemEntry> _recipeEntries = [];
  // Sizes
  final List<_SizeEntry> _sizeEntries = [];
  final _sizeNameController = TextEditingController();

  void _addRecipeItem() {
    setState(() {
      _recipeEntries.add(_RecipeItemEntry(
        material: widget.allMaterials.isNotEmpty ? widget.allMaterials.first : null,
        quantityController: TextEditingController(),
      ));
    });
  }

  void _addSize() {
    setState(() {
      _sizeEntries.add(_SizeEntry(
        nameController: TextEditingController(),
        materialQuantities: {},
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('CREATE PRODUCT',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: ["Men's Wear", "Women's Wear", "Kids Wear", "Infants"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                      labelText: 'Selling Price (\$)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Recipe Items
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECIPE ITEMS',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: _addRecipeItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                ..._recipeEntries.map((entry) => _buildRecipeEntry(entry)),
                const SizedBox(height: 20),

                // Sizes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SIZES',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: _addSize,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Size'),
                    ),
                  ],
                ),
                ..._sizeEntries.map((entry) => _buildSizeEntry(entry)),
                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        // Create product
                        final product = ProductModel(
                          name: _nameController.text,
                          category: _category,
                          sellingPrice: double.parse(_priceController.text),
                        );
                        final productId = await ProductService().createProduct(product);

                        // Create recipe items
                        for (var entry in _recipeEntries) {
                          if (entry.material != null) {
                            await ProductService().createRecipeItem(
                              RecipeItemModel(
                                productId: productId,
                                materialId: entry.material!.id!,
                                materialName: entry.material!.name,
                                category: entry.material!.category,
                                gsm: entry.material!.gsm,
                                unit: entry.material!.unit,
                                costPerUnit: entry.material!.costPerUnit,
                                sortOrder: _recipeEntries.indexOf(entry),
                              ),
                            );
                          }
                        }

                        // Create size variants
                        for (var sizeEntry in _sizeEntries) {
                          final materialUsage = <int, double>{};
                          for (var recipeEntry in _recipeEntries) {
                            if (recipeEntry.material != null && sizeEntry.materialQuantities.containsKey(recipeEntry)) {
                              materialUsage[recipeEntry.material!.id!] =
                                  final qtyController = entry.materialQuantities[recipeEntry] ?? TextEditingController(text: '1');
                            }
                          }
                          if (sizeEntry.nameController.text.isNotEmpty) {
                            await ProductService().createSizeVariant(
                              SizeVariantModel(
                                productId: productId,
                                sizeName: sizeEntry.nameController.text,
                                materialUsage: materialUsage,
                              ),
                            );
                          }
                        }

                        widget.onSaved();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('SAVE PRODUCT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeEntry(_RecipeItemEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: entry.material?.id,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Material',
                      isDense: true,
                    ),
                    items: widget.allMaterials.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (id) {
                      setState(() {
                        entry.material = widget.allMaterials.firstWhere((m) => m.id == id);
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                  onPressed: () {
                    setState(() => _recipeEntries.remove(entry));
                  },
                ),
              ],
            ),
            if (entry.material != null)
              Text(
                'Cost: \$${entry.material!.costPerUnit.toStringAsFixed(2)}/${entry.material!.unit}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeEntry(_SizeEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Size Name',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error, size: 20),
                  onPressed: () {
                    setState(() => _sizeEntries.remove(entry));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._recipeEntries.map((recipeEntry) {
              if (recipeEntry.material == null) return const SizedBox();
              final qtyController = entry.materialQuantities.putIfAbsent(
                recipeEntry,
                () => TextEditingController(text: '1'),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        recipeEntry.material!.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: qtyController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: recipeEntry.material!.unit,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _sizeNameController.dispose();
    for (var entry in _recipeEntries) {
      entry.quantityController.dispose();
    }
    for (var entry in _sizeEntries) {
      entry.nameController.dispose();
      for (var qty in entry.materialQuantities.values) {
        qty.dispose();
      }
    }
    super.dispose();
  }
}

class _RecipeItemEntry {
  MaterialModel? material;
  final TextEditingController quantityController;
  _RecipeItemEntry({this.material, required this.quantityController});
}

class _SizeEntry {
  final TextEditingController nameController;
  final Map<_RecipeItemEntry, TextEditingController> materialQuantities;
  _SizeEntry({required this.nameController, required this.materialQuantities});
}