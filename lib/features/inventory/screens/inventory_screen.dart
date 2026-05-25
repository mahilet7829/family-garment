import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/gsm_calculator.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/services/material_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final MaterialService _service = MaterialService();
  List<MaterialModel> _materials = [];
  String? _filterCategory;
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadMaterials(); }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final materials = await _service.getAll(category: _filterCategory);
      if (mounted) setState(() { _materials = materials; _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  void _showAddMaterialDialog() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MaterialFormSheet(onSaved: _loadMaterials, allMaterials: _materials)).then((_) => _loadMaterials());
  void _showEditMaterialDialog(MaterialModel m) => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MaterialFormSheet(existing: m, onSaved: _loadMaterials, allMaterials: _materials)).then((_) => _loadMaterials());
  void _showGsmCalculator() => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => const GsmCalculatorSheet());
  void _openMaterialDetail(MaterialModel m) => Navigator.push(context, MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: m, onUpdated: _loadMaterials, onEdit: (x) => _showEditMaterialDialog(x)))).then((_) => _loadMaterials());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('INVENTORY'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [
        IconButton(icon: const Icon(Icons.calculate_outlined), onPressed: _showGsmCalculator, tooltip: 'GSM Calculator'),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _showAddMaterialDialog, tooltip: 'Add'),
      ]),
      body: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _filterChip('All', null), const SizedBox(width: 8),
          _filterChip('Fabric', 'Fabric'), const SizedBox(width: 8),
          _filterChip('Trim', 'Trim'), const SizedBox(width: 8),
          _filterChip('Thread', 'Thread'), const SizedBox(width: 8),
          _filterChip('Packaging', 'Packaging'), const SizedBox(width: 8),
          _filterChip('Labor', 'Labor'), const SizedBox(width: 8),
          _filterChip('Other', 'Other'),
        ]))),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _materials.isEmpty ? _buildEmptyState() : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: _materials.length, itemBuilder: (_, i) => _materialListTile(_materials[i]))),
      ]),
    );
  }

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textSecondary.withOpacity(0.4)), const SizedBox(height: 16),
    Text('No materials found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textSecondary.withOpacity(0.7))), const SizedBox(height: 8),
    Text(_filterCategory != null ? 'Try a different filter' : 'Tap + to add your first material', style: const TextStyle(color: AppColors.textSecondary)), const SizedBox(height: 20),
    if (_filterCategory == null) ElevatedButton.icon(onPressed: _showAddMaterialDialog, icon: const Icon(Icons.add), label: const Text('ADD MATERIAL'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14))),
  ]));

  Widget _filterChip(String label, String? category) {
    final isSelected = _filterCategory == category;
    return FilterChip(label: Text(label, style: TextStyle(color: isSelected ? AppColors.white : AppColors.navy, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 12)), selected: isSelected, onSelected: (s) { setState(() => _filterCategory = s ? category : null); _loadMaterials(); }, backgroundColor: AppColors.white, selectedColor: AppColors.navy, checkmarkColor: AppColors.white, side: BorderSide(color: isSelected ? AppColors.navy : AppColors.cardBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)));
  }

  Widget _materialListTile(MaterialModel m) {
    final sc = m.currentStock <= 0 ? AppColors.error : m.currentStock < 5 ? AppColors.warning : AppColors.success;
    final icon = m.category == 'Labor' ? Icons.people : m.category == 'Other' ? Icons.more_horiz : m.category == 'Thread' ? Icons.texture : Icons.inventory_2;
    return Card(margin: const EdgeInsets.only(bottom: 8), elevation: 1, shadowColor: AppColors.navy.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _openMaterialDetail(m), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: sc.withOpacity(0.1), image: m.imagePath != null && File(m.imagePath!).existsSync() ? DecorationImage(image: FileImage(File(m.imagePath!)), fit: BoxFit.cover) : null), child: (m.imagePath == null || !File(m.imagePath!).existsSync()) ? Icon(icon, color: sc, size: 22) : null),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 3), Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)), const SizedBox(width: 5), Flexible(child: Text(m.stockDisplay, style: TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis))])])),
      if (m.isFabric && m.gsm != null) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Text('${m.gsm!.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.navy))),
      const SizedBox(width: 2), Icon(Icons.chevron_right, color: AppColors.textSecondary.withOpacity(0.4), size: 20),
    ]))));
  }
}

