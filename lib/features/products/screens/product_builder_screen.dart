import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../models/product_model.dart';
import '../../../../models/material_model.dart';
import '../../../../models/size_variant_model.dart';
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

  void _showEditProductDialog(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductSheet(
        allMaterials: _allMaterials,
        onSaved: _loadData,
        existingProduct: product,
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
                          size: 80,
                          color:
                              AppColors.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text('No products yet.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddProductDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('CREATE FIRST PRODUCT'),
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
            '${product.category}  •  ${CurrencyFormatter.format(product.sellingPrice)}/pc'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: AppColors.navy),
              onPressed: () => _showEditProductDialog(product),
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  size: 20, color: AppColors.error),
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

// ========== ADD/EDIT PRODUCT FORM ==========
class _AddProductSheet extends StatefulWidget {
  final List<MaterialModel> allMaterials;
  final VoidCallback onSaved;
  final ProductModel? existingProduct;

  const _AddProductSheet({
    required this.allMaterials,
    required this.onSaved,
    this.existingProduct,
  });

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _category = "Men's Wear";

  // Image
  File? _image;
  List<File> _additionalImages = [];

  // Size entries
  final List<_SizeEntry> _sizes = [];

  bool get _isEditing => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _priceController.text = p.sellingPrice.toString();
      _category = p.category;
      if (p.imagePaths.isNotEmpty && File(p.imagePaths.first).existsSync()) {
        _image = File(p.imagePaths.first);
      }
      _loadExistingSizes();
    } else {
      _sizes.add(_SizeEntry(
          nameController: TextEditingController(text: 'Medium')));
    }
  }

  Future<void> _loadExistingSizes() async {
    final variants =
        await ProductService().getSizeVariants(widget.existingProduct!.id!);
    for (var v in variants) {
      _sizes.add(_SizeEntry(
        nameController: TextEditingController(text: v.sizeName),
        existingVariant: v,
      ));
    }
    setState(() {});
  }

  void _addSize() {
    setState(() {
      _sizes.add(_SizeEntry(nameController: TextEditingController()));
    });
  }

  void _removeSize(int index) {
    setState(() {
      _sizes[index].nameController.dispose();
      _sizes.removeAt(index);
    });
  }

  // IMAGE METHODS
  Future<void> _pickMainImage() async {
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
  }

  void _removeMainImage() {
    setState(() {
      _image = null;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final productService = ProductService();

      // Save images to local storage
      List<String> imagePaths = [];
      final appDir = Directory('${Directory.current.path}/app_documents/images');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      if (_image != null) {
        final fileName =
            'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await _image!.copy('${appDir.path}/$fileName');
        imagePaths.add(savedImage.path);
      } else if (_isEditing && widget.existingProduct!.imagePaths.isNotEmpty) {
        imagePaths = List.from(widget.existingProduct!.imagePaths);
      }

      int productId;
      if (_isEditing) {
        final product = widget.existingProduct!.copyWith(
          name: _nameController.text,
          category: _category,
          sellingPrice: double.parse(_priceController.text),
          imagePaths: imagePaths,
        );
        await productService.updateProduct(product);
        productId = product.id!;
        // Delete old size variants
        final oldVariants =
            await productService.getSizeVariants(productId);
        for (var v in oldVariants) {
          await productService.deleteSizeVariant(v.id!);
        }
      } else {
        final product = ProductModel(
          name: _nameController.text,
          category: _category,
          sellingPrice: double.parse(_priceController.text),
          imagePaths: imagePaths,
        );
        productId = await productService.createProduct(product);
      }

      // Save size variants
      for (var size in _sizes) {
        if (size.nameController.text.isNotEmpty) {
          await productService.createSizeVariant(
            SizeVariantModel(
              productId: productId,
              sizeName: size.nameController.text,
              materialUsage: {},
            ),
          );
        }
      }

      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
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
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder()),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Category
                DropdownButtonFormField(
                  value: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: [
                    "Men's Wear",
                    "Women's Wear",
                    "Kids Wear",
                    "Infants"
                  ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),

                // Price
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                      labelText: 'Selling Price (Br)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // PRODUCT IMAGE
                const Text('Product Image (optional)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickMainImage,
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
                              Text('Tap to Add Product Photo',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                if (_image != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _removeMainImage,
                    icon: const Icon(Icons.delete,
                        color: AppColors.error, size: 18),
                    label: const Text('Remove Image',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(height: 20),

                // SIZES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SIZES',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _addSize,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Size'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._sizes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final size = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: size.nameController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Size Name',
                                hintText:
                                    'e.g. Small, Medium, Large, XL',
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
                    child: Text(
                        _isEditing ? 'UPDATE PRODUCT' : 'SAVE PRODUCT'),
                  ),
                ),
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
    for (var s in _sizes) {
      s.nameController.dispose();
    }
    super.dispose();
  }
}

class _SizeEntry {
  final TextEditingController nameController;
  final SizeVariantModel? existingVariant;

  _SizeEntry({
    required this.nameController,
    this.existingVariant,
  });
}