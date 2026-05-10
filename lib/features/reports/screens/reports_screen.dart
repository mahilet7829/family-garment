import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../services/production_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ProductionService _productionService = ProductionService();
  Map<String, double> _summary = {};
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
    _summary = await _productionService.getProfitSummary(
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Net Profit Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('NET PROFIT (7 DAYS)',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.format(
                                _summary['netProfit'] ?? 0),
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _summaryCard('Revenue',
                            _summary['totalRevenue'] ?? 0, AppColors.success),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _summaryCard('Total Cost',
                            _summary['totalCost'] ?? 0, AppColors.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pie Chart Placeholder
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('PROFIT BREAKDOWN',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: _summary['netProfit'] ?? 0,
                                    title: 'Profit',
                                    color: AppColors.success,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  PieChartSectionData(
                                    value: _summary['totalCost'] ?? 0,
                                    title: 'Cost',
                                    color: AppColors.error,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Batches count
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Production Batches'),
                          Text('${(_summary['totalBatches'] ?? 0).toInt()}',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.format(amount),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}