// ========== MATERIAL DETAIL SCREEN ==========
class MaterialDetailScreen extends StatefulWidget {
  final MaterialModel material; final VoidCallback onUpdated; final Function(MaterialModel) onEdit;
  const MaterialDetailScreen({super.key, required this.material, required this.onUpdated, required this.onEdit});
  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}
class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late MaterialModel _material; final MaterialService _service = MaterialService();
  @override
  void initState() { super.initState(); _material = widget.material; }
  Future<void> _refresh() async { final u = await _service.getById(_material.id!); if (u != null && mounted) { setState(() => _material = u); widget.onUpdated(); } }
  void _edit() => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => MaterialFormSheet(existing: _material, onSaved: _refresh, allMaterials: [])).then((_) => _refresh());
  Future<void> _delete() async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete'), content: Text('Delete "${_material.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete'))]));
    if (c == true) { await _service.delete(_material.id!); widget.onUpdated(); if (mounted) Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    final sc = _material.currentStock <= 0 ? AppColors.error : _material.currentStock < 5 ? AppColors.warning : AppColors.success;
    return Scaffold(backgroundColor: AppColors.background, appBar: AppBar(title: Text(_material.name), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _edit), IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)]), body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 200, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)), child: _material.imagePath != null && File(_material.imagePath!).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_material.imagePath!), fit: BoxFit.cover)) : Center(child: Icon(Icons.inventory_2, size: 56, color: AppColors.textSecondary.withOpacity(0.3)))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: sc.withOpacity(0.3))), child: Row(children: [Icon(Icons.circle, color: sc, size: 12), const SizedBox(width: 8), Text(_material.currentStock <= 0 ? 'Out of Stock' : _material.currentStock < 5 ? 'Low Stock' : 'In Stock', style: TextStyle(fontWeight: FontWeight.w600, color: sc)), const Spacer(), Text(_material.stockDisplay, style: const TextStyle(fontWeight: FontWeight.w600))])),
      const SizedBox(height: 20),
      Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [_dr('Name', _material.name), _div(), _dr('Category', _material.category), if (_material.isFabric && _material.gsm != null) ...[_div(), _dr('GSM', '${_material.gsm!.toInt()} g/m²'), _div(), _dr('Usable Area', '${(_material.currentStock * 1000 / _material.gsm!).toStringAsFixed(2)} m²')], _div(), _dr('Unit', _material.unit), _div(), _dr('Cost', 'Br ${_material.costPerUnit.toStringAsFixed(2)} / ${_material.unit}'), _div(), _dr('Total Value', 'Br ${(_material.currentStock * _material.costPerUnit).toStringAsFixed(2)}'), _div(), _dr('Added', _material.createdAt.toString().substring(0, 10)), _div(), _dr('Updated', _material.updatedAt.toString().substring(0, 10))]))),
      const SizedBox(height: 20),
      Row(children: [Expanded(child: _btn('EDIT', Icons.edit_outlined, AppColors.navy, _edit)), const SizedBox(width: 12), Expanded(child: _btn('DELETE', Icons.delete_outline, AppColors.error, _delete))]),
      const SizedBox(height: 20),
    ])));
  }
  Widget _btn(String l, IconData i, Color c, VoidCallback t) => ElevatedButton.icon(onPressed: t, icon: Icon(i, size: 20), label: Text(l), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));
  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right))]));
  Widget _div() => Divider(height: 1, color: AppColors.cardBorder.withOpacity(0.5));
}

