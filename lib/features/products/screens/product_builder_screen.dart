import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/product_model.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/models/size_variant_model.dart';
import 'package:family_garment/models/recipe_item_model.dart';
import 'package:family_garment/services/product_service.dart';
import 'package:family_garment/services/material_service.dart';

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
      if (mounted) {
        setState(() {
          _products = products;
          _allMaterials = materials;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    ).then((_) => _loadData());
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
    ).then((_) => _loadData());
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white),
            child: const Text('Delete'),
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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: _showAddDialog,
            tooltip: 'Add Product',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (_, i) => _productCard(_products[i]),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.checkroom_outlined,
                size: 56, color: AppColors.navy.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          const Text('No products yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Create your first garment product',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('CREATE PRODUCT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(ProductModel product) {
    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditDialog(product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.navy.withOpacity(0.05),
                  image: product.imagePaths.isNotEmpty &&
                          File(product.imagePaths.first).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(product.imagePaths.first)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imagePaths.isEmpty ||
                        !File(product.imagePaths.first).existsSync()
                    ? Icon(Icons.checkroom,
                        color: AppColors.navy.withOpacity(0.5), size: 24)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(product.category,
                              style: const TextStyle(fontSize: 11, color: AppColors.navy)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(product.sellingPrice),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.navy),
                onPressed: () => _showEditDialog(product),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                onPressed: () => _deleteProduct(product),
              ),
            ],
          ),
        ),
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
  bool _isSaving = false;

  final List<TextEditingController> _sizeControllers = [];
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
      final variants = await ProductService().getSizeVariants(widget.existing!.id!);
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
          quantityController: TextEditingController(text: '1'),
        ));
      }
      setState(() {});
    }
  }

  void _addSize() {
    setState(() => _sizeControllers.add(TextEditingController()));
  }

  void _removeSize(int index) {
    if (_sizeControllers.length > 1 || !_isEditing) {
      setState(() {
        _sizeControllers[index].dispose();
        _sizeControllers.removeAt(index);
      });
    }
  }

  void _addRecipeItem() {
    setState(() {
      _recipeItems.add(_RecipeItemEntry(
        material: widget.allMaterials.isNotEmpty ? widget.allMaterials.first : null,
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
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (_) {}
  }

  void _removeImage() {
    if (mounted) setState(() => _image = null);
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
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final productService = ProductService();

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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding + 16),
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
                const SizedBox(height: 16),
                Text(_isEditing ? 'EDIT PRODUCT' : 'CREATE PRODUCT',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 20),
                _buildLabel('Product Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('e.g. Classic Boxer'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Category'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _inputDecoration(null),
                  items: ["Men's Wear", "Women's Wear", "Kids Wear", "Infants"]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _category = v); },
                ),
                const SizedBox(height: 16),
                _buildLabel('Selling Price (Br)'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceController,
                  decoration: _inputDecoration('0.00'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildSectionTitle('Product Image', optional: true),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity, height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    ),
                    child: _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_image!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 36),
                              SizedBox(height: 8),
                              Text('Tap to Add Photo', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16),
                    label: const Text('Remove Image', style: TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 20),

                // ===== RECIPE SECTION =====
                _buildSectionTitle('RECIPE (Materials Needed)',
                    action: TextButton.icon(
                      onPressed: _addRecipeItem,
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.navy),
                      label: const Text('Add', style: TextStyle(color: AppColors.navy)),
                    )),
                const SizedBox(height: 8),
                if (_recipeItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add materials from your inventory to build the recipe.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ..._recipeItems.asMap().entries.map((entry) {
                  return _buildRecipeCard(entry.key, entry.value);
                }),
                const SizedBox(height: 20),

                // ===== SIZES SECTION =====
                _buildSectionTitle('SIZES',
                    action: TextButton.icon(
                      onPressed: _addSize,
                      icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.navy),
                      label: const Text('Add', style: TextStyle(color: AppColors.navy)),
                    )),
                const SizedBox(height: 8),
                ..._sizeControllers.asMap().entries.map((entry) {
                  return _buildSizeCard(entry.key, entry.value);
                }),
                const SizedBox(height: 24),

                // ===== SAVE BUTTON =====
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : Text(
                            _isEditing ? 'UPDATE PRODUCT' : 'CREATE PRODUCT',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  Widget _buildRecipeCard(int index, _RecipeItemEntry item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<int>(
                      value: item.material?.id,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.white,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500),
                      hint: Text('Select material',
                          style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.6),
                              fontSize: 14)),
                      items: widget.allMaterials.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            '${m.name}${m.isFabric && m.gsm != null ? " (${m.gsm!.toInt()} GSM)" : ""}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          setState(() {
                            item.material = widget.allMaterials.firstWhere((m) => m.id == id);
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeRecipeItem(index),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                ),
              ),
            ],
          ),
          if (item.material != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Qty per piece:  ',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.navy, width: 2)),
                      labelText: item.material!.unit,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSizeCard(int index, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                labelText: 'Size Name',
                hintText: 'Small, Medium, Large, XL',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_sizeControllers.length > 1 || _isEditing)
            GestureDetector(
              onTap: () => _removeSize(index),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  }

  Widget _buildSectionTitle(String text, {bool optional = false, Widget? action}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(text,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy)),
            if (optional)
              const Text(' (optional)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        if (action != null) action,
      ],
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  _RecipeItemEntry({this.material, required this.quantityController});
}