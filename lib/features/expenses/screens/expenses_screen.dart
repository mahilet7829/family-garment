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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _loadExpenses();
      await _loadMonthPayments();
    } catch (e) {
      debugPrint('Error in _load: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadExpenses() async {
    try {
      final db = await DatabaseHelper().database;
      _expenses = await db.query('expenses', orderBy: 'name ASC');
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      _expenses = [];
    }
  }

  Future<void> _loadMonthPayments() async {
    try {
      final db = await DatabaseHelper().database;
      final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final to = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59, 999);
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
    } catch (e) {
      debugPrint('Error loading payments: $e');
      _monthPayments = {};
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

  Future<void> _openDetail(Map<String, dynamic> expense) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: expense)));
    _load();
  }

  Future<void> _addExpense() async {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    String category = 'Labor';
    String frequency = 'monthly';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Expense', style: TextStyle(color: AppColors.navy)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: category, decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), items: ['Labor', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Labor' ? 'Labor (Workers)' : 'Other (Transport, Rent)'))).toList(), onChanged: (v) { if (v != null) setDialogState(() => category = v); }),
          const SizedBox(height: 12),
          TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name', hintText: 'e.g. Worker X Salary', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: costController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount (Br)', hintText: '5000', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: frequency, decoration: InputDecoration(labelText: 'Frequency', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), items: ['daily', 'weekly', 'monthly', 'one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(), onChanged: (v) { if (v != null) setDialogState(() => frequency = v); }),
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
      if (name.isEmpty || cost <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Name and amount are required'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        return;
      }
      try {
        final db = await DatabaseHelper().database;
        await db.insert('expenses', {
          'name': name, 'category': category, 'monthlyCost': cost,
          'expenseFrequency': frequency, 'createdAt': DateTime.now().toIso8601String(),
        });
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    final nameController = TextEditingController(text: expense['name']);
    final costController = TextEditingController(text: expense['monthlyCost'].toString());
    String category = expense['category'] as String;
    String frequency = (expense['expenseFrequency'] as String?) ?? 'monthly';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Expense', style: TextStyle(color: AppColors.navy)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: category, decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), items: ['Labor', 'Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setDialogState(() => category = v); }),
          const SizedBox(height: 12),
          TextField(controller: nameController, decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: costController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount (Br)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: frequency, decoration: InputDecoration(labelText: 'Frequency', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), items: ['daily', 'weekly', 'monthly', 'one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(), onChanged: (v) { if (v != null) setDialogState(() => frequency = v); }),
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
      try {
        final db = await DatabaseHelper().database;
        await db.update('expenses', {'name': name, 'category': category, 'monthlyCost': cost, 'expenseFrequency': frequency}, where: 'id = ?', whereArgs: [expense['id']]);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Expense updated'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete'),
      content: Text('Delete "${expense['name']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete')),
      ],
    ));
    if (c == true) {
      try {
        final db = await DatabaseHelper().database;
        await db.delete('expense_payments', where: 'expenseId = ?', whereArgs: [expense['id']]);
        await db.delete('expenses', where: 'id = ?', whereArgs: [expense['id']]);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${expense['name']} deleted'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _payExpense(Map<String, dynamic> expense) async {
    final notesController = TextEditingController();
    final now = DateTime.now();
    final db = await DatabaseHelper().database;

    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Pay ${expense['name']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Amount: ${CurrencyFormatter.format((expense['monthlyCost'] as num).toDouble())}'),
        const SizedBox(height: 12),
        TextField(controller: notesController, decoration: InputDecoration(labelText: 'Notes (optional)', hintText: 'e.g. Transport for driver Alemu', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), maxLines: 2),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white), child: const Text('Confirm Payment')),
      ],
    ));

    if (confirm == true) {
      try {
        final cost = (expense['monthlyCost'] as num).toDouble();
        await db.insert('expense_payments', {
          'expenseId': expense['id'], 'name': expense['name'], 'category': expense['category'],
          'amount': cost, 'notes': notesController.text.trim(), 'paidAt': now.toIso8601String(),
        });
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${expense['name']}: ${CurrencyFormatter.format(cost)} paid'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      }
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
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip('Labor', laborCost, Colors.red), const SizedBox(width: 12), _chip('Other', otherCost, Colors.purple),
          ])),
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
    final cost = (e['monthlyCost'] as num?)?.toDouble() ?? 0.0;
    final category = e['category'] as String? ?? 'Other';
    final name = e['name'] as String? ?? 'Unknown';
    final frequency = (e['expenseFrequency'] as String?) ?? 'monthly';
    final isLabor = category == 'Labor';

    return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.only(bottom: 8), child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openDetail(e),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (isLabor ? Colors.red : Colors.purple).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(isLabor ? Icons.people : Icons.local_shipping, color: isLabor ? Colors.red : Colors.purple, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${CurrencyFormatter.format(cost)}/$frequency', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.navy), onPressed: () => _editExpense(e), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteExpense(e), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        const SizedBox(width: 4),
        ElevatedButton.icon(onPressed: () => _payExpense(e), icon: const Icon(Icons.payment, size: 14), label: const Text('Pay', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      ])),
    ));
  }
}

class ExpenseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> expense;
  const ExpenseDetailScreen({super.key, required this.expense});
  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseHelper().database;
      _payments = await db.query('expense_payments', where: 'expenseId = ?', whereArgs: [widget.expense['id']], orderBy: 'paidAt DESC');
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final cost = (e['monthlyCost'] as num?)?.toDouble() ?? 0.0;
    final category = e['category'] as String? ?? 'Other';
    final frequency = (e['expenseFrequency'] as String?) ?? 'monthly';
    final totalPaid = _payments.fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(e['name'] as String? ?? 'Expense'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          _dr('Name', e['name'] as String? ?? ''), _div(),
          _dr('Category', category == 'Labor' ? 'Labor (Workers)' : 'Other (Transport, Rent, etc.)'), _div(),
          _dr('Monthly Cost', CurrencyFormatter.format(cost)), _div(),
          _dr('Frequency', frequency[0].toUpperCase() + frequency.substring(1)), _div(),
          _dr('Total Paid', CurrencyFormatter.format(totalPaid)), _div(),
          _dr('Remaining', CurrencyFormatter.format((cost - totalPaid).clamp(0, double.infinity))), _div(),
          _dr('Created', (e['createdAt'] as String?)?.substring(0, 10) ?? ''),
        ]))),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.history_rounded, color: AppColors.gold, size: 18)), const SizedBox(width: 10), const Text('PAYMENT HISTORY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy))]),
          const SizedBox(height: 12),
          if (_payments.isEmpty) const Text('No payments recorded yet', style: TextStyle(color: AppColors.textSecondary))
          else ..._payments.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check, color: AppColors.success, size: 16)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(CurrencyFormatter.format((p['amount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if ((p['notes'] as String?)?.isNotEmpty == true) Text(p['notes'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text((p['paidAt'] as String?)?.substring(0, 10) ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ])),
            ]),
          )),
        ]))),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right))]));
  Widget _div() => Divider(height: 1, color: AppColors.cardBorder.withOpacity(0.5));
}