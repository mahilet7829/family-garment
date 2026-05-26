import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/services/material_service.dart';
import 'package:family_garment/services/production_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final MaterialService _ms = MaterialService();
  final ProductionService _ps = ProductionService();
  List<MaterialModel> _laborItems = [];
  List<MaterialModel> _otherItems = [];
  Map<String, double> _monthExpenses = {};
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await _ms.getAll();
    _laborItems = all.where((m) => m.category == 'Labor').toList();
    _otherItems = all.where((m) => m.category == 'Other').toList();
    await _loadMonthExpenses();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMonthExpenses() async {
    final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final to = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    final breakdown = await _ps.getCostBreakdown(from: from, to: to);
    _monthExpenses = breakdown;
  }

  void _previousMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
    _load();
  }

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
    _load();
  }

  String _monthName(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _payExpense(MaterialModel material) async {
    final amountController = TextEditingController(text: '1');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Record ${material.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Cost: ${CurrencyFormatter.format(material.costPerUnit)}/${material.unit}'),
          const SizedBox(height: 12),
          TextField(controller: amountController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity', suffixText: material.unit, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, amountController.text), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white), child: const Text('Record')),
        ],
      ),
    );

    if (result != null && material.id != null) {
      final qty = double.tryParse(result) ?? 1;
      final totalCost = qty * material.costPerUnit;

      await _ps.recordProduction(
        productId: 0,
        productName: material.name,
        sizeName: material.category,
        quantityProduced: 1,
        totalRevenue: 0,
        totalCost: totalCost,
        netProfit: -totalCost,
        materialsToDeduct: {material.id!: qty},
        materialNames: {material.id!: material.name},
        materialCategories: {material.id!: material.category},
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${material.name}: ${CurrencyFormatter.format(totalCost)} recorded'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final laborCost = _monthExpenses['Labor'] ?? 0;
    final otherCost = _monthExpenses['Other'] ?? 0;
    final totalExpenses = laborCost + otherCost;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('MONTHLY EXPENSES'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy), onPressed: _previousMonth),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(_monthName(_selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy))),
          IconButton(icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy), onPressed: _nextMonth),
        ]),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.monetization_on, color: AppColors.error, size: 20)), const SizedBox(width: 10), const Text('TOTAL EXPENSES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy))]),
          const SizedBox(height: 12),
          Text(CurrencyFormatter.format(totalExpenses), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.error)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip('Labor', laborCost, Colors.red), const SizedBox(width: 12), _chip('Other', otherCost, Colors.purple),
          ]),
        ]))),
        const SizedBox(height: 20),
        _sectionHeader('LABOR', Icons.people, Colors.red), const SizedBox(height: 8),
        if (_laborItems.isEmpty) _emptyCard('No labor items. Add in Inventory tab.') else ..._laborItems.map((m) => _expenseCard(m)),
        const SizedBox(height: 20),
        _sectionHeader('OTHER COSTS (Transport, Rent, etc.)', Icons.local_shipping, Colors.purple), const SizedBox(height: 8),
        if (_otherItems.isEmpty) _emptyCard('No other cost items. Add in Inventory tab.') else ..._otherItems.map((m) => _expenseCard(m)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _chip(String l, double a, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('$l: ${CurrencyFormatter.format(a)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)));
  Widget _sectionHeader(String t, IconData i, Color c) => Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(i, color: c, size: 18)), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy))]);
  Widget _emptyCard(String m) => Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Text(m, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))));
  Widget _expenseCard(MaterialModel m) => Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(m.category == 'Labor' ? Icons.people : Icons.local_shipping, color: AppColors.navy, size: 20)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), Text('${CurrencyFormatter.format(m.costPerUnit)}/${m.unit}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))])),
    ElevatedButton.icon(onPressed: () => _payExpense(m), icon: const Icon(Icons.payment, size: 16), label: const Text('Pay'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
  ])));
}