// ========== ADD/EDIT MATERIAL FORM ==========
class MaterialFormSheet extends StatefulWidget {
  final MaterialModel? existing; final VoidCallback onSaved; final List<MaterialModel> allMaterials;
  const MaterialFormSheet({super.key, this.existing, required this.onSaved, required this.allMaterials});
  @override
  State<MaterialFormSheet> createState() => _MaterialFormSheetState();
}
class _MaterialFormSheetState extends State<MaterialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nc = TextEditingController(), _sc = TextEditingController(), _cc = TextEditingController(), _gc = TextEditingController();
  final MaterialService _service = MaterialService();
  String _cat = 'Fabric', _unit = 'kg';
  File? _img; bool _saving = false;
  bool get _edit => widget.existing != null;

  final List<String> _categories = ['Fabric', 'Trim', 'Thread', 'Packaging', 'Labor', 'Other'];
  final List<String> _units = ['kg', 'grams', 'meters', 'pieces', 'cones', 'liters', 'hours', 'days', 'months'];

  @override
  void initState() {
    super.initState();
    if (_edit) { final m = widget.existing!; _nc.text = m.name; _sc.text = m.currentStock.toString(); _cc.text = m.costPerUnit.toString(); _cat = m.category; _unit = m.unit; if (m.gsm != null) _gc.text = m.gsm!.toString(); if (m.imagePath != null && File(m.imagePath!).existsSync()) _img = File(m.imagePath!); }
  }

  Future<void> _pick() async { try { final p = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800); if (p != null && mounted) setState(() => _img = File(p.path)); } catch (_) {} }
  void _remImg() { if (mounted) setState(() => _img = null); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return; if (_saving) return;
    final name = _nc.text.trim(), st = _sc.text.trim(), ct = _cc.text.trim();
    if (name.isEmpty) { _err('Enter name'); return; }
    if (st.isEmpty) { _err('Enter stock/quantity'); return; }
    if (ct.isEmpty) { _err('Enter cost'); return; }
    final stock = double.tryParse(st), cost = double.tryParse(ct);
    if (stock == null) { _err('Stock must be a number'); return; }
    if (cost == null) { _err('Cost must be a number'); return; }
    for (var m in widget.allMaterials) { if (m.name.toLowerCase() == name.toLowerCase() && m.id != widget.existing?.id) { _err('A material with this name already exists'); return; } }
    setState(() => _saving = true);
    try {
      String? ip;
      if (_img != null) { final dd = await getApplicationDocumentsDirectory(); final dir = Directory('${dd.path}/images'); if (!await dir.exists()) await dir.create(recursive: true); ip = (await _img!.copy('${dir.path}/material_${DateTime.now().millisecondsSinceEpoch}.jpg')).path; }
      else if (_edit && widget.existing?.imagePath != null) ip = widget.existing!.imagePath;
      final mat = MaterialModel(id: widget.existing?.id, name: name, category: _cat, gsm: _cat == 'Fabric' ? double.tryParse(_gc.text) : null, unit: _unit, currentStock: stock, costPerUnit: cost, imagePath: ip);
      _edit ? await _service.update(mat) : await _service.create(mat);
      widget.onSaved();
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_edit ? 'Material updated' : 'Material added'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }
    } catch (e) { _err('Error: $e'); } finally { if (mounted) setState(() => _saving = false); }
  }
  void _err(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))); }

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).viewInsets.bottom;
    return Container(height: MediaQuery.of(context).size.height * 0.88, decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bp + 16), child: Form(key: _formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 16),
      Text(_edit ? 'EDIT MATERIAL' : 'ADD MATERIAL', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)), const SizedBox(height: 20),
      _lbl('Category'), const SizedBox(height: 6),
      DropdownButtonFormField<String>(value: _cat, decoration: _dec(), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) { setState(() { _cat = v; if (_cat == 'Fabric') _unit = 'kg'; if (_cat != 'Fabric') _gc.clear(); }); } }),
      const SizedBox(height: 16), _lbl('Unit'), const SizedBox(height: 6),
      DropdownButtonFormField<String>(value: _unit, decoration: _dec(), items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(), onChanged: (v) { if (v != null) setState(() => _unit = v); }),
      const SizedBox(height: 16), _lbl('Name'), const SizedBox(height: 6),
      TextFormField(controller: _nc, decoration: _dec(hint: _cat == 'Labor' ? 'e.g. Worker X Salary' : 'e.g. Cotton Jersey'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 16),
      if (_cat == 'Fabric') ...[_lbl('GSM (grams per m²)'), const SizedBox(height: 6), TextFormField(controller: _gc, decoration: _dec(hint: '180'), keyboardType: TextInputType.number), const SizedBox(height: 16)],
      _lbl(_cat == 'Labor' || _cat == 'Other' ? 'Amount' : 'Stock Quantity'), const SizedBox(height: 6),
      Row(children: [Expanded(child: TextFormField(controller: _sc, decoration: _dec(hint: '0'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)), const SizedBox(width: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(12), color: AppColors.background), child: Text(_unit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)))]),
      const SizedBox(height: 16), _lbl('Cost per $_unit (Br)'), const SizedBox(height: 6),
      TextFormField(controller: _cc, decoration: _dec(hint: '0.00'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
      const SizedBox(height: 20), _lbl('Image (optional)'), const SizedBox(height: 8),
      Row(children: [
        GestureDetector(onTap: _pick, child: Container(width: 100, height: 100, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder, width: 1.5)), child: _img != null ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_img!, fit: BoxFit.cover)) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 28), SizedBox(height: 4), Text('Add Photo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))]))),
        if (_img != null) ...[const SizedBox(width: 12), GestureDetector(onTap: _remImg, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, color: AppColors.error, size: 22)))],
      ]),
      const SizedBox(height: 24),
      SizedBox(height: 52, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, disabledBackgroundColor: AppColors.navy.withOpacity(0.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white)) : Text(_edit ? 'UPDATE MATERIAL' : 'SAVE MATERIAL', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))),
      const SizedBox(height: 16),
    ])))));
  }
  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  InputDecoration _dec({String? hint}) => InputDecoration(hintText: hint, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
  @override
  void dispose() { _nc.dispose(); _sc.dispose(); _cc.dispose(); _gc.dispose(); super.dispose(); }
}

