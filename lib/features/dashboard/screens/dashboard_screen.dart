import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/models/product_model.dart';
import 'package:family_garment/models/size_variant_model.dart';
import 'package:family_garment/models/recipe_item_model.dart';
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
  final ProductService _productService = ProductService();
  final MaterialService _materialService = MaterialService();

  List<ProductModel> _products = [];
  List<SizeVariantModel> _sizeVariants = [];
  List<RecipeItemModel> _recipeItems = [];

  ProductModel? _selectedProduct;
  SizeVariantModel? _selectedSize;
  int _totalProducts = 0;
  double _totalFabricKg = 0;
  int _totalMaterialTypes = 0;
  final _quantityController = TextEditingController();

  // Results
  Map<String, double> _materialsNeeded = {};
  double _totalCost = 0;
  double _totalRevenue = 0;
  double _netProfit = 0;
  bool _showResults = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final products = await _productService.getAllProducts();
      final materials = await _materialService.getAll();
      if (mounted) setState(() {
        _products = products;
        _totalProducts = products.length;
        _totalFabricKg = materials.where((m) => m.isFabric).fold(0.0, (sum, m) => sum + m.currentStock);
        _totalMaterialTypes = materials.length;
      });
    } catch (_) {}
  }

  Future<void> _onProductSelected(ProductModel p) async {
    _selectedProduct = p;
    _selectedSize = null;
    _recipeItems = [];
    _showResults = false;
    _sizeVariants = await _productService.getSizeVariants(p.id!);
    _recipeItems = await _productService.getRecipeItems(p.id!);
    if (_sizeVariants.isNotEmpty) _selectedSize = _sizeVariants.first;
    setState(() {});
  }

  void _onCalculate() {
    if (_selectedProduct == null) { _showMsg('Please select a product'); return; }
    if (_selectedSize == null) { _showMsg('Please add sizes to this product first'); return; }
    final qtyText = _quantityController.text.trim();
    if (qtyText.isEmpty) { _showMsg('Please enter how many you want to make'); return; }
    final quantity = int.tryParse(qtyText);
    if (quantity == null || quantity <= 0) { _showMsg('Please enter a valid quantity'); return; }

    // Calculate materials needed
    final matUsage = _selectedSize!.materialUsage;
    final materialsNeeded = <String, double>{};
    double totalCost = 0;

    for (var item in _recipeItems) {
      final qtyPerPiece = matUsage[item.materialId] ?? 1.0;
      final totalNeeded = qtyPerPiece * quantity;
      materialsNeeded['${item.materialName} (${item.unit})'] = totalNeeded;

      if (item.isFabric && item.gsm != null && item.gsm! > 0) {
        totalCost += (totalNeeded * item.gsm! / 1000) * item.costPerUnit;
      } else {
        totalCost += totalNeeded * item.costPerUnit;
      }
    }

    final totalRevenue = _selectedProduct!.sellingPrice * quantity;
    final netProfit = totalRevenue - totalCost;

    setState(() {
      _materialsNeeded = materialsNeeded;
      _totalCost = totalCost;
      _totalRevenue = totalRevenue;
      _netProfit = netProfit;
      _showResults = true;
    });
  }

  void _showMsg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('FAMILY GARMENT'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bp + 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSnapshotCard(),
          const SizedBox(height: 28),
          _sectionHeader('WHAT-IF SIMULATOR', icon: Icons.calculate_rounded),
          const SizedBox(height: 16),
          _buildProductDropdown(),
          const SizedBox(height: 14),
          if (_sizeVariants.isNotEmpty) _buildSizeDropdown(),
          if (_sizeVariants.isEmpty && _selectedProduct != null) _buildNoSizesWarning(),
          const SizedBox(height: 14),
          _buildQuantityInput(),
          const SizedBox(height: 28),
          _buildCalculateButton(),
          if (_showResults) ...[const SizedBox(height: 24), _buildResultsCard()],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String t, {IconData? icon}) => Row(children: [if (icon != null) ...[Icon(icon, color: AppColors.navy, size: 22), const SizedBox(width: 8)], Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.5))]);

  Widget _buildSnapshotCard() => Card(elevation: 1, shadowColor: AppColors.navy.withOpacity(0.06), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
    _snap(Icons.inventory_2_rounded, '${_totalFabricKg.toStringAsFixed(1)} kg', 'Fabric Stock', AppColors.success),
    Container(width: 1, height: 40, color: AppColors.cardBorder),
    _snap(Icons.checkroom_rounded, '$_totalProducts', 'Products', AppColors.navy),
    Container(width: 1, height: 40, color: AppColors.cardBorder),
    _snap(Icons.category_rounded, '$_totalMaterialTypes', 'Materials', AppColors.warning),
  ])));

  Widget _snap(IconData i, String v, String l, Color c) => Column(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.1), shape: BoxShape.circle), child: Icon(i, color: c, size: 22)), const SizedBox(height: 10), Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navy)), const SizedBox(height: 2), Text(l, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]);

  Widget _buildProductDropdown() => _card(Icons.checkroom_outlined, 'Which product do you want to make?', DropdownButtonFormField<int>(value: _selectedProduct?.id, decoration: _dd('Select product...'), isExpanded: true, items: _products.map((p) => DropdownMenuItem(value: p.id, child: Row(children: [Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('Br ${p.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)))])),).toList(), onChanged: (id) { if (id != null) _onProductSelected(_products.firstWhere((p) => p.id == id)); }));

  Widget _buildSizeDropdown() => _card(Icons.straighten_outlined, 'Size', DropdownButtonFormField<int>(value: _selectedSize?.id, decoration: _dd('Select size...'), isExpanded: true, items: _sizeVariants.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sizeName))).toList(), onChanged: (id) { if (id != null) setState(() => _selectedSize = _sizeVariants.firstWhere((s) => s.id == id)); }));

  Widget _buildQuantityInput() => _card(Icons.numbers_outlined, 'How many do you want to make?', TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'e.g. 50', hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), suffixText: 'pieces')));

  Widget _buildNoSizesWarning() => Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.3))), child: const Row(children: [Icon(Icons.info_outline, color: AppColors.warning, size: 18), SizedBox(width: 8), Expanded(child: Text('No sizes added. Go to Products tab to add sizes.', style: TextStyle(color: AppColors.warning, fontSize: 13)))]));

  Widget _buildCalculateButton() => SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(onPressed: _onCalculate, icon: const Icon(Icons.calculate_rounded, size: 24), label: const Text('CALCULATE MATERIALS NEEDED', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy, elevation: 2, shadowColor: AppColors.gold.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))));

  Widget _buildResultsCard() {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    return Card(
      elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.check_circle, color: AppColors.success, size: 20)), const SizedBox(width: 10), Text('To make $qty ${_selectedProduct?.name ?? ""} (${_selectedSize?.sizeName ?? ""})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy))]),
        const SizedBox(height: 4),
        Text('You will need:', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 14),
        ..._materialsNeeded.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.navy, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Text(e.value.toStringAsFixed(2), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
        ]))),
        const Divider(height: 24),
        _moneyRow('Total Cost', _totalCost, AppColors.error),
        const SizedBox(height: 4),
        _moneyRow('Total Revenue', _totalRevenue, AppColors.success),
        const SizedBox(height: 4),
        _moneyRow('NET PROFIT', _netProfit, AppColors.navy, bold: true),
      ])),
    );
  }

  Widget _moneyRow(String l, double a, Color c, {bool bold = false}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 16 : 14, color: c)), Text(CurrencyFormatter.format(a), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 14, color: c))]);

  Widget _card(IconData i, String l, Widget c) => Card(elevation: 1, shadowColor: AppColors.navy.withOpacity(0.04), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(i, color: AppColors.navy, size: 18), const SizedBox(width: 8), Text(l, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))]), const SizedBox(height: 10), c])));

  InputDecoration _dd(String h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));

  @override
  void dispose() { _quantityController.dispose(); super.dispose(); }
}