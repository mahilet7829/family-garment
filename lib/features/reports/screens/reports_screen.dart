import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../services/production_service.dart';

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

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // All-time summary
    _allTimeSummary = await _productionService.getProfitSummary(
      from: DateTime(2020),
      to: now,
    );

    // Weekly summary
    _weeklySummary = await _productionService.getProfitSummary(
      from: weekAgo,
      to: now,
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('REPORTS'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // All-Time Net Profit
                  _bigNumberCard(
                    'TOTAL NET PROFIT (All Time)',
                    _allTimeSummary['netProfit'] ?? 0,
                    AppColors.navy,
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(height: 16),

                  // Revenue & Cost Row
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'TOTAL REVENUE',
                          _allTimeSummary['totalRevenue'] ?? 0,
                          AppColors.success,
                          Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          'TOTAL COST',
                          _allTimeSummary['totalCost'] ?? 0,
                          AppColors.error,
                          Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // This Week Header
                  const Text('THIS WEEK',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),

                  // Weekly Net Profit
                  _bigNumberCard(
                    'Weekly Net Profit',
                    _weeklySummary['netProfit'] ?? 0,
                    AppColors.success,
                    Icons.calendar_today,
                  ),
                  const SizedBox(height: 16),

                  // Weekly Revenue & Cost
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard(
                          'Weekly Revenue',
                          _weeklySummary['totalRevenue'] ?? 0,
                          AppColors.success,
                          Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard(
                          'Weekly Cost',
                          _weeklySummary['totalCost'] ?? 0,
                          AppColors.error,
                          Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Production Batches
                  _infoCard(
                    'Total Production Batches',
                    '${(_allTimeSummary['totalBatches'] ?? 0).toInt()}',
                    Icons.factory,
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    'Batches This Week',
                    '${(_weeklySummary['totalBatches'] ?? 0).toInt()}',
                    Icons.checklist,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bigNumberCard(
      String label, double amount, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
      String label, double amount, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.format(amount),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 24),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}