// ========== GSM CALCULATOR ==========
class GsmCalculatorSheet extends StatefulWidget {
  const GsmCalculatorSheet({super.key});
  @override
  State<GsmCalculatorSheet> createState() => _GsmCalculatorSheetState();
}
class _GsmCalculatorSheetState extends State<GsmCalculatorSheet> {
  final _wc = TextEditingController(), _wic = TextEditingController(text: '10'), _hic = TextEditingController(text: '10');
  double? _gsm;
  void _calc() { final w = double.tryParse(_wc.text), wi = double.tryParse(_wic.text), hi = double.tryParse(_hic.text); if (w != null && wi != null && hi != null && w > 0 && wi > 0 && hi > 0) setState(() => _gsm = GsmCalculator.calculateFromSwatch(swatchWeightInGrams: w, swatchWidthCm: wi, swatchHeightCm: hi)); }
  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).viewInsets.bottom;
    return Container(padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bp + 20), decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))), const SizedBox(height: 20),
      Row(children: [const Icon(Icons.calculate, color: AppColors.navy, size: 24), const SizedBox(width: 8), const Text('GSM CALCULATOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy))]), const SizedBox(height: 6),
      const Text('Cut a 10×10 cm fabric swatch and weigh it.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)), const SizedBox(height: 20),
      TextFormField(controller: _wc, decoration: InputDecoration(labelText: 'Weight (grams)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.scale, color: AppColors.navy)), keyboardType: TextInputType.number),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextFormField(controller: _wic, decoration: InputDecoration(labelText: 'Width (cm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)), const SizedBox(width: 12), Expanded(child: TextFormField(controller: _hic, decoration: InputDecoration(labelText: 'Height (cm)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number))]),
      const SizedBox(height: 16),
      if (_gsm != null) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))), child: Column(children: [const Text('FABRIC GSM', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), const SizedBox(height: 4), Text('${_gsm!.toInt()}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.success)), const Text('grams per m²', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
      const SizedBox(height: 16),
      SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _calc, icon: const Icon(Icons.calculate, size: 20), label: const Text('CALCULATE GSM'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ])));
  }
  @override
  void dispose() { _wc.dispose(); _wic.dispose(); _hic.dispose(); super.dispose(); }
}