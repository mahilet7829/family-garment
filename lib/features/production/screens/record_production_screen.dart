import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/product_model.dart';
import '../../../models/size_variant_model.dart';
import '../../../models/recipe_item_model.dart';
import '../../../services/product_service.dart';
import '../../../services/simulation_service.dart';
import '../../../services/production_service.dart';

class RecordProductionScreen extends StatefulWidget {
  const RecordProductionScreen({super.key});

  @override
  State<RecordProductionScreen> createState() => _RecordProductionScreenState();
}

class _RecordProductionScreenState extends State<RecordProductionScreen> {
  final ProductService _productService = ProductService();
  final SimulationService _simulationService = SimulationService();
  final ProductionService _productionService = ProductionService();

  List<ProductModel> _products = [];
  List<SizeVariantModel> _sizeVariants = [];
  ProductModel? _selectedProduct;
  SizeVariantModel? _selectedSize;
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productService.getAllProducts();
    setState(() => _products = products);
  }

  Future<void> _onProductSelected(ProductModel product) async {
    _selectedProduct = product;
    _selectedSize = null;
    _sizeVariants = await _productService.getSizeVariants(product.id!);
    setState(() {});
  }

  Future<void> _recordProduction() async {
    if (_selectedProduct == null || _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select product and size')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate materials needed
      final recipeItems = await _productService.getRecipeItems(_selectedProduct!.id!);
      final materialsToDeduct = <int, double>{};
      final materialNames = <int, String>{};

      for (var item in recipeItems) {
        final qtyPerPiece = _selectedSize!.materialUsage[item.materialId] ?? 0;
        final totalNeeded = qtyPerPiece * quantity;
        materialsToDeduct[item.materialId] = totalNeeded;
        materialNames[item.materialId] = item.materialName;
      }

      // Calculate financials
      final totalRevenue = _selectedProduct!.sellingPrice * quantity;
      double totalCost = 0;
      for (var item in recipeItems) {
        final qtyNeeded = materialsToDeduct[item.materialId] ?? 0;
        totalCost += qtyNeeded * item.costPerUnit;
      }
      final netProfit = totalRevenue - totalCost;

      // Record production
      await _productionService.recordProduction(
        productId: _selectedProduct!.id!,
        productName: _selectedProduct!.name,
        sizeName: _selectedSize!.sizeName,
        quantityProduced: quantity,
        totalRevenue: totalRevenue,
        totalCost: totalCost,
        netProfit: netProfit,
        materialsToDeduct: materialsToDeduct,
        materialNames: materialNames,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ $quantity ${_selectedProduct!.name} recorded! Profit: ${CurrencyFormatter.format(netProfit)}'),
          backgroundColor: AppColors.success,
        ),
      );

      _quantityController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RECORD PRODUCTION'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select what you made today:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedProduct?.id,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Product',
              ),
              items: _products.map((p) {
                return DropdownMenuItem(value: p.id, child: Text(p.name));
              }).toList(),
              onChanged: (id) {
                if (id != null) {
                  _onProductSelected(_products.firstWhere((p) => p.id == id));
                }
              },
            ),
            const SizedBox(height: 12),
            if (_sizeVariants.isNotEmpty)
              DropdownButtonFormField<int>(
                value: _selectedSize?.id,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Size',
                ),
                items: _sizeVariants.map((s) {
                  return DropdownMenuItem(
                      value: s.id, child: Text(s.sizeName));
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() => _selectedSize =
                        _sizeVariants.firstWhere((s) => s.id == id));
                  }
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Quantity Produced',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _recordProduction,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(_isLoading ? 'RECORDING...' : 'CONFIRM PRODUCTION',
                    style: const TextStyle(fontSize: 16, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                ),
              ),
            ),
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