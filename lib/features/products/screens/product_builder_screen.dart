import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/product_model.dart';
import '../../../../models/material_model.dart';
import '../../../../models/size_variant_model.dart';
import '../../../../models/recipe_item_model.dart';
import '../../../../services/product_service.dart';
import '../../../../services/material_service.dart';

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
    try {
      final products = await _productService.getAllProducts();
      final materials = await _materialService.getAll();
      setState(() {
        _products = products;
        _allMaterials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(
        onSaved: _loadData,
        allMaterials: _allMaterials,
      ),
    );
  }

  void _showEditDialog(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddProductSheet(
        onSaved: _loadData,
        existing: product,
        allMaterials: _allMaterials,
      ),
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete ${product.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _productService.deleteProduct(product.id!);
      _loadData();
    }
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
            onPressed: _showAddDialog,
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
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No products yet.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('CREATE FIRST PRODUCT'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (_, i) {
                    final product = _products[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.navy.withOpacity(0.1),
                          backgroundImage: product.imagePaths.isNotEmpty &&
                                  File(product.imagePaths.first).existsSync()
                              ? FileImage(File(product.imagePaths.first))
                              : null,
                          child: product.imagePaths.isEmpty ||
                                  !File(product.imagePaths.first).existsSync()
                              ? const Icon(Icons.checkroom, color: AppColors.navy)
                              : null,
                        ),
                        title: Text(product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${product.category}  •  Br ${product.sellingPrice.toStringAsFixed(2)}/pc'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: AppColors.navy),
                              onPressed: () => _showEditDialog(product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
                              onPressed: () => _deleteProduct(product),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ========== ADD/EDIT PRODUCT SHEET ==========
class AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ProductModel? existing;
  final List<MaterialModel> allMaterials;

  const AddProductSheet({
    super.key,
    required this.onSaved,
    this.existing,
    required this.allMaterials,
  });

  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = "Men's Wear";
  File? _image;

  // Sizes
  final List<TextEditingController> _sizeControllers = [];

  // Recipe items (BOM)
  final List<_RecipeItemEntry> _recipeItems = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existing!;
      _nameController.text = p.name;
      _priceController.text = p.sellingPrice.toString();
      _category = p.category;
      if (p.imagePaths.isNotEmpty && File(p.imagePaths.first).existsSync()) {
        _image = File(p.imagePaths.first);
      }
    } else {
      _sizeControllers.add(TextEditingController(text: 'Medium'));
    }
    _loadExistingSizes();
    _loadExistingRecipe();
  }

  Future<void> _loadExistingSizes() async {
    if (_isEditing) {
      final variants =
          await ProductService().getSizeVariants(widget.existing!.id!);
      for (var v in variants) {
        _sizeControllers.add(TextEditingController(text: v.sizeName));
      }
      setState(() {});
    }
  }

  Future<void> _loadExistingRecipe() async {
    if (_isEditing) {
      final items = await ProductService().getRecipeItems(widget.existing!.id!);
      for (var item in items) {
        final material = widget.allMaterials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => MaterialModel(
            name: 'Unknown',
            category: 'Unknown',
            unit: 'pieces',
            currentStock: 0,
            costPerUnit: 0,
          ),
        );
        _recipeItems.add(_RecipeItemEntry(
          material: material,
          quantityController: TextEditingController(
              text: '1'),
        ));
      }
      setState(() {});
    }
  }

  void _addSize() {
    setState(() {
      _sizeControllers.add(TextEditingController());
    });
  }

  void _removeSize(int index) {
    setState(() {
      _sizeControllers[index].dispose();
      _sizeControllers.removeAt(index);
    });
  }

  void _addRecipeItem() {
    setState(() {
      _recipeItems.add(_RecipeItemEntry(
        material: widget.allMaterials.isNotEmpty
            ? widget.allMaterials.first
            : null,
        quantityController: TextEditingController(text: '1'),
      ));
    });
  }

  void _removeRecipeItem(int index) {
    setState(() {
      _recipeItems[index].quantityController.dispose();
      _recipeItems.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        setState(() {
          _image = File(picked.path);
        });
      }
    } catch (e) {
      // User cancelled or permission denied
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  Map<int, double> _buildMaterialUsage() {
    final usage = <int, double>{};
    for (var item in _recipeItems) {
      if (item.material != null) {
        final qty = double.tryParse(item.quantityController.text) ?? 1.0;
        usage[item.material!.id!] = qty;
      }
    }
    return usage;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final productService = ProductService();

      // Save image
      List<String> imagePaths = [];
      if (_image != null) {
        final appDir = Directory('${Directory.current.path}/app_documents/images');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await _image!.copy('${appDir.path}/$fileName');
        imagePaths.add(savedImage.path);
      } else if (_isEditing && widget.existing!.imagePaths.isNotEmpty) {
        imagePaths = List.from(widget.existing!.imagePaths);
      }

      int productId;
      if (_isEditing) {
        final product = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          category: _category,
          sellingPrice: double.parse(_priceController.text.trim()),
          imagePaths: imagePaths,
        );
        await productService.updateProduct(product);
        productId = product.id!;
        // Delete old sizes and recipe
        final oldVariants = await productService.getSizeVariants(productId);
        for (var v in oldVariants) {
          await productService.deleteSizeVariant(v.id!);
        }
        await productService.deleteAllRecipeItems(productId);
      } else {
        final product = ProductModel(
          name: _nameController.text.trim(),
          category: _category,
          sellingPrice: double.parse(_priceController.text.trim()),
          imagePaths: imagePaths,
        );
        productId = await productService.createProduct(product);
      }

      // Save recipe items (BOM)
      for (var i = 0; i < _recipeItems.length; i++) {
        final item = _recipeItems[i];
        if (item.material != null) {
          await productService.createRecipeItem(
            RecipeItemModel(
              productId: productId,
              materialId: item.material!.id!,
              materialName: item.material!.name,
              category: item.material!.category,
              gsm: item.material!.gsm,
              unit: item.material!.unit,
              costPerUnit: item.material!.costPerUnit,
              sortOrder: i,
            ),
          );
        }
      }

      // Save sizes
      final materialUsage = _buildMaterialUsage();
      for (var controller in _sizeControllers) {
        final name = controller.text.trim();
        if (name.isNotEmpty) {
          await productService.createSizeVariant(
            SizeVariantModel(
              productId: productId,
              sizeName: name,
              materialUsage: materialUsage,
            ),
          );
        }
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '✅ Product updated!' : '✅ Product created!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomPadding + 20,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_isEditing ? 'EDIT PRODUCT' : 'CREATE PRODUCT',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Category
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ["Men's Wear", "Women's Wear", "Kids Wear", "Infants"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),

                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price (Br)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Image
                const Text('Product Image (optional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_image!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  color: AppColors.textSecondary, size: 40),
                              SizedBox(height: 8),
                              Text('Tap to Add Photo',
                                  style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                    label: const Text('Remove Image',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 20),

                // RECIPE (Bill of Materials)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECIPE (Materials Needed)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addRecipeItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Material'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_recipeItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Add materials from your inventory to build the recipe.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ..._recipeItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
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
                                  value: item.material?.id,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Material',
                                    isDense: true,
                                  ),
                                  items: widget.allMaterials.map((m) {
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Text(
                                        '${m.name}${m.isFabric && m.gsm != null ? " (${m.gsm!.toInt()} GSM)" : ""}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (id) {
                                    setState(() {
                                      item.material = widget.allMaterials
                                          .firstWhere((m) => m.id == id);
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppColors.error, size: 20),
                                onPressed: () => _removeRecipeItem(index),
                              ),
                            ],
                          ),
                          if (item.material != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Qty per piece:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    controller: item.quantityController,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: item.material!.unit,
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // SIZES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SIZES',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addSize,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Size'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._sizeControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Size Name',
                                hintText: 'e.g. Small, Medium, Large',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.error, size: 20),
                            onPressed: () => _removeSize(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(
                      _isEditing ? 'UPDATE PRODUCT' : 'CREATE PRODUCT',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (var c in _sizeControllers) {
      c.dispose();
    }
    for (var item in _recipeItems) {
      item.quantityController.dispose();
    }
    super.dispose();
  }
}

class _RecipeItemEntry {
  MaterialModel? material;
  final TextEditingController quantityController;

  _RecipeItemEntry({
    this.material,
    required this.quantityController,
  });
}