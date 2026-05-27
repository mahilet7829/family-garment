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
    try {
      _expenses = await _service.getAllExpenses();
      _monthPayments = await _service.getMonthlySummary(_selectedMonth);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _previousMonth() { setState(() { _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1); }); _load(); }
  void _nextMonth() { setState(() { _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1); }); _load(); }

  String _monthName(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.year}';
  }

  // ========== NAVIGATE TO DETAIL ==========
  Future<void> _openDetail(ExpenseModel expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expense: expense)),
    );
    if (result == true) _load();
  }

  // ========== ADD EXPENSE ==========
  Future<void> _addExpense() async {
    final nc = TextEditingController();
    final cc = TextEditingController();
    String cat = 'Labor';
    String freq = 'monthly';

    final r = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_circle, color: AppColors.navy, size: 20)), const SizedBox(width: 10), const Text('Add Expense', style: TextStyle(color: AppColors.navy, fontSize: 18))]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _lbl('Type'), const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
          child: DropdownButtonFormField<String>(
            value: cat, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(h: 14, v: 4)),
            items: ['Labor','Other'].map((c) => DropdownMenuItem(value: c, child: Text(c == 'Labor' ? '🧑‍🔧 Labor (Workers)' : '🚚 Other (Transport, Rent)'))).toList(),
            onChanged: (v) { if (v != null) setSt(() => cat = v); },
          ),
        ),
        const SizedBox(height: 14),
        _lbl('Name'), const SizedBox(height: 6),
        TextField(controller: nc, decoration: _dec('e.g. Worker X Salary')),
        const SizedBox(height: 14),
        _lbl('Amount (Br)'), const SizedBox(height: 6),
        TextField(controller: cc, keyboardType: TextInputType.number, decoration: _dec('5000')),
        const SizedBox(height: 14),
        _lbl('Frequency'), const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)),
          child: DropdownButtonFormField<String>(
            value: freq, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(h: 14, v: 4)),
            items: ['daily','weekly','monthly','one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(),
            onChanged: (v) { if (v != null) setSt(() => freq = v); },
          ),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(h: 20, v: 12)), child: const Text('Save Expense')),
      ],
    )));

    if (r == true) {
      final name = nc.text.trim();
      final cost = double.tryParse(cc.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) {
        if (mounted) _snack('Name and amount are required', true);
        return;
      }
      await _service.createExpense(ExpenseModel(name: name, category: cat, monthlyCost: cost, expenseFrequency: freq));
      _load();
      if (mounted) _snack('$name added successfully', false);
    }
  }

  // ========== PAY EXPENSE (deducts from profit) ==========
  Future<void> _payExpense(ExpenseModel expense) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payment, color: AppColors.success, size: 20)), const SizedBox(width: 10), Text('Pay ${expense.name}', style: const TextStyle(color: AppColors.navy, fontSize: 16))]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(CurrencyFormatter.format(expense.monthlyCost), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.error)),
        ])),
        const SizedBox(height: 16),
        _lbl('Notes (optional)'), const SizedBox(height: 6),
        TextField(controller: notesController, decoration: _dec('e.g. Transport for driver Alemu'), maxLines: 2),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(h: 20, v: 12)), child: const Text('Confirm Payment')),
      ],
    ));

    if (confirm == true) {
      // This payment will be picked up by getProfitSummary and deducted from profit
      await _service.createPayment(ExpensePaymentModel(
        expenseId: expense.id!, name: expense.name, category: expense.category,
        amount: expense.monthlyCost, notes: notesController.text.trim(),
      ));
      _load();
      if (mounted) _snack('${expense.name}: ${CurrencyFormatter.format(expense.monthlyCost)} paid - deducted from profit', false);
    }
  }

  void _snack(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lc = _monthPayments['Labor'] ?? 0;
    final oc = _monthPayments['Other'] ?? 0;
    final total = lc + oc;
    final lab = _expenses.where((e) => e.category == 'Labor').toList();
    final oth = _expenses.where((e) => e.category == 'Other').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MONTHLY EXPENSES'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _addExpense, tooltip: 'Add Expense')],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy), onPressed: _previousMonth),
              Text(_monthName(_selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
              IconButton(icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy), onPressed: _nextMonth),
            ]),
          ),
          const SizedBox(height: 20),

          // Total expenses card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(children: [
              const Text('TOTAL EXPENSES THIS MONTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldLight, letterSpacing: 1)),
              const SizedBox(height: 12),
              Text(CurrencyFormatter.format(total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.white)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _chip('Labor', lc, AppColors.gold), const SizedBox(width: 16), _chip('Other', oc, AppColors.goldLight),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Labor section
          _sectionHeader('LABOR', Icons.people_alt_rounded, Colors.red),
          const SizedBox(height: 10),
          if (lab.isEmpty) _emptyCard('No labor expenses yet.\nTap + to add workers, salaries, etc.') else ...lab.map((e) => _expenseCard(e)),
          const SizedBox(height: 24),

          // Other costs section
          _sectionHeader('OTHER COSTS', Icons.local_shipping_rounded, Colors.purple),
          const SizedBox(height: 10),
          if (oth.isEmpty) _emptyCard('No other costs yet.\nTap + to add transport, rent, utilities, etc.') else ...oth.map((e) => _expenseCard(e)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _chip(String l, double a, Color c) => Container(padding: const EdgeInsets.symmetric(h: 12, v: 6), decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.4))), child: Text('$l: ${CurrencyFormatter.format(a)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)));

  Widget _sectionHeader(String t, IconData i, Color c) => Row(children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 20)),
    const SizedBox(width: 10),
    Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.5)),
    const Spacer(),
    Text('${_expenses.where((e) => e.category == (t.startsWith('L') ? 'Labor' : 'Other')).length} items', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);

  Widget _emptyCard(String m) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder, style: BorderStyle.solid)), child: Row(children: [Icon(Icons.info_outline, color: AppColors.textSecondary.withOpacity(0.5), size: 24), const SizedBox(width: 12), Expanded(child: Text(m, style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13, height: 1.4)))],),);

  Widget _expenseCard(ExpenseModel e) {
    final isLabor = e.category == 'Labor';
    final color = isLabor ? Colors.red : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder), boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetail(e),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isLabor ? Icons.people_alt_rounded : Icons.local_shipping_rounded, color: color, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(h: 8, v: 3), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(e.expenseFrequency, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
                  const SizedBox(width: 8),
                  Text(CurrencyFormatter.format(e.monthlyCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
                ]),
              ])),
              Icon(Icons.chevron_right, color: AppColors.textSecondary.withOpacity(0.4), size: 22),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _actionBtn(Icons.payment, 'Pay', AppColors.success, () => _payExpense(e)),
            ]),
          ])),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(padding: const EdgeInsets.symmetric(h: 14, v: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color), const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ])),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(h: 14, v: 14));
}

// ========== EXPENSE DETAIL SCREEN (with edit & delete) ==========
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

  Future<void> _load() async {
    setState(() => _loading = true);
    _payments = await _service.getPayments(_expense.id!);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editExpense() async {
    final nc = TextEditingController(text: _expense.name);
    final cc = TextEditingController(text: _expense.monthlyCost.toString());
    String cat = _expense.category;
    String freq = _expense.expenseFrequency;

    final r = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Expense', style: TextStyle(color: AppColors.navy, fontSize: 18)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _lbl('Type'), const SizedBox(height: 6),
        Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)), child: DropdownButtonFormField<String>(value: cat, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(h: 14, v: 4)), items: ['Labor','Other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setSt(() => cat = v); })),
        const SizedBox(height: 14),
        _lbl('Name'), const SizedBox(height: 6),
        TextField(controller: nc, decoration: _dec(null)),
        const SizedBox(height: 14),
        _lbl('Amount (Br)'), const SizedBox(height: 6),
        TextField(controller: cc, keyboardType: TextInputType.number, decoration: _dec(null)),
        const SizedBox(height: 14),
        _lbl('Frequency'), const SizedBox(height: 6),
        Container(decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cardBorder)), child: DropdownButtonFormField<String>(value: freq, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(h: 14, v: 4)), items: ['daily','weekly','monthly','one-time'].map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1)))).toList(), onChanged: (v) { if (v != null) setSt(() => freq = v); })),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save Changes')),
      ],
    )));

    if (r == true) {
      final name = nc.text.trim();
      final cost = double.tryParse(cc.text.trim()) ?? 0;
      if (name.isEmpty || cost <= 0) return;
      await _service.updateExpense(ExpenseModel(id: _expense.id, name: name, category: cat, monthlyCost: cost, expenseFrequency: freq));
      setState(() { _expense = ExpenseModel(id: _expense.id, name: name, category: cat, monthlyCost: cost, expenseFrequency: freq, createdAt: _expense.createdAt); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Expense updated'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<void> _deleteExpense() async {
    final c = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Delete Expense'),
      content: Text('Delete "${_expense.name}"?\n\nThis will also delete all payment history.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.white), child: const Text('Delete')),
      ],
    ));
    if (c == true) {
      await _service.deleteExpense(_expense.id!);
      if (mounted) { Navigator.pop(context, true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    final remaining = (_expense.monthlyCost - totalPaid).clamp(0, double.infinity);
    final isLabor = _expense.category == 'Labor';
    final color = isLabor ? Colors.red : Colors.purple;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_expense.name), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editExpense, tooltip: 'Edit'),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: _deleteExpense, tooltip: 'Delete'),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))]),
          child: Column(children: [
            Icon(isLabor ? Icons.people_alt_rounded : Icons.local_shipping_rounded, color: AppColors.white, size: 40),
            const SizedBox(height: 12),
            Text(CurrencyFormatter.format(_expense.monthlyCost), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.white)),
            const SizedBox(height: 4),
            Text('per ${_expense.expenseFrequency}', style: const TextStyle(fontSize: 14, color: AppColors.goldLight)),
          ]),
        ),
        const SizedBox(height: 20),

        // Details card
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          _dr('Name', _expense.name), _div(),
          _dr('Category', isLabor ? 'Labor (Workers)' : 'Other (Transport, Rent)'), _div(),
          _dr('Amount', CurrencyFormatter.format(_expense.monthlyCost)), _div(),
          _dr('Frequency', _expense.expenseFrequency[0].toUpperCase() + _expense.expenseFrequency.substring(1)), _div(),
          _dr('Total Paid', CurrencyFormatter.format(totalPaid)), _div(),
          _dr('Remaining', CurrencyFormatter.format(remaining)), _div(),
          _dr('Created', _expense.createdAt.toString().substring(0, 10)),
        ]))),
        const SizedBox(height: 20),

        // Payment history
        Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.history_rounded, color: AppColors.gold, size: 18)),
            const SizedBox(width: 10),
            const Text('PAYMENT HISTORY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy, letterSpacing: 0.5)),
            const Spacer(),
            Text('${_payments.length} payments', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          if (_payments.isEmpty) Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18), SizedBox(width: 8), Text('No payments recorded yet', style: TextStyle(color: AppColors.textSecondary))]))
          else ..._payments.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check_rounded, color: AppColors.success, size: 16)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(CurrencyFormatter.format(p.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (p.notes.isNotEmpty) Text(p.notes, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(p.paidAt.toString().substring(0, 16).replaceAll('T', ' '), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ])),
            ]),
          )),
        ]))),
        const SizedBox(height: 20),

        // Action buttons
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
  InputDecoration _dec(String? h) => InputDecoration(hintText: h, hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.cardBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 2)), contentPadding: const EdgeInsets.symmetric(h: 14, v: 14));
}