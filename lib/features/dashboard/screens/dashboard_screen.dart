import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/material_model.dart';
import '../../../../models/product_model.dart';
import '../../../../models/size_variant_model.dart';
import '../../../../services/material_service.dart';
import '../../../../services/product_service.dart';
import '../../../../services/simulation_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final materials = await _materialService.getAll();
    final products = await _productService.getAllProducts();

    setState(() {
      _materials = materials;
      _products = products;
      _totalProducts = products.length;
      _totalFabricKg = materials
          .where((m) => m.isFabric)
          .fold(0.0, (sum, m) => sum + m.currentStock);
    });
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
    if (_selectedMaterial == null ||
        _selectedProduct == null ||
        _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select material, product, and size')),
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FAMILY GARMENT'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSnapshotCard(),
            const SizedBox(height: 24),
            Text('WHAT-IF SIMULATOR',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            _buildDropdownCard(
              icon: Icons.inventory_2,
              label: 'I have this material:',
              child: DropdownButtonFormField<int>(
                value: _selectedMaterial?.id,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select material...',
                ),
                items: _materials.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(
                        '${m.name}${m.isFabric && m.gsm != null ? " (${m.gsm!.toInt()} GSM)" : ""}'),
                  );
                }).toList(),
                onChanged: (id) {
                  setState(() => _selectedMaterial =
                      _materials.firstWhere((m) => m.id == id));
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildDropdownCard(
              icon: Icons.scale,
              label: 'Quantity:',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter amount...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      _selectedMaterial?.unit ?? 'unit',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDropdownCard(
              icon: Icons.checkroom,
              label: 'I want to make:',
              child: DropdownButtonFormField<int>(
                value: _selectedProduct?.id,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select product...',
                ),
                items: _products.map((p) {
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} (Br ${p.sellingPrice.toStringAsFixed(2)}/pc)'),
                  );
                }).toList(),
                onChanged: (id) {
                  final product =
                      _products.firstWhere((p) => p.id == id);
                  _onProductSelected(product);
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_sizeVariants.isNotEmpty)
              _buildDropdownCard(
                icon: Icons.straighten,
                label: 'Size:',
                child: DropdownButtonFormField<int>(
                  value: _selectedSize?.id,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select size...',
                  ),
                  items: _sizeVariants.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(s.sizeName),
                    );
                  }).toList(),
                  onChanged: (id) {
                    setState(() => _selectedSize =
                        _sizeVariants.firstWhere((s) => s.id == id));
                  },
                ),
              ),
            if (_sizeVariants.isEmpty && _selectedProduct != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '⚠️ No sizes added for this product. Go to Products tab to add sizes.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _onCalculate,
                icon: const Icon(Icons.calculate, size: 24),
                label: const Text('CALCULATE YIELD & PROFIT',
                    style: TextStyle(fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('TODAY AT A GLANCE',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _snapshotItem(Icons.inventory_2,
                    '${_totalFabricKg.toStringAsFixed(1)} kg', 'Fabric Stock'),
                _snapshotItem(
                    Icons.checkroom, '$_totalProducts', 'Products'),
                _snapshotItem(
                    Icons.category, '${_materials.length}', 'Materials'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.navy, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.navy, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}