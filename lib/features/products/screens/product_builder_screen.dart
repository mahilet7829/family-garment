import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getAllProducts();
      final materials = await _materialService.getAll();
      if (mounted) setState(() { _products = products; _allMaterials = materials; _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _showAddDialog() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => AddProductSheet(onSaved: _loadData, allMaterials: _allMaterials)).then((_) => _loadData());
  void _showEditDialog(ProductModel p) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => AddProductSheet(onSaved: _loadData, existing: p, allMaterials: _allMaterials)).then((_) => _loadData());
  void _openProductDetail(ProductModel p) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, onUpdated: _loadData, onEdit: (x) => _showEditDialog(x)))).then((_) => _loadData());

  Future<void> _deleteProduct(ProductModel p) async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete Product'), content: Text('Delete "${p.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete'))]));
    if (c == true) { await _productService.deleteProduct(p.id!); _loadData(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('PRODUCTS'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _showAddDialog)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _products.isEmpty ? _buildEmptyState() : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _products.length, itemBuilder: (_, i) => _productCard(_products[i])),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.05), shape: BoxShape.circle), child: Icon(Icons.checkroom_outlined, size: 56, color: AppColors.navy.withOpacity(0.4))), const SizedBox(height: 20), const Text('No products yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const SizedBox(height: 6), const Text('Create your first garment product', style: TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 20), ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('CREATE PRODUCT'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))]));

  Widget _productCard(ProductModel p) => Card(elevation: 1, shadowColor: AppColors.navy.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), margin: const EdgeInsets.only(bottom: 10), child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _openProductDetail(p), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.navy.withOpacity(0.05), image: p.imagePaths.isNotEmpty && File(p.imagePaths.first).existsSync() ? DecorationImage(image: FileImage(File(p.imagePaths.first)), fit: BoxFit.cover) : null), child: p.imagePaths.isEmpty || !File(p.imagePaths.first).existsSync() ? Icon(Icons.checkroom, color: AppColors.navy.withOpacity(0.5), size: 24) : null), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), const SizedBox(height: 4), Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Text(p.category, style: const TextStyle(fontSize: 11, color: AppColors.navy))), const SizedBox(width: 8), Text(CurrencyFormatter.format(p.sellingPrice), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.success))])])), IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.navy), onPressed: () => _showEditDialog(p)), IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error), onPressed: () => _deleteProduct(p))]))));
}

// ========== PRODUCT DETAIL SCREEN ==========
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product; final VoidCallback onUpdated; final Function(ProductModel) onEdit;
  const ProductDetailScreen({super.key, required this.product, required this.onUpdated, required this.onEdit});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}
class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductModel _product; final ProductService _ps = ProductService();
  List<SizeVariantModel> _sizes = []; List<RecipeItemModel> _recipe = []; bool _loading = true;
  @override
  void initState() { super.initState(); _product = widget.product; _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try { final s = await _ps.getSizeVariants(_product.id!); final r = await _ps.getRecipeItems(_product.id!); final u = await _ps.getProductById(_product.id!); if (mounted) setState(() { _sizes = s; _recipe = r; if (u != null) _product = u; _loading = false; }); } catch (e) { if (mounted) setState(() => _loading = false); }
  }
  void _edit() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => AddProductSheet(onSaved: () { _load(); widget.onUpdated(); }, existing: _product, allMaterials: [])).then((_) { _load(); widget.onUpdated(); });
  Future<void> _delete() async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete Product'), content: Text('Delete "${_product.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete'))]));
    if (c == true) { await _ps.deleteProduct(_product.id!); widget.onUpdated(); if (mounted) Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_product.name), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit), IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _delete)]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 200, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)), child: _product.imagePaths.isNotEmpty && File(_product.imagePaths.first).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_product.imagePaths.first), fit: BoxFit.cover)) : Center(child: Icon(Icons.checkroom, size: 56, color: AppColors.textSecondary.withOpacity(0.3)))),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [_dr('Name', _product.name), _div(), _dr('Category', _product.category), _div(), _dr('Price', CurrencyFormatter.format(_product.sellingPrice)), _div(), _dr('Created', _product.createdAt.toString().substring(0, 10)), _div(), _dr('Updated', _product.updatedAt.toString().substring(0, 10))]))),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.straighten, color: AppColors.navy, size: 18)), const SizedBox(width: 10), const Text('SIZES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy))]), const SizedBox(height: 12), _sizes.isEmpty ? const Text('No sizes added', style: TextStyle(color: AppColors.textSecondary)) : Wrap(spacing: 8, runSpacing: 8, children: _sizes.map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.05), borderRadius: BorderRadius.circular(10)), child: Text(s.sizeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.navy)))).toList())]))),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long, color: AppColors.gold, size: 18)), const SizedBox(width: 10), const Text('RECIPE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy))]), const SizedBox(height: 12), if (_recipe.isEmpty) const Text('No materials in recipe', style: TextStyle(color: AppColors.textSecondary)) else ..._recipe.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(Icons.circle, size: 8, color: item.isFabric ? AppColors.navy : AppColors.gold), const SizedBox(width: 10), Expanded(child: Text(item.materialName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))), Text('Br ${item.costPerUnit.toStringAsFixed(2)}/${item.unit}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))])))])),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: _btn('EDIT', Icons.edit_outlined, AppColors.navy, _edit)), const SizedBox(width: 12), Expanded(child: _btn('DELETE', Icons.delete_outline, AppColors.error, _delete))]),
        const SizedBox(height: 20),
      ])),
    );
  }
  Widget _btn(String l, IconData i, Color c, VoidCallback t) => ElevatedButton.icon(onPressed: t, icon: Icon(i, size: 20), label: Text(l), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right))]));
  Widget _div() => Divider(height: 1, color: AppColors.cardBorder.withOpacity(0.5));
}

