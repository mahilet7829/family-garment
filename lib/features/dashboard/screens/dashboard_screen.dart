import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/models/product_model.dart';
import 'package:family_garment/models/size_variant_model.dart';
import 'package:family_garment/services/material_service.dart';
import 'package:family_garment/services/product_service.dart';
import 'package:family_garment/services/simulation_service.dart';
import 'result_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MaterialService _materialService = MaterialService();
  final ProductService _productService = ProductService();
  final SimulationService _simulationService = SimulationService();

  List<MaterialModel> _materials = [];
  List<ProductModel> _products = [];
  List<SizeVariantModel> _sizeVariants = [];

  MaterialModel? _selectedMaterial;
  ProductModel? _selectedProduct;
  SizeVariantModel? _selectedSize;

  final _quantityController = TextEditingController();
  int _totalProducts = 0;
  double _totalFabricKg = 0;
  int _totalMaterialTypes = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final materials = await _materialService.getAll();
      final products = await _productService.getAllProducts();

      if (mounted) {
        setState(() {
          _materials = materials;
          _products = products;
          _totalProducts = products.length;
          _totalFabricKg = materials
              .where((m) => m.isFabric)
              .fold(0.0, (sum, m) => sum + m.currentStock);
          _totalMaterialTypes = materials.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _onProductSelected(ProductModel product) async {
    _selectedProduct = product;
    _selectedSize = null;
    _sizeVariants = await _productService.getSizeVariants(product.id!);
    if (_sizeVariants.isNotEmpty) {
      _selectedSize = _sizeVariants.first;
    }
    setState(() {});
  }

  void _onCalculate() {
    if (_selectedMaterial == null) {
      _showMessage('Please select a material');
      return;
    }
    if (_selectedProduct == null) {
      _showMessage('Please select a product');
      return;
    }
    if (_selectedSize == null) {
      _showMessage('Please add sizes to this product first');
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showMessage('Please enter a valid quantity');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          material: _selectedMaterial!,
          availableQuantity: quantity,
          product: _selectedProduct!,
          sizeVariant: _selectedSize!,
          simulationService: _simulationService,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FAMILY GARMENT'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSnapshotCard(),
            const SizedBox(height: 28),
            _buildSectionHeader('WHAT-IF SIMULATOR',
                icon: Icons.calculate_rounded),
            const SizedBox(height: 16),
            _buildMaterialDropdown(),
            const SizedBox(height: 14),
            _buildQuantityInput(),
            const SizedBox(height: 14),
            _buildProductDropdown(),
            const SizedBox(height: 14),
            if (_sizeVariants.isNotEmpty) _buildSizeDropdown(),
            if (_sizeVariants.isEmpty && _selectedProduct != null)
              _buildNoSizesWarning(),
            const SizedBox(height: 28),
            _buildCalculateButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.navy, size: 22),
          const SizedBox(width: 8),
        ],
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSnapshotCard() {
    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _snapshotItem(Icons.inventory_2_rounded,
                '${_totalFabricKg.toStringAsFixed(1)} kg', 'Fabric Stock',
                AppColors.success),
            Container(
                width: 1, height: 40, color: AppColors.cardBorder),
            _snapshotItem(Icons.checkroom_rounded, '$_totalProducts',
                'Products', AppColors.navy),
            Container(
                width: 1, height: 40, color: AppColors.cardBorder),
            _snapshotItem(Icons.category_rounded, '$_totalMaterialTypes',
                'Materials', AppColors.warning),
          ],
        ),
      ),
    );
  }

  Widget _snapshotItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildMaterialDropdown() {
    return _buildCard(
      icon: Icons.inventory_2_outlined,
      label: 'I have this material',
      child: DropdownButtonFormField<int>(
        value: _selectedMaterial?.id,
        decoration: _dropdownDecoration('Select material...'),
        isExpanded: true,
        items: _materials.map((m) {
          return DropdownMenuItem(
            value: m.id,
            child: Row(
              children: [
                Icon(
                  m.isFabric ? Icons.checkroom : Icons.straighten,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${m.name}${m.isFabric && m.gsm != null ? " (${m.gsm!.toInt()} GSM)" : ""}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            setState(() => _selectedMaterial =
                _materials.firstWhere((m) => m.id == id));
          }
        },
      ),
    );
  }

  Widget _buildQuantityInput() {
    return _buildCard(
      icon: Icons.scale_outlined,
      label: 'Quantity',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount...',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.5)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.cardBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.navy, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              _selectedMaterial?.unit ?? 'unit',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDropdown() {
    return _buildCard(
      icon: Icons.checkroom_outlined,
      label: 'I want to make',
      child: DropdownButtonFormField<int>(
        value: _selectedProduct?.id,
        decoration: _dropdownDecoration('Select product...'),
        isExpanded: true,
        items: _products.map((p) {
          return DropdownMenuItem(
            value: p.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Br ${p.sellingPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            _onProductSelected(
                _products.firstWhere((p) => p.id == id));
          }
        },
      ),
    );
  }

  Widget _buildSizeDropdown() {
    return _buildCard(
      icon: Icons.straighten_outlined,
      label: 'Size',
      child: DropdownButtonFormField<int>(
        value: _selectedSize?.id,
        decoration: _dropdownDecoration('Select size...'),
        isExpanded: true,
        items: _sizeVariants.map((s) {
          return DropdownMenuItem(
            value: s.id,
            child: Text(s.sizeName),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            setState(() => _selectedSize =
                _sizeVariants.firstWhere((s) => s.id == id));
          }
        },
      ),
    );
  }

  Widget _buildNoSizesWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No sizes added. Go to Products tab to add sizes.',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _onCalculate,
        icon: const Icon(Icons.calculate_rounded, size: 24),
        label: const Text('CALCULATE YIELD & PROFIT',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          elevation: 2,
          shadowColor: AppColors.gold.withOpacity(0.3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.navy, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.navy, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}