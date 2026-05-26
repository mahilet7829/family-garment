import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/core/database/database_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  Map<String, double> _monthPayments = {};
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _loadExpenses();
    await _loadMonthPayments();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadExpenses() async {
    final db = await DatabaseHelper().database;
    _expenses = await db.query('expenses', orderBy: 'name ASC');
  }

  Future<void> _loadMonthPayments() async {
    final db = await DatabaseHelper().database;
    final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final to = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    final result = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM expense_payments
      WHERE paidAt >= ? AND paidAt <= ?
      GROUP BY category
    ''', [from.toIso8601String(), to.toIso8601String()]);
    _monthPayments = {};
    for (var row in result) {
      _monthPayments[row['category'] as String] = (row['total'] as num).toDouble();
    }
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

  Future<void> _addExpense() async {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    String category = 'Labor';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Expense', style: TextStyle(color: AppColors.navy)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: category,
            decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Labor', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Labor' ? 'Labor (Workers)' : 'Other (Transport, Rent, etc.)'))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => category = v); },
          ),
          const SizedBox(height: 12),
          TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Worker X Salary', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: costController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Cost (Br)', hintText: '5000', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white), child: const Text('Save')),
        ],
      )),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final cost = double.tryParse(costController.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) return;
      final db = await DatabaseHelper().database;
      await db.insert('expenses', {
        'name': name,
        'category': category,
        'monthlyCost': cost,
        'createdAt': DateTime.now().toIso8601String(),
      });
      _load();
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final nameController = TextEditingController(text: expense['name']);
    final costController = TextEditingController(text: expense['monthlyCost'].toString());
    String category = expense['category'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Expense', style: TextStyle(color: AppColors.navy)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: category,
            decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: ['Labor', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Labor' ? 'Labor (Workers)' : 'Other (Transport, Rent, etc.)'))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => category = v); },
          ),
          const SizedBox(height: 12),
          TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: costController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Cost (Br)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white), child: const Text('Save')),
        ],
      )),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final cost = double.tryParse(costController.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) return;
      final db = await DatabaseHelper().database;
      await db.update('expenses', {'name': name, 'category': category, 'monthlyCost': cost}, where: 'id = ?', whereArgs: [expense['id']]);
      _load();
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete'), content: Text('Delete "${expense['name']}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete'))]));
    if (c == true) {
      final db = await DatabaseHelper().database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [expense['id']]);
      _load();
    }
  }

  Future<void> _payExpense(Map<String, dynamic> expense) async {
    final now = DateTime.now();
    final db = await DatabaseHelper().database;

    // Check if already paid this month
    final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final to = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);
    final existing = await db.query('expense_payments', where: 'expenseId = ? AND paidAt >= ? AND paidAt <= ?', whereArgs: [expense['id'], from.toIso8601String(), to.toIso8601String()]);

    if (existing.isNotEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Already paid this month'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      return;
    }

    final cost = (expense['monthlyCost'] as num).toDouble();
    await db.insert('expense_payments', {
      'expenseId': expense['id'],
      'name': expense['name'],
      'category': expense['category'],
      'amount': cost,
      'paidAt': now.toIso8601String(),
    });

    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${expense['name']}: ${CurrencyFormatter.format(cost)} paid'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final laborCost = _monthPayments['Labor'] ?? 0;
    final otherCost = _monthPayments['Other'] ?? 0;
    final totalExpenses = laborCost + otherCost;

    final laborExpenses = _expenses.where((e) => e['category'] == 'Labor').toList();
    final otherExpenses = _expenses.where((e) => e['category'] == 'Other').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('MONTHLY EXPENSES'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _addExpense, tooltip: 'Add Expense'),
      ]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy), onPressed: _previousMonth),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(_monthName(_selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy))),
          IconButton(icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy), onPressed: _nextMonth),
        ]),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.monetization_on, color: AppColors.error, size: 20)), const SizedBox(width: 10), const Text('TOTAL EXPENSES THIS MONTH', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy))]),
          const SizedBox(height: 12),
          Text(CurrencyFormatter.format(totalExpenses), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.error)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip('Labor', laborCost, Colors.red), const SizedBox(width: 12), _chip('Other', otherCost, Colors.purple),
          ]),
        ]))),
        const SizedBox(height: 20),
        _sectionHeader('LABOR', Icons.people, Colors.red), const SizedBox(height: 8),
        if (laborExpenses.isEmpty) _emptyCard('No labor expenses. Tap + to add.') else ...laborExpenses.map((e) => _expenseCard(e)),
        const SizedBox(height: 20),
        _sectionHeader('OTHER COSTS', Icons.local_shipping, Colors.purple), const SizedBox(height: 8),
        if (otherExpenses.isEmpty) _emptyCard('No other costs. Tap + to add transport, rent, etc.') else ...otherExpenses.map((e) => _expenseCard(e)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _chip(String l, double a, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('$l: ${CurrencyFormatter.format(a)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)));
  Widget _sectionHeader(String t, IconData i, Color c) => Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(i, color: c, size: 18)), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy))]);
  Widget _emptyCard(String m) => Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Text(m, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))));

  Widget _expenseCard(Map<String, dynamic> e) {
    final cost = (e['monthlyCost'] as num).toDouble();
    final category = e['category'] as String;
    final name = e['name'] as String;
    final isLabor = category == 'Labor';

    // Check if paid this month
    bool isPaid = false;
    return Card(
      elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (isLabor ? Colors.red : Colors.purple).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(isLabor ? Icons.people : Icons.local_shipping, color: isLabor ? Colors.red : Colors.purple, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${CurrencyFormatter.format(cost)}/month', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.navy), onPressed: () => _editExpense(e), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteExpense(e), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        const SizedBox(width: 4),
        ElevatedButton.icon(onPressed: () => _payExpense(e), icon: const Icon(Icons.payment, size: 14), label: const Text('Pay', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      ])),
    );
  }
}