import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/gsm_calculator.dart';
import '../../../models/material_model.dart';
import '../../../services/material_service.dart';

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

  void _showAddMaterialDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMaterialSheet(onSaved: _loadMaterials),
    );
  }

  void _showGsmCalculator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _GsmCalculatorSheet(),
    );
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
            onPressed: _showAddMaterialDialog,
            tooltip: 'Add Material',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
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
          // Material list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? const Center(
                        child: Text('No materials yet. Add some!'))
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
        labelStyle: TextStyle(color: isSelected ? AppColors.white : AppColors.navy),
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
          backgroundColor: stockColor.withOpacity(0.1),
          child: Icon(Icons.inventory_2, color: stockColor),
        ),
        title: Text(material.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(material.stockDisplay),
            Text('Cost: \$${material.costPerUnit.toStringAsFixed(2)}/${material.unit}',
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
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                // Edit functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet for adding a new material
class _AddMaterialSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddMaterialSheet({required this.onSaved});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _gsmController = TextEditingController();
  String _category = 'Fabric';
  String _unit = 'kg';
  File? _image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('ADD MATERIAL',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Material Name', border: OutlineInputBorder()),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (_category == 'Fabric')
                  TextFormField(
                    controller: _gsmController,
                    decoration: const InputDecoration(
                        labelText: 'GSM (grams/m²)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                if (_category == 'Fabric') const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        decoration: InputDecoration(
                            labelText: 'Stock ($_unit)',
                            border: const OutlineInputBorder()),
                        keyboardType: TextInputType.number,
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
                TextFormField(
                  controller: _costController,
                  decoration: InputDecoration(
                      labelText: 'Cost per $_unit (\$)',
                      border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final material = MaterialModel(
                          name: _nameController.text,
                          category: _category,
                          gsm: _category == 'Fabric'
                              ? double.tryParse(_gsmController.text)
                              : null,
                          unit: _unit,
                          currentStock:
                              double.parse(_stockController.text),
                          costPerUnit:
                              double.parse(_costController.text),
                        );
                        await MaterialService().create(material);
                        widget.onSaved();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('SAVE MATERIAL'),
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

// GSM Calculator Bottom Sheet
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
    if (weight != null && width != null && height != null) {
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('GSM CALCULATOR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Cut a swatch, weigh it, and find the exact GSM.',
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
                      labelText: 'Width (cm)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                      labelText: 'Height (cm)', border: OutlineInputBorder()),
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
                'Your GSM: ${_calculatedGsm!.toInt()}',
                style: const TextStyle(
                    fontSize: 24,
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