// ========== ADD/EDIT PRODUCT SHEET ==========
class AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved; final ProductModel? existing; final List<MaterialModel> allMaterials;
  const AddProductSheet({super.key, required this.onSaved, this.existing, required this.allMaterials});
  @override
  State<AddProductSheet> createState() => _AddProductSheetState();
}
class _AddProductSheetState extends State<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nc = TextEditingController(), _pc = TextEditingController();
  String _cat = "Men's Wear"; File? _img; bool _saving = false;
  final List<TextEditingController> _sizes = []; final List<_RecipeItemEntry> _recipe = [];
  final ProductService _ps = ProductService();
  bool get _edit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_edit) { final p = widget.existing!; _nc.text = p.name; _pc.text = p.sellingPrice.toString(); _cat = p.category; if (p.imagePaths.isNotEmpty && File(p.imagePaths.first).existsSync()) _img = File(p.imagePaths.first); }
    else _sizes.add(TextEditingController(text: 'Medium'));
    _loadSizes(); _loadRecipe();
  }
  Future<void> _loadSizes() async { if (_edit) { final v = await _ps.getSizeVariants(widget.existing!.id!); for (var s in v) _sizes.add(TextEditingController(text: s.sizeName)); setState(() {}); } }
  Future<void> _loadRecipe() async { if (_edit) { final items = await _ps.getRecipeItems(widget.existing!.id!); for (var item in items) { final m = widget.allMaterials.firstWhere((x) => x.id == item.materialId, orElse: () => MaterialModel(name: 'Unknown', category: 'Unknown', unit: 'pieces', currentStock: 0, costPerUnit: 0)); _recipe.add(_RecipeItemEntry(material: m, qc: TextEditingController(text: '1'))); } setState(() {}); } }
  void _addSize() => setState(() => _sizes.add(TextEditingController()));
  void _remSize(int i) { if (_sizes.length > 1 || !_edit) { _sizes[i].dispose(); _sizes.removeAt(i); setState(() {}); } }
  void _addRecipe() => setState(() => _recipe.add(_RecipeItemEntry(material: widget.allMaterials.isNotEmpty ? widget.allMaterials.first : null, qc: TextEditingController(text: '1'))));
  void _remRecipe(int i) { _recipe[i].qc.dispose(); _recipe.removeAt(i); setState(() {}); }
  Future<void> _pick() async { try { final p = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800); if (p != null && mounted) setState(() => _img = File(p.path)); } catch (_) {} }

  Map<int, double> _buildMU() { final u = <int, double>{}; for (var item in _recipe) { if (item.material != null) u[item.material!.id!] = double.tryParse(item.qc.text) ?? 1.0; } return u; }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; if (_saving) return;
    final n = _nc.text.trim(), pt = _pc.text.trim();
    if (n.isEmpty) { _err('Enter product name'); return; }
    if (pt.isEmpty) { _err('Enter selling price'); return; }
    final pr = double.tryParse(pt); if (pr == null) { _err('Price must be a number'); return; }
    setState(() => _saving = true);
    try {
      List<String> ips = [];
      if (_img != null) { final dd = await getApplicationDocumentsDirectory(); final dir = Directory('${dd.path}/images'); if (!await dir.exists()) await dir.create(recursive: true); ips.add((await _img!.copy('${dir.path}/product_${DateTime.now().millisecondsSinceEpoch}.jpg')).path); }
      else if (_edit && widget.existing!.imagePaths.isNotEmpty) ips = List.from(widget.existing!.imagePaths);
      int pid;
      if (_edit) { final p = widget.existing!.copyWith(name: n, category: _cat, sellingPrice: pr, imagePaths: ips); await _ps.updateProduct(p); pid = p.id!; for (var v in await _ps.getSizeVariants(pid)) await _ps.deleteSizeVariant(v.id!); await _ps.deleteAllRecipeItems(pid); }
      else pid = await _ps.createProduct(ProductModel(name: n, category: _cat, sellingPrice: pr, imagePaths: ips));
      for (var i = 0; i < _recipe.length; i++) { final item = _recipe[i]; if (item.material != null) await _ps.createRecipeItem(RecipeItemModel(productId: pid, materialId: item.material!.id!, materialName: item.material!.name, category: item.material!.category, gsm: item.material!.gsm, unit: item.material!.unit, costPerUnit: item.material!.costPerUnit, sortOrder: i)); }
      final mu = _buildMU(); for (var c in _sizes) { final sn = c.text.trim(); if (sn.isNotEmpty) await _ps.createSizeVariant(SizeVariantModel(productId: pid, sizeName: sn, materialUsage: mu)); }
      widget.onSaved();
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_edit ? 'Product updated' : 'Product created'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }
    } catch (e) { _err('Error: $e'); } finally { if (mounted) setState(() => _saving = false); }
  }
  void _err(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).viewInsets.bottom;
    return Container(height: MediaQuery.of(context).size.height * 0.92, decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bp + 16), child: Form(key: _formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 16),
      Text(_edit ? 'EDIT PRODUCT' : 'CREATE PRODUCT', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)), const SizedBox(height: 20),
      _lbl('Product Name'), const SizedBox(height: 6), TextFormField(controller: _nc, decoration: _dec('e.g. Classic Boxer'), validator: (v) => (v == null || v!.trim().isEmpty) ? 'Required' : null), const SizedBox(height: 14),
      _lbl('Category'), const SizedBox(height: 6), DropdownButtonFormField<String>(value: _cat, decoration: _dec(null), items: ["Men's Wear", "Women's Wear", "Kids Wear", "Infants"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setState(() => _cat = v); }), const SizedBox(height: 14),
      _lbl('Selling Price (Br)'), const SizedBox(height: 6), TextFormField(controller: _pc, decoration: _dec('0.00'), keyboardType: TextInputType.number, validator: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (double.tryParse(v.trim()) == null) return 'Enter a number'; return null; }), const SizedBox(height: 18),
      _sec('Product Image', optional: true), const SizedBox(height: 8),
      GestureDetector(onTap: _pick, child: Container(height: 160, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)), child: _img != null ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_img!, fit: BoxFit.cover)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 36), SizedBox(height: 8), Text('Tap to Add Photo', style: TextStyle(color: AppColors.textSecondary))]))),
      if (_img != null) TextButton.icon(onPressed: () => setState(() => _img = null), icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16), label: const Text('Remove', style: TextStyle(color: AppColors.error))),
      const SizedBox(height: 18),
      _sec('RECIPE (Materials Needed)', action: TextButton.icon(onPressed: _addRecipe, icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.navy), label: const Text('Add', style: TextStyle(color: AppColors.navy, fontSize: 13)))), const SizedBox(height: 6),
      if (_recipe.isEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: AppColors.textSecondary, size: 16), SizedBox(width: 8), Expanded(child: Text('Add materials to build the recipe', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))])),
      ..._recipe.asMap().entries.map((e) => _buildRecipeCard(e.key, e.value)),
      const SizedBox(height: 18),
      _sec('SIZES', action: TextButton.icon(onPressed: _addSize, icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.navy), label: const Text('Add', style: TextStyle(color: AppColors.navy, fontSize: 13)))), const SizedBox(height: 6),
      ..._sizes.asMap().entries.map((e) => _buildSizeCard(e.key, e.value)),
      const SizedBox(height: 24),
      SizedBox(height: 50, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white)) : Text(_edit ? 'UPDATE PRODUCT' : 'CREATE PRODUCT', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 20),
    ])))));
  }

  Widget _buildRecipeCard(int i, _RecipeItemEntry item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)), child: DropdownButtonHideUnderline(child: DropdownButtonFormField<int>(value: item.material?.id, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8), isDense: true), isExpanded: true, dropdownColor: AppColors.white, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary), hint: Text('Select material', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 13)), items: widget.allMaterials.map((m) => DropdownMenuItem(value: m.id, child: Text('${m.name}${m.isFabric && m.gsm != null ? " (${m.gsm!.toInt()} GSM)" : ""}', style: const TextStyle(fontSize: 13)))).toList(), onChanged: (id) { if (id != null) setState(() => item.material = widget.allMaterials.firstWhere((m) => m.id == id)); })))), const SizedBox(width: 6), GestureDetector(onTap: () => _remRecipe(i), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18)))]), if (item.material != null) ...[const SizedBox(height: 10), Row(children: [const Text('Qty per piece: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), SizedBox(width: 100, child: TextFormField(controller: item.qc, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.navy, width: 2)), labelText: item.material!.unit, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 13)))])]])));

  Widget _buildSizeCard(int i, TextEditingController c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)), child: Row(children: [Expanded(child: TextFormField(controller: c, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), labelText: 'Size Name', hintText: 'Small, Medium, Large', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)))), if (_sizes.length > 1 || _edit) GestureDetector(onTap: () => _remSize(i), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, color: AppColors.error, size: 18)))])));

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  Widget _sec(String t, {bool optional = false, Widget? action}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)), if (optional) const Text(' (optional)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))]), if (action != null) action]);
  InputDecoration _dec(String? h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

  @override
  void dispose() { _nc.dispose(); _pc.dispose(); for (var c in _sizes) c.dispose(); for (var item in _recipe) item.qc.dispose(); super.dispose(); }
}

class _RecipeItemEntry {
  MaterialModel? material;
  final TextEditingController qc;
  _RecipeItemEntry({this.material, required this.qc});
}