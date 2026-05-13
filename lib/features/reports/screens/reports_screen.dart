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
  final ProductionService _productionService = ProductionService();
  Map<String, double> _allTimeSummary = {};
  Map<String, double> _weeklySummary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      _allTimeSummary = await _productionService.getProfitSummary(
        from: DateTime(2020),
        to: now,
      );

      _weeklySummary = await _productionService.getProfitSummary(
        from: weekAgo,
        to: now,
      );
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('REPORTS'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.navy),
                  SizedBox(height: 16),
                  Text('Loading reports...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              color: AppColors.navy,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAllTimeSection(),
                    const SizedBox(height: 24),
                    _buildPieChartSection(),
                    const SizedBox(height: 24),
                    _buildWeeklySection(),
                    const SizedBox(height: 20),
                    _buildBatchesSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAllTimeSection() {
    final profit = _allTimeSummary['netProfit'] ?? 0;
    final revenue = _allTimeSummary['totalRevenue'] ?? 0;
    final cost = _allTimeSummary['totalCost'] ?? 0;
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;

    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.navy, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('ALL TIME',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: margin >= 0
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${margin.toStringAsFixed(1)}% margin',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: margin >= 0
                              ? AppColors.success
                              : AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              CurrencyFormatter.format(profit),
              style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: profit >= 0 ? AppColors.navy : AppColors.error),
            ),
            const SizedBox(height: 4),
            const Text('Net Profit',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                      'Revenue', revenue, AppColors.success, Icons.arrow_upward_rounded),
                ),
                Container(width: 1, height: 40, color: AppColors.cardBorder),
                Expanded(
                  child: _miniStat(
                      'Cost', cost, AppColors.error, Icons.arrow_downward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
      String label, double amount, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(CurrencyFormatter.format(amount),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPieChartSection() {
    final profit = _allTimeSummary['netProfit'] ?? 0;
    final cost = _allTimeSummary['totalCost'] ?? 0;
    final total = profit + cost;

    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pie_chart_rounded,
                      color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('PROFIT BREAKDOWN',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        letterSpacing: 0.5)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: total > 0
                  ? PieChart(
                      PieChartData(
                        centerSpaceRadius: 50,
                        sectionsSpace: 3,
                        sections: [
                          PieChartSectionData(
                            value: profit > 0 ? profit : 0,
                            title: profit > 0
                                ? '${((profit / total) * 100).toStringAsFixed(0)}%'
                                : '',
                            color: AppColors.success,
                            radius: 55,
                            titleStyle: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                          PieChartSectionData(
                            value: cost > 0 ? cost : 1,
                            title: cost > 0
                                ? '${((cost / total) * 100).toStringAsFixed(0)}%'
                                : '',
                            color: AppColors.error.withOpacity(0.7),
                            radius: 55,
                            titleStyle: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Text('No data yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(AppColors.success, 'Profit'),
                const SizedBox(width: 24),
                _legendDot(AppColors.error.withOpacity(0.7), 'Cost'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildWeeklySection() {
    final profit = _weeklySummary['netProfit'] ?? 0;
    final revenue = _weeklySummary['totalRevenue'] ?? 0;
    final cost = _weeklySummary['totalCost'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('THIS WEEK',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 1,
          shadowColor: AppColors.navy.withOpacity(0.04),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  CurrencyFormatter.format(profit),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: profit >= 0 ? AppColors.success : AppColors.error),
                ),
                const SizedBox(height: 2),
                const Text('Weekly Net Profit',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat('Revenue', revenue, AppColors.success,
                          Icons.trending_up_rounded),
                    ),
                    Container(
                        width: 1, height: 35, color: AppColors.cardBorder),
                    Expanded(
                      child: _miniStat('Cost', cost, AppColors.error,
                          Icons.trending_down_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchesSection() {
    final allBatches =
        (_allTimeSummary['totalBatches'] ?? 0).toInt();
    final weeklyBatches =
        (_weeklySummary['totalBatches'] ?? 0).toInt();

    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 1,
            shadowColor: AppColors.navy.withOpacity(0.04),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.factory_rounded,
                        color: AppColors.navy, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('$allBatches',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  const SizedBox(height: 2),
                  const Text('Total Batches',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 1,
            shadowColor: AppColors.navy.withOpacity(0.04),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.checklist_rounded,
                        color: AppColors.success, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('$weeklyBatches',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success)),
                  const SizedBox(height: 2),
                  const Text('This Week',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}