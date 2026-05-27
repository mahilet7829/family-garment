import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/expense_model.dart';
import 'package:family_garment/services/expense_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();
  List<ExpenseModel> _expenses = [];
  Map<String, double> _monthPayments = {};
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try { _expenses = await _service.getAllExpenses(); _monthPayments = await _service.getMonthlySummary(_selectedMonth); } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _previousMonth() { setState(() { _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1); }); _load(); }
  void _nextMonth() { setState(() { _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1); }); _load(); }

  String _monthName(DateTime d) { const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${m[d.month-1]} ${d.year}'; }

  Future<void> _openDetail(ExpenseModel expense) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: expense)));
    _load();
  }

  Future<void> _addExpense() async {
    final nc = TextEditingController(); final cc = TextEditingController();
    String cat = 'Labor'; String freq = 'monthly';
    final r = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Expense', style: TextStyle(color: AppColors.navy, fontSize: 18)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _lbl('Type'), const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: cat, decoration: _dd(), items: ['Labor','Other'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Labor' ? 'Labor (Workers)' : 'Other (Transport, Rent)'))).toList(), onChanged: (v) { if (v != null) setSt(() => cat = v); }),
        const SizedBox(height: 14), _lbl('Name'), const SizedBox(height: 6),
        TextField(controller: nc, decoration: _dec('e.g. Worker X Salary')),
        const SizedBox(height: 14), _lbl('Amount (Br)'), const SizedBox(height: 6),
        TextField(controller: cc, keyboardType: TextInputType.number, decoration: _dec('5000')),
        const SizedBox(height: 14), _lbl('Frequency'), const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: freq, decoration: _dd(), items: ['daily','weekly','monthly','one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(), onChanged: (v) { if (v != null) setSt(() => freq = v); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save'))],
    )));
    if (r == true) {
      final name = nc.text.trim(); final cost = double.tryParse(cc.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) return;
      await _service.createExpense(ExpenseModel(name: name, category: cat, monthlyCost: cost, expenseFrequency: freq));
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<void> _payExpense(ExpenseModel expense) async {
    final nc = TextEditingController();
    final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Pay ${expense.name}', style: const TextStyle(color: AppColors.navy, fontSize: 16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Amount: ${CurrencyFormatter.format(expense.monthlyCost)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16), _lbl('Notes (optional)'), const SizedBox(height: 6),
        TextField(controller: nc, decoration: _dec('e.g. Transport for driver Alemu'), maxLines: 2),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Confirm Payment'))],
    ));
    if (r == true) {
      await _service.createPayment(ExpensePaymentModel(expenseId: expense.id!, name: expense.name, category: expense.category, amount: expense.monthlyCost, notes: nc.text.trim()));
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${expense.name}: ${CurrencyFormatter.format(expense.monthlyCost)} paid'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lc = _monthPayments['Labor'] ?? 0; final oc = _monthPayments['Other'] ?? 0;
    final lab = _expenses.where((e) => e.category == 'Labor').toList();
    final oth = _expenses.where((e) => e.category == 'Other').toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('MONTHLY EXPENSES'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _addExpense)]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.navy), onPressed: _previousMonth),
          Text(_monthName(_selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
          IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.navy), onPressed: _nextMonth),
        ])),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyLight]), borderRadius: BorderRadius.circular(20)), child: Column(children: [
          const Text('TOTAL EXPENSES THIS MONTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldLight)),
          const SizedBox(height: 12),
          Text(CurrencyFormatter.format(lc + oc), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.white)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_chip('Labor', lc, AppColors.gold), const SizedBox(width: 16), _chip('Other', oc, AppColors.goldLight)]),
        ])),
        const SizedBox(height: 24),
        _section('LABOR', Icons.people, Colors.red), const SizedBox(height: 10),
        if (lab.isEmpty) _empty('No labor expenses. Tap + to add.') else ...lab.map((e) => _card(e)),
        const SizedBox(height: 24),
        _section('OTHER COSTS', Icons.local_shipping, Colors.purple), const SizedBox(height: 10),
        if (oth.isEmpty) _empty('No other costs. Tap + to add.') else ...oth.map((e) => _card(e)),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _chip(String l, double a, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text('$l: ${CurrencyFormatter.format(a)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)));
  Widget _section(String t, IconData i, Color c) => Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 20)), const SizedBox(width: 10), Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)), const Spacer(), Text('${_expenses.where((e) => e.category == (t.startsWith('L') ? 'Labor' : 'Other')).length} items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]);
  Widget _empty(String m) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)), child: Row(children: [Icon(Icons.info_outline, color: AppColors.textSecondary.withOpacity(0.5), size: 24), const SizedBox(width: 12), Expanded(child: Text(m, style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13)))]));

  Widget _card(ExpenseModel e) {
    final isLabor = e.category == 'Labor'; final color = isLabor ? Colors.red : Colors.purple;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14), onTap: () => _openDetail(e),
        child: Column(children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isLabor ? Icons.people : Icons.local_shipping, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(e.expenseFrequency, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
                const SizedBox(width: 8),
                Text(CurrencyFormatter.format(e.monthlyCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
              ]),
            ])),
            Icon(Icons.chevron_right, color: AppColors.textSecondary.withOpacity(0.4), size: 22),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Material(color: Colors.transparent, child: InkWell(onTap: () => _payExpense(e), borderRadius: BorderRadius.circular(8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.success.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.payment, size: 14, color: AppColors.success), const SizedBox(width: 6), const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success))])))),
          ]),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
  InputDecoration _dd() => const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4));
}

// ========== EXPENSE DETAIL SCREEN ==========
class ExpenseDetailScreen extends StatefulWidget {
  final ExpenseModel expense;
  const ExpenseDetailScreen({super.key, required this.expense});
  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final ExpenseService _service = ExpenseService();
  List<ExpensePaymentModel> _payments = [];
  late ExpenseModel _expense;
  bool _loading = true;

  @override
  void initState() { super.initState(); _expense = widget.expense; _load(); }

  Future<void> _load() async { setState(() => _loading = true); _payments = await _service.getPayments(_expense.id!); if (mounted) setState(() => _loading = false); }

  Future<void> _editExpense() async {
    final nc = TextEditingController(text: _expense.name); final cc = TextEditingController(text: _expense.monthlyCost.toString());
    String cat = _expense.category; String freq = _expense.expenseFrequency;
    final r = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Edit Expense', style: TextStyle(color: AppColors.navy)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _lbl('Type'), const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: cat, decoration: _dd(), items: ['Labor','Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setSt(() => cat = v); }),
        const SizedBox(height: 14), _lbl('Name'), const SizedBox(height: 6),
        TextField(controller: nc, decoration: _dec(null)), const SizedBox(height: 14),
        _lbl('Amount (Br)'), const SizedBox(height: 6),
        TextField(controller: cc, keyboardType: TextInputType.number, decoration: _dec(null)), const SizedBox(height: 14),
        _lbl('Frequency'), const SizedBox(height: 6),
        DropdownButtonFormField<String>(value: freq, decoration: _dd(), items: ['daily','weekly','monthly','one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(), onChanged: (v) { if (v != null) setSt(() => freq = v); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save'))],
    )));
    if (r == true) {
      final name = nc.text.trim(); final cost = double.tryParse(cc.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) return;
      await _service.updateExpense(ExpenseModel(id: _expense.id, name: name, category: cat, monthlyCost: cost, expenseFrequency: freq));
      setState(() { _expense = ExpenseModel(id: _expense.id, name: name, category: cat, monthlyCost: cost, expenseFrequency: freq, createdAt: _expense.createdAt); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Updated'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<void> _deleteExpense() async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete'), content: Text('Delete "${_expense.name}"?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete'))]));
    if (c == true) { await _service.deleteExpense(_expense.id!); if (mounted) Navigator.pop(context, true); }
  }

  @override
  Widget build(BuildContext context) {
    final totalPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    final isLabor = _expense.category == 'Labor'; final color = isLabor ? Colors.red : Colors.purple;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_expense.name), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editExpense), IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _deleteExpense)]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.8), color]), borderRadius: BorderRadius.circular(20)), child: Column(children: [
          Icon(isLabor ? Icons.people : Icons.local_shipping, color: AppColors.white, size: 40),
          const SizedBox(height: 12),
          Text(CurrencyFormatter.format(_expense.monthlyCost), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.white)),
          Text('per ${_expense.expenseFrequency}', style: const TextStyle(fontSize: 14, color: AppColors.goldLight)),
        ])),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          _dr('Name', _expense.name), _div(), _dr('Category', isLabor ? 'Labor' : 'Other'), _div(),
          _dr('Amount', CurrencyFormatter.format(_expense.monthlyCost)), _div(),
          _dr('Frequency', _expense.expenseFrequency), _div(),
          _dr('Total Paid', CurrencyFormatter.format(totalPaid)), _div(),
          _dr('Remaining', CurrencyFormatter.format((_expense.monthlyCost - totalPaid).clamp(0, double.infinity))), _div(),
          _dr('Created', _expense.createdAt.toString().substring(0, 10)),
        ]))),
        const SizedBox(height: 20),
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.history_rounded, color: AppColors.gold, size: 18)), const SizedBox(width: 10), const Text('PAYMENT HISTORY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)), const Spacer(), Text('${_payments.length} payments', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
          const SizedBox(height: 12),
          if (_payments.isEmpty) const Text('No payments yet', style: TextStyle(color: AppColors.textSecondary))
          else ..._payments.map((p) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)), child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.check, color: AppColors.success, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(CurrencyFormatter.format(p.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (p.notes.isNotEmpty) Text(p.notes, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(p.paidAt.toString().substring(0, 16).replaceAll('T', ' '), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ])),
          ]))),
        ]))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: _editExpense, icon: const Icon(Icons.edit_outlined, size: 20), label: const Text('EDIT'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: _deleteExpense, icon: const Icon(Icons.delete_outline, size: 20), label: const Text('DELETE'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ]),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.right))]));
  Widget _div() => Divider(height: 1, color: AppColors.cardBorder.withOpacity(0.5));
  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  InputDecoration _dec(String? h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
  InputDecoration _dd() => const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4));
}