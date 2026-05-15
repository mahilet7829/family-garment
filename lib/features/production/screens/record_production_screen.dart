import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/product_model.dart';
import 'package:family_garment/models/size_variant_model.dart';
import 'package:family_garment/models/production_log_model.dart';
import 'package:family_garment/services/product_service.dart';
import 'package:family_garment/services/production_service.dart';

class RecordProductionScreen extends StatefulWidget {
  const RecordProductionScreen({super.key});

  @override
  State<RecordProductionScreen> createState() =>
      _RecordProductionScreenState();
}

class _RecordProductionScreenState extends State<RecordProductionScreen> {
  final ProductService _productService = ProductService();
  final ProductionService _productionService = ProductionService();

  List<ProductModel> _products = [];
  List<SizeVariantModel> _sizeVariants = [];
  List<ProductionLogModel> _recentLogs = [];
  ProductModel? _selectedProduct;
  SizeVariantModel? _selectedSize;
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final products = await _productService.getAllProducts();
      final logs = await _productionService.getLogs();
      if (mounted) {
        setState(() {
          _products = products;
          _recentLogs = logs.take(10).toList();
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

  Future<void> _recordProduction() async {
    if (_selectedProduct == null || _selectedSize == null) {
      _showMessage('Please select a product and size', isError: true);
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showMessage('Please enter a valid quantity', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final recipeItems =
          await _productService.getRecipeItems(_selectedProduct!.id!);

      print('=== RECORD PRODUCTION DEBUG ===');
      print('Product: ${_selectedProduct!.name}');
      print('Product ID: ${_selectedProduct!.id}');
      print('Size: ${_selectedSize!.sizeName}');
      print('Size ID: ${_selectedSize!.id}');
      print('Quantity: $quantity');
      print('Recipe items count: ${recipeItems.length}');

      final materialUsage = _selectedSize!.materialUsage;
      print('Material usage map: $materialUsage');

      final materialsToDeduct = <int, double>{};
      final materialNames = <int, String>{};

      // If materialUsage is empty, build it from recipe items
      final effectiveUsage = materialUsage.isNotEmpty
          ? materialUsage
          : <int, double>{
              for (var item in recipeItems) item.materialId: 1.0
            };

      for (var item in recipeItems) {
        final qtyPerPiece = effectiveUsage[item.materialId] ?? 1.0;
        final totalNeeded = qtyPerPiece * quantity;
        print('  ${item.materialName}: qtyPerPiece=$qtyPerPiece, totalNeeded=$totalNeeded, costPerUnit=${item.costPerUnit}, unit=${item.unit}');

        if (totalNeeded > 0) {
          materialsToDeduct[item.materialId] = totalNeeded;
          materialNames[item.materialId] = item.materialName;
        }
      }

      final totalRevenue = _selectedProduct!.sellingPrice * quantity;
      double totalCost = 0;

      for (var item in recipeItems) {
        final qtyUsed = materialsToDeduct[item.materialId] ?? 0;
        final gsm = item.gsm;
        double itemCost;

        if (item.isFabric && gsm != null && gsm > 0) {
          // Fabric: qtyUsed is in m², costPerUnit is per kg
          // Convert m² to kg: weight(grams) = m² × GSM
          final weightInGrams = qtyUsed * gsm;
          itemCost = (weightInGrams / 1000) * item.costPerUnit;
          print('  FABRIC ${item.materialName}: ${qtyUsed}m² × ${gsm}GSM = ${weightInGrams}g = ${(weightInGrams/1000).toStringAsFixed(2)}kg × Br${item.costPerUnit} = Br${itemCost.toStringAsFixed(2)}');
        } else {
          // Trim/Packaging: direct multiplication
          itemCost = qtyUsed * item.costPerUnit;
          print('  TRIM ${item.materialName}: $qtyUsed ${item.unit} × Br${item.costPerUnit} = Br${itemCost.toStringAsFixed(2)}');
        }
        totalCost += itemCost;
      }

      final netProfit = totalRevenue - totalCost;

      print('=== SUMMARY ===');
      print('Revenue: Br${totalRevenue.toStringAsFixed(2)}');
      print('Cost: Br${totalCost.toStringAsFixed(2)}');
      print('Profit: Br${netProfit.toStringAsFixed(2)}');

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

      if (mounted) {
        _showMessage(
          '✅ $quantity ${_selectedProduct!.name} recorded!\nRevenue: Br${totalRevenue.toStringAsFixed(0)}\nCost: Br${totalCost.toStringAsFixed(0)}\nProfit: ${CurrencyFormatter.format(netProfit)}',
          isError: false,
        );
      }

      _quantityController.clear();
      _loadData();
    } catch (e) {
      print('ERROR: $e');
      if (mounted) {
        _showMessage('Error: $e', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('RECORD PRODUCTION'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomPadding + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader(),
            const SizedBox(height: 16),
            _buildProductDropdown(),
            const SizedBox(height: 14),
            if (_sizeVariants.isNotEmpty) _buildSizeDropdown(),
            if (_sizeVariants.isEmpty && _selectedProduct != null)
              _buildWarning('Add sizes in Products tab first.'),
            const SizedBox(height: 14),
            _buildQuantityInput(),
            const SizedBox(height: 24),
            _buildConfirmButton(),
            const SizedBox(height: 28),
            if (_recentLogs.isNotEmpty) _buildRecentLogs(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 22),
        ),
        const SizedBox(width: 12),
        const Text('Select what you made today',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildProductDropdown() {
    return _buildCard(
      icon: Icons.checkroom_outlined,
      label: 'Product',
      child: DropdownButtonFormField<int>(
        value: _selectedProduct?.id,
        decoration: _inputDecoration('Select product...'),
        isExpanded: true,
        items: _products.map((p) {
          return DropdownMenuItem(
            value: p.id,
            child: Row(
              children: [
                Expanded(child: Text(p.name)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Br ${p.sellingPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id != null) {
            _onProductSelected(_products.firstWhere((p) => p.id == id));
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
        decoration: _inputDecoration('Select size...'),
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

  Widget _buildQuantityInput() {
    return _buildCard(
      icon: Icons.numbers_outlined,
      label: 'Quantity Produced',
      child: TextFormField(
        controller: _quantityController,
        decoration: InputDecoration(
          hintText: 'How many did you make?',
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
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _recordProduction,
        icon: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.white),
              )
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(
          _isLoading ? 'RECORDING...' : 'CONFIRM PRODUCTION',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.success.withOpacity(0.5),
          elevation: 2,
          shadowColor: AppColors.success.withOpacity(0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildRecentLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.navy, size: 20),
            const SizedBox(width: 8),
            const Text('RECENT PRODUCTION',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.navy,
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentLogs.map((log) {
          final isPositive = log.netProfit >= 0;
          return Card(
            elevation: 0.5,
            shadowColor: AppColors.navy.withOpacity(0.04),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isPositive
                          ? AppColors.success
                          : AppColors.error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${log.productName} (${log.sizeName})',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '${log.quantityProduced} pieces  •  Br${log.totalRevenue.toStringAsFixed(0)} rev',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(log.netProfit),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isPositive
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(log.producedAt),
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date.toString().substring(0, 10);
  }

  Widget _buildWarning(String message) {
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
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.warning, fontSize: 13)),
          ),
        ],
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

  InputDecoration _inputDecoration(String hint) {
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