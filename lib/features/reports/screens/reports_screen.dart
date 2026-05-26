import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/services/production_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ProductionService _ps = ProductionService();
  Map<String, double> _monthSummary = {};
  Map<String, double> _costBreakdown = {};
  List<Map<String, dynamic>> _monthHistory = [];
  List<AuditEntry> _auditTrail = [];
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadReports(); }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final from = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final to = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0, 23, 59, 59);

      _monthSummary = await _ps.getProfitSummary(from: from, to: to);
      _costBreakdown = await _ps.getCostBreakdown(from: from, to: to);
      _auditTrail = await _ps.getDetailedAuditTrail(from: from, to: to);

      // Build history for last 12 months
      _monthHistory = [];
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
        final f = DateTime(d.year, d.month, 1);
        final t = DateTime(d.year, d.month + 1, 0, 23, 59, 59);
        final s = await _ps.getProfitSummary(from: f, to: t);
        _monthHistory.add({
          'month': d,
          'revenue': s['totalRevenue'] ?? 0,
          'cost': s['totalCost'] ?? 0,
          'profit': s['netProfit'] ?? 0,
          'batches': (s['totalBatches'] ?? 0).toInt(),
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _previousMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
    _loadReports();
  }

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
    _loadReports();
  }

  String _monthName(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('REPORTS'), backgroundColor: AppColors.navy, foregroundColor: AppColors.white, elevation: 0, actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadReports, tooltip: 'Refresh'),
      ]),
      body: _isLoading ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: AppColors.navy), SizedBox(height: 16), Text('Loading reports...', style: TextStyle(color: AppColors.textSecondary))]))
      : RefreshIndicator(onRefresh: _loadReports, color: AppColors.navy, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildMonthSelector(),
        const SizedBox(height: 20),
        _buildMonthSummary(),
        const SizedBox(height: 20),
        _buildCostBreakdownCard(),
        const SizedBox(height: 20),
        _buildAuditTrailSection(),
        const SizedBox(height: 20),
        _buildHistorySection(),
        const SizedBox(height: 20),
      ]))),
    );
  }

  Widget _buildMonthSelector() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy), onPressed: _previousMonth),
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(_monthName(_selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy))),
      IconButton(icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy), onPressed: _nextMonth),
    ]);
  }

  Widget _buildMonthSummary() {
    final profit = _monthSummary['netProfit'] ?? 0;
    final revenue = _monthSummary['totalRevenue'] ?? 0;
    final cost = _monthSummary['totalCost'] ?? 0;
    final expenseCost = _monthSummary['expenseCost'] ?? 0;
    final productionCost = _monthSummary['productionCost'] ?? 0;
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;

    return Card(elevation: 1, shadowColor: AppColors.navy.withOpacity(0.06), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.navy, size: 22)),
        const SizedBox(width: 12),
        Text(_monthName(_selectedMonth).toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 1)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: margin >= 0 ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('${margin.toStringAsFixed(1)}% margin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: margin >= 0 ? AppColors.success : AppColors.error))),
      ]),
      const SizedBox(height: 20),
      Text(CurrencyFormatter.format(profit), style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: profit >= 0 ? AppColors.navy : AppColors.error)),
      const Text('Net Profit', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _miniStat('Revenue', revenue, AppColors.success, Icons.arrow_upward_rounded)),
        Container(width: 1, height: 40, color: AppColors.cardBorder),
        Expanded(child: _miniStat('Total Cost', cost, AppColors.error, Icons.arrow_downward_rounded)),
      ]),
      if (expenseCost > 0 || productionCost > 0) ...[
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: Row(children: [
          Expanded(child: Column(children: [
            Text(CurrencyFormatter.format(productionCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
            const Text('Production', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ])),
          Container(width: 1, height: 30, color: AppColors.cardBorder),
          Expanded(child: Column(children: [
            Text(CurrencyFormatter.format(expenseCost), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
            const Text('Expenses', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ])),
        ])),
      ],
    ])));
  }

  Widget _miniStat(String label, double amount, Color color, IconData icon) => Column(children: [
    Icon(icon, color: color, size: 18), const SizedBox(height: 6),
    Text(CurrencyFormatter.format(amount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
  ]);

  Widget _buildCostBreakdownCard() {
    final fabricCost = _costBreakdown['Fabric'] ?? 0;
    final trimCost = _costBreakdown['Trim'] ?? 0;
    final threadCost = _costBreakdown['Thread'] ?? 0;
    final packagingCost = _costBreakdown['Packaging'] ?? 0;
    final laborCost = _costBreakdown['Labor'] ?? 0;
    final otherCost = _costBreakdown['Other'] ?? 0;
    final total = fabricCost + trimCost + threadCost + packagingCost + laborCost + otherCost;

    return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.pie_chart_rounded, color: AppColors.gold, size: 20)), const SizedBox(width: 10), const Text('COST BREAKDOWN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.5))]),
      const SizedBox(height: 16),
      if (total > 0) ...[
        SizedBox(height: 180, child: PieChart(PieChartData(centerSpaceRadius: 40, sectionsSpace: 2, sections: [
          if (fabricCost > 0) PieChartSectionData(value: fabricCost, title: '${((fabricCost/total)*100).toStringAsFixed(0)}%', color: AppColors.navy, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (trimCost > 0) PieChartSectionData(value: trimCost, title: '${((trimCost/total)*100).toStringAsFixed(0)}%', color: Colors.blue, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (threadCost > 0) PieChartSectionData(value: threadCost, title: '${((threadCost/total)*100).toStringAsFixed(0)}%', color: Colors.teal, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (packagingCost > 0) PieChartSectionData(value: packagingCost, title: '${((packagingCost/total)*100).toStringAsFixed(0)}%', color: Colors.orange, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (laborCost > 0) PieChartSectionData(value: laborCost, title: '${((laborCost/total)*100).toStringAsFixed(0)}%', color: Colors.red, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          if (otherCost > 0) PieChartSectionData(value: otherCost, title: '${((otherCost/total)*100).toStringAsFixed(0)}%', color: Colors.purple, radius: 45, titleStyle: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]))),
        const SizedBox(height: 12),
        _costRow('Fabric', fabricCost, AppColors.navy),
        _costRow('Trim', trimCost, Colors.blue),
        _costRow('Thread', threadCost, Colors.teal),
        _costRow('Packaging', packagingCost, Colors.orange),
        _costRow('Labor', laborCost, Colors.red),
        _costRow('Other', otherCost, Colors.purple),
        const Divider(height: 16),
        _costRow('TOTAL COST', total, AppColors.textPrimary, bold: true),
      ] else
        const Text('No cost data this month', style: TextStyle(color: AppColors.textSecondary)),
    ])));
  }

  Widget _costRow(String label, double amount, Color color, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(label, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: AppColors.textSecondary))]),
    Text(CurrencyFormatter.format(amount), style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
  ]));

  // ========== UNIFIED AUDIT TRAIL SECTION ==========
  Widget _buildAuditTrailSection() {
    return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_long, color: AppColors.navy, size: 20)),
        const SizedBox(width: 10),
        const Text('AUDIT TRAIL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.5)),
        const Spacer(),
        Text('${_auditTrail.length} entries', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
      const SizedBox(height: 12),
      if (_auditTrail.isEmpty)
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18), SizedBox(width: 8), Text('No transactions this month', style: TextStyle(color: AppColors.textSecondary))]))
      else
        ..._auditTrail.take(20).map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.cardBorder)),
            child: Row(children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: entry.type == 'Production' ? AppColors.success.withOpacity(0.1) : entry.type == 'Expense' ? AppColors.error.withOpacity(0.1) : AppColors.navy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  entry.type == 'Production' ? Icons.factory : entry.type == 'Expense' ? Icons.monetization_on : Icons.inventory_2,
                  size: 16,
                  color: entry.type == 'Production' ? AppColors.success : entry.type == 'Expense' ? AppColors.error : AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              // Description & details
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(entry.details, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_formatAuditDate(entry.date), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ])),
              const SizedBox(width: 8),
              // Amount
              Text(
                CurrencyFormatter.format(entry.amount),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: entry.amount >= 0 ? AppColors.success : AppColors.error),
              ),
            ]),
          ),
        )),
    ])));
  }

  String _formatAuditDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildHistorySection() {
    return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.history_rounded, color: AppColors.navy, size: 20)), const SizedBox(width: 10), const Text('MONTHLY HISTORY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy, letterSpacing: 0.5))]),
      const SizedBox(height: 16),
      ..._monthHistory.map((m) {
        final d = m['month'] as DateTime;
        final rev = (m['revenue'] as double?) ?? 0;
        final cost = (m['cost'] as double?) ?? 0;
        final profit = (m['profit'] as double?) ?? 0;
        final batches = (m['batches'] as int?) ?? 0;
        final isPositive = profit >= 0;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.cardBorder)), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_monthName(d), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text('$batches batches  •  Rev: ${CurrencyFormatter.format(rev)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(CurrencyFormatter.format(profit), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isPositive ? AppColors.success : AppColors.error)),
            Text('Cost: ${CurrencyFormatter.format(cost)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ])));
      }),
      if (_monthHistory.isEmpty) const Text('No history yet', style: TextStyle(color: AppColors.textSecondary)),
    ])));
  }
}