import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/gsm_calculator.dart';
import '../../../../models/material_model.dart';
import '../../../../services/material_service.dart';

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
    final materials = await _service.getAll(category: _filterCategory);
    setState(() {
      _materials = materials;
      _isLoading = false;
    });
  }

  void _showAddMaterialDialog({MaterialModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MaterialFormSheet(
        existing: existing,
        onSaved: _loadMaterials,
      ),
    );
  }

  void _showGsmCalculator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GsmCalculatorSheet(),
    );
  }

  Future<void> _deleteMaterial(MaterialModel material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Delete ${material.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.delete(material.id!);
      _loadMaterials();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('INVENTORY'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            onPressed: _showGsmCalculator,
            tooltip: 'GSM Calculator',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMaterialDialog(),
            tooltip: 'Add Material',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', null),
                  _filterChip('Fabric', 'Fabric'),
                  _filterChip('Trim', 'Trim'),
                  _filterChip('Packaging', 'Packaging'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 80,
                                color:
                                    AppColors.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text('No materials yet.'),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddMaterialDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('ADD FIRST MATERIAL'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _materials.length,
                        itemBuilder: (_, i) => _materialCard(_materials[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? category) {
    final isSelected = _filterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filterCategory = selected ? category : null);
          _loadMaterials();
        },
        selectedColor: AppColors.navy,
        labelStyle: TextStyle(
            color: isSelected ? AppColors.white : AppColors.navy),
      ),
    );
  }

  Widget _materialCard(MaterialModel material) {
    final stockColor = material.currentStock <= 0
        ? AppColors.error
        : material.currentStock < 10
            ? AppColors.warning
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: stockColor.withOpacity(0.1),
          backgroundImage: material.imagePath != null &&
                  File(material.imagePath!).existsSync()
              ? FileImage(File(material.imagePath!))
              : null,
          child: material.imagePath == null ||
                  !File(material.imagePath!).existsSync()
              ? Icon(Icons.inventory_2, color: stockColor)
              : null,
        ),
        title: Text(material.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(material.stockDisplay),
            Text(
                'Br ${material.costPerUnit.toStringAsFixed(2)}/${material.unit}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (material.isFabric && material.gsm != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${material.gsm!.toInt()} GSM',
                    style: const TextStyle(fontSize: 12)),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon:
                  const Icon(Icons.edit, size: 20, color: AppColors.navy),
              onPressed: () => _showAddMaterialDialog(existing: material),
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  size: 20, color: AppColors.error),
              onPressed: () => _deleteMaterial(material),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== ADD/EDIT MATERIAL FORM ==========
class _MaterialFormSheet extends StatefulWidget {
  final MaterialModel? existing;
  final VoidCallback onSaved;
  const _MaterialFormSheet({this.existing, required this.onSaved});

  @override
  State<_MaterialFormSheet> createState() => _MaterialFormSheetState();
}

class _MaterialFormSheetState extends State<_MaterialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _gsmController = TextEditingController();
  String _category = 'Fabric';
  String _unit = 'kg';
  File? _image;

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

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      // Save image to app's local storage if picked
      String? imagePath;
      if (_image != null) {
        final appDir = Directory(
            '${(await getApplicationDocumentsDirectory()).path}/images');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        final fileName =
            'material_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await _image!.copy('${appDir.path}/$fileName');
        imagePath = savedImage.path;
      } else if (_isEditing && widget.existing?.imagePath != null) {
        imagePath = widget.existing!.imagePath;
      }

      final material = MaterialModel(
        id: widget.existing?.id,
        name: _nameController.text,
        category: _category,
        gsm:
            _category == 'Fabric' ? double.tryParse(_gsmController.text) : null,
        unit: _unit,
        currentStock: double.parse(_stockController.text),
        costPerUnit: double.parse(_costController.text),
        imagePath: imagePath,
      );

      if (_isEditing) {
        await MaterialService().update(material);
      } else {
        await MaterialService().create(material);
      }

      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
                Text(_isEditing ? 'EDIT MATERIAL' : 'ADD MATERIAL',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Category
                DropdownButtonFormField(
                  value: _category,
                  decoration: const InputDecoration(
                      labelText: 'Category', border: OutlineInputBorder()),
                  items: ['Fabric', 'Trim', 'Packaging']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _category = v!;
                      _unit = _category == 'Fabric' ? 'kg' : 'pieces';
                      if (_category != 'Fabric') _gsmController.clear();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Material Name',
                      border: OutlineInputBorder()),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // GSM (only for Fabric)
                if (_category == 'Fabric')
                  TextFormField(
                    controller: _gsmController,
                    decoration: const InputDecoration(
                        labelText: 'GSM (grams/m²)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                if (_category == 'Fabric') const SizedBox(height: 12),

                // Stock
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        decoration: InputDecoration(
                            labelText: 'Stock ($_unit)',
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_unit),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cost
                TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                      labelText: 'Cost per $_unit (Br)',
                      border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // IMAGE PICKER
                const Text('Material Image (optional)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppColors.cardBorder),
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!,
                                    fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      color: AppColors.textSecondary,
                                      size: 30),
                                  SizedBox(height: 4),
                                  Text('Add Photo',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              AppColors.textSecondary)),
                                ],
                              ),
                      ),
                    ),
                    if (_image != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: AppColors.error, size: 28),
                        onPressed: _removeImage,
                        tooltip: 'Remove image',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(_isEditing
                        ? 'UPDATE MATERIAL'
                        : 'SAVE MATERIAL'),
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
    _stockController.dispose();
    _costController.dispose();
    _gsmController.dispose();
    super.dispose();
  }
}

// Need this helper to get app directory
Future<Directory> getApplicationDocumentsDirectory() async {
  final directory = Directory(
      '${Directory.current.path}/app_documents');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

// ========== GSM CALCULATOR ==========
class _GsmCalculatorSheet extends StatefulWidget {
  @override
  State<_GsmCalculatorSheet> createState() => _GsmCalculatorSheetState();
}

class _GsmCalculatorSheetState extends State<_GsmCalculatorSheet> {
  final _weightController = TextEditingController();
  final _widthController = TextEditingController(text: '10');
  final _heightController = TextEditingController(text: '10');
  double? _calculatedGsm;

  void _calculate() {
    final weight = double.tryParse(_weightController.text);
    final width = double.tryParse(_widthController.text);
    final height = double.tryParse(_heightController.text);
    if (weight != null && width != null && height != null && weight > 0) {
      setState(() {
        _calculatedGsm = GsmCalculator.calculateFromSwatch(
          swatchWeightInGrams: weight,
          swatchWidthCm: width,
          swatchHeightCm: height,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const Text('🧵 GSM CALCULATOR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Cut a swatch, weigh it, find exact GSM.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _weightController,
            decoration: const InputDecoration(
                labelText: 'Weight of swatch (grams)',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _widthController,
                  decoration: const InputDecoration(
                      labelText: 'Width (cm)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_calculatedGsm != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'GSM: ${_calculatedGsm!.toInt()}',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _calculate,
            child: const Text('CALCULATE GSM'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}