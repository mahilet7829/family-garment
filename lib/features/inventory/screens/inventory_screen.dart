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
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final materials = await _service.getAll(category: _filterCategory);
      if (mounted) {
        setState(() {
          _materials = materials;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddMaterialDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialFormSheet(onSaved: _loadMaterials),
    ).then((_) => _loadMaterials());
  }

  void _showEditMaterialDialog(MaterialModel material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialFormSheet(
        existing: material,
        onSaved: _loadMaterials,
      ),
    ).then((_) => _loadMaterials());
  }

  void _showGsmCalculator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const GsmCalculatorSheet(),
    );
  }

  void _openMaterialDetail(MaterialModel material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialDetailScreen(
          material: material,
          onUpdated: _loadMaterials,
          onEdit: (m) => _showEditMaterialDialog(m),
        ),
      ),
    ).then((_) => _loadMaterials());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('INVENTORY'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: _showGsmCalculator,
            tooltip: 'GSM Calculator',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: _showAddMaterialDialog,
            tooltip: 'Add Material',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', null),
                  const SizedBox(width: 8),
                  _filterChip('Fabric', 'Fabric'),
                  const SizedBox(width: 8),
                  _filterChip('Trim', 'Trim'),
                  const SizedBox(width: 8),
                  _filterChip('Packaging', 'Packaging'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _materials.length,
                        itemBuilder: (_, i) => _materialListTile(_materials[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No materials found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textSecondary.withOpacity(0.7))),
          const SizedBox(height: 8),
          Text(_filterCategory != null ? 'Try a different filter' : 'Tap + to add your first material',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          if (_filterCategory == null)
            ElevatedButton.icon(
              onPressed: _showAddMaterialDialog,
              icon: const Icon(Icons.add),
              label: const Text('ADD MATERIAL'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? category) {
    final isSelected = _filterCategory == category;
    return FilterChip(
      label: Text(label,
          style: TextStyle(color: isSelected ? AppColors.white : AppColors.navy, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterCategory = selected ? category : null);
        _loadMaterials();
      },
      backgroundColor: AppColors.white,
      selectedColor: AppColors.navy,
      checkmarkColor: AppColors.white,
      side: BorderSide(color: isSelected ? AppColors.navy : AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
  Widget _materialListTile(MaterialModel material) {
    final stockColor = material.currentStock <= 0
        ? AppColors.error
        : material.currentStock < 5
            ? AppColors.warning
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMaterialDetail(material),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Image / Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: stockColor.withOpacity(0.1),
                  image: material.imagePath != null &&
                          File(material.imagePath!).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(material.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: material.imagePath == null ||
                        !File(material.imagePath!).existsSync()
                    ? Icon(Icons.inventory_2, color: stockColor, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              // Name & Stock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: stockColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            material.stockDisplay,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // GSM Badge (only for fabric)
              if (material.isFabric && material.gsm != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${material.gsm!.toInt()}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy)),
                ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right,
                  color: AppColors.textSecondary.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }
              if (material.isFabric && material.gsm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text('${material.gsm!.toInt()} GSM', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.navy)),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.textSecondary.withOpacity(0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== MATERIAL DETAIL SCREEN ==========
class MaterialDetailScreen extends StatefulWidget {
  final MaterialModel material;
  final VoidCallback onUpdated;
  final Function(MaterialModel) onEdit;

  const MaterialDetailScreen({super.key, required this.material, required this.onUpdated, required this.onEdit});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  late MaterialModel _material;
  final MaterialService _service = MaterialService();

  @override
  void initState() {
    super.initState();
    _material = widget.material;
  }

  Future<void> _refreshMaterial() async {
    final updated = await _service.getById(_material.id!);
    if (updated != null && mounted) {
      setState(() => _material = updated);
      widget.onUpdated();
    }
  }

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialFormSheet(existing: _material, onSaved: _refreshMaterial),
    ).then((_) => _refreshMaterial());
  }

  Future<void> _deleteMaterial() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Material'),
        content: Text('Delete "${_material.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.delete(_material.id!);
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockColor = _material.currentStock <= 0
        ? AppColors.error
        : _material.currentStock < 5
            ? AppColors.warning
            : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_material.name),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _showEditDialog, tooltip: 'Edit'),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteMaterial, tooltip: 'Delete'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity, height: 200,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: _material.imagePath != null && File(_material.imagePath!).existsSync()
                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_material.imagePath!), fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 56, color: AppColors.textSecondary.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text('No Image', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.5))),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: stockColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: stockColor.withOpacity(0.3))),
              child: Row(
                children: [
                  Icon(Icons.circle, color: stockColor, size: 12),
                  const SizedBox(width: 8),
                  Text(
                    _material.currentStock <= 0 ? 'Out of Stock' : _material.currentStock < 5 ? 'Low Stock' : 'In Stock',
                    style: TextStyle(fontWeight: FontWeight.w600, color: stockColor),
                  ),
                  const Spacer(),
                  Text(_material.stockDisplay, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _detailRow('Name', _material.name), _divider(),
                    _detailRow('Category', _material.category),
                    if (_material.isFabric && _material.gsm != null) ...[
                      _divider(), _detailRow('GSM', '${_material.gsm!.toInt()} g/m²'),
                      _divider(), _detailRow('Usable Area', '${(_material.currentStock * 1000 / _material.gsm!).toStringAsFixed(2)} m²'),
                    ],
                    _divider(), _detailRow('Unit', _material.unit),
                    _divider(), _detailRow('Cost', 'Br ${_material.costPerUnit.toStringAsFixed(2)} / ${_material.unit}'),
                    _divider(), _detailRow('Total Value', 'Br ${(_material.currentStock * _material.costPerUnit).toStringAsFixed(2)}'),
                    _divider(), _detailRow('Added', _material.createdAt.toString().substring(0, 10)),
                    _divider(), _detailRow('Updated', _material.updatedAt.toString().substring(0, 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('EDIT'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _deleteMaterial,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('DELETE'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.cardBorder.withOpacity(0.5));
}

// ========== ADD/EDIT MATERIAL FORM ==========
class MaterialFormSheet extends StatefulWidget {
  final MaterialModel? existing;
  final VoidCallback onSaved;
  const MaterialFormSheet({super.key, this.existing, required this.onSaved});

  @override
  State<MaterialFormSheet> createState() => _MaterialFormSheetState();
}

class _MaterialFormSheetState extends State<MaterialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _gsmController = TextEditingController();
  final MaterialService _service = MaterialService();
  String _category = 'Fabric';
  String _unit = 'kg';
  File? _image;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final m = widget.existing!;
      _nameController.text = m.name;
      _stockController.text = m.currentStock.toString();
      _costController.text = m.costPerUnit.toString();
      _category = m.category;
      _unit = m.unit;
      if (m.gsm != null) _gsmController.text = m.gsm!.toString();
      if (m.imagePath != null && File(m.imagePath!).existsSync()) {
        _image = File(m.imagePath!);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (_) {}
  }

  void _removeImage() {
    if (mounted) setState(() => _image = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final stockText = _stockController.text.trim();
    final costText = _costController.text.trim();

    if (name.isEmpty) { _showError('Please enter a material name'); return; }
    if (stockText.isEmpty) { _showError('Please enter stock quantity'); return; }
    if (costText.isEmpty) { _showError('Please enter cost'); return; }

    final stock = double.tryParse(stockText);
    final cost = double.tryParse(costText);
    if (stock == null) { _showError('Stock must be a valid number'); return; }
    if (cost == null) { _showError('Cost must be a valid number'); return; }

    setState(() => _isSaving = true);

    try {
      String? imagePath;
      if (_image != null) {
        final docDir = await getApplicationDocumentsDirectory();
        final appDir = Directory('${docDir.path}/images');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        final fileName = 'material_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await _image!.copy('${appDir.path}/$fileName');
        imagePath = savedImage.path;
      } else if (_isEditing && widget.existing?.imagePath != null) {
        imagePath = widget.existing!.imagePath;
      }

      final material = MaterialModel(
        id: widget.existing?.id,
        name: name,
        category: _category,
        gsm: _category == 'Fabric' ? double.tryParse(_gsmController.text) : null,
        unit: _unit,
        currentStock: stock,
        costPerUnit: cost,
        imagePath: imagePath,
      );

      if (_isEditing) {
        await _service.update(material);
      } else {
        await _service.create(material);
      }

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Material updated' : 'Material added'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottomPadding + 16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(_isEditing ? 'EDIT MATERIAL' : 'ADD MATERIAL', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 20),
                _buildLabel('Category'), const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _inputDecoration(),
                  items: ['Fabric', 'Trim', 'Packaging'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() { _category = v; _unit = _category == 'Fabric' ? 'kg' : 'pieces'; if (_category != 'Fabric') _gsmController.clear(); });
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildLabel('Material Name'), const SizedBox(height: 6),
                TextFormField(controller: _nameController, decoration: _inputDecoration(hint: 'e.g. Cotton Jersey'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 16),
                if (_category == 'Fabric') ...[
                  _buildLabel('GSM (grams per square meter)'), const SizedBox(height: 6),
                  TextFormField(controller: _gsmController, decoration: _inputDecoration(hint: 'e.g. 180'), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                ],
                _buildLabel('Stock Quantity'), const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _stockController, decoration: _inputDecoration(hint: '0'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
                    const SizedBox(width: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(12), color: AppColors.background), child: Text(_unit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Cost per $_unit (Br)'), const SizedBox(height: 6),
                TextFormField(controller: _costController, decoration: _inputDecoration(hint: '0.00'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                const SizedBox(height: 20),
                _buildLabel('Material Image (optional)'), const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder, width: 1.5)),
                        child: _image != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_image!, fit: BoxFit.cover))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 28), SizedBox(height: 4), Text('Add Photo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
                      ),
                    ),
                    if (_image != null) ...[
                      const SizedBox(width: 12),
                      GestureDetector(onTap: _removeImage, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete_outline, color: AppColors.error, size: 22))),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, disabledBackgroundColor: AppColors.navy.withOpacity(0.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : Text(_isEditing ? 'UPDATE MATERIAL' : 'SAVE MATERIAL', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void dispose() {
    _nameController.dispose(); _stockController.dispose(); _costController.dispose(); _gsmController.dispose();
    super.dispose();
  }
}

// ========== GSM CALCULATOR ==========
class GsmCalculatorSheet extends StatefulWidget {
  const GsmCalculatorSheet({super.key});
  @override
  State<GsmCalculatorSheet> createState() => _GsmCalculatorSheetState();
}

class _GsmCalculatorSheetState extends State<GsmCalculatorSheet> {
  final _weightController = TextEditingController();
  final _widthController = TextEditingController(text: '10');
  final _heightController = TextEditingController(text: '10');
  double? _calculatedGsm;

  void _calculate() {
    final weight = double.tryParse(_weightController.text);
    final width = double.tryParse(_widthController.text);
    final height = double.tryParse(_heightController.text);
    if (weight != null && width != null && height != null && weight > 0 && width > 0 && height > 0) {
      setState(() {
        _calculatedGsm = GsmCalculator.calculateFromSwatch(swatchWeightInGrams: weight, swatchWidthCm: width, swatchHeightCm: height);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: bottomPadding + 20),
      decoration: const BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [const Icon(Icons.calculate, color: AppColors.navy, size: 24), const SizedBox(width: 8), const Text('GSM CALCULATOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy))]),
            const SizedBox(height: 6),
            const Text('Cut a 10×10 cm fabric swatch and weigh it on a scale.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextFormField(controller: _weightController, decoration: InputDecoration(labelText: 'Weight of swatch (grams)', labelStyle: const TextStyle(color: AppColors.textSecondary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.scale, color: AppColors.navy)), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _widthController, decoration: InputDecoration(labelText: 'Width (cm)', labelStyle: const TextStyle(color: AppColors.textSecondary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _heightController, decoration: InputDecoration(labelText: 'Height (cm)', labelStyle: const TextStyle(color: AppColors.textSecondary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            if (_calculatedGsm != null)
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                child: Column(children: [
                  const Text('FABRIC GSM', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('${_calculatedGsm!.toInt()}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.success)),
                  const Text('grams per square meter', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            const SizedBox(height: 16),
            SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _calculate, icon: const Icon(Icons.calculate, size: 20), label: const Text('CALCULATE GSM'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose(); _widthController.dispose(); _heightController.dispose();
    super.dispose();
  }
}