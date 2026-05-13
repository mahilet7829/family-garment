import 'package:flutter/material.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/core/utils/currency_formatter.dart';
import 'package:family_garment/models/material_model.dart';
import 'package:family_garment/models/product_model.dart';
import 'package:family_garment/models/size_variant_model.dart';
import 'package:family_garment/services/simulation_service.dart';

class ResultScreen extends StatefulWidget {
  final MaterialModel material;
  final double availableQuantity;
  final ProductModel product;
  final SizeVariantModel sizeVariant;
  final SimulationService simulationService;

  const ResultScreen({
    super.key,
    required this.material,
    required this.availableQuantity,
    required this.product,
    required this.sizeVariant,
    required this.simulationService,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  SimulationResult? _result;
  bool _isLoading = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  Map<int, String> _materialNames = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    try {
      final result = await widget.simulationService.simulate(
        materialId: widget.material.id!,
        availableQuantity: widget.availableQuantity,
        productId: widget.product.id!,
        sizeVariantId: widget.sizeVariant.id!,
      );

      final names = <int, String>{};
      for (var id in result.materialsNeeded.keys) {
        names[id] = 'Material #$id';
      }

      setState(() {
        _result = result;
        _materialNames = names;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Simulation Result'),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Error: $_error',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMainResultCard(result),
              const SizedBox(height: 20),
              _buildMaterialsCheckCard(result),
              const SizedBox(height: 20),
              _buildMoneyCard(result),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle, size: 24),
                  label: const Text('GO TO RECORD PRODUCTION',
                      style: TextStyle(fontSize: 16, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainResultCard(SimulationResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Text(
              '${widget.availableQuantity} ${widget.material.unit} ${widget.material.name}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (widget.material.isFabric && widget.material.gsm != null)
              Text(
                '(${widget.material.gsm!.toInt()} GSM)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward, color: AppColors.gold, size: 30),
            const SizedBox(height: 8),
            Text(
              '${widget.product.name} (${widget.sizeVariant.sizeName})',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('YOU CAN MAKE',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  Text(
                    '${result.maxPieces}',
                    style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  ),
                  Text(
                    '${widget.product.name}S',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                  ),
                  if (result.limitingFactor != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Limited by: ${result.limitingFactor}',
                        style: const TextStyle(
                            color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsCheckCard(SimulationResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MATERIALS CHECK',
                style: TextStyle(
                    fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (result.materialSufficiency.isEmpty)
              const Text('No recipe items found for this product.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...result.materialSufficiency.entries.map((entry) {
                final materialId = entry.key;
                final needed = result.materialsNeeded[materialId] ?? 0;
                final isEnough = entry.value;
                final name =
                    _materialNames[materialId] ?? 'Material #$materialId';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isEnough ? Icons.check_circle : Icons.cancel,
                        color:
                            isEnough ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isEnough
                                    ? AppColors.textPrimary
                                    : AppColors.error,
                              ),
                            ),
                            Text(
                              '${needed.toStringAsFixed(2)} needed',
                              style: TextStyle(
                                fontSize: 12,
                                color: isEnough
                                    ? AppColors.textSecondary
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMoneyCard(SimulationResult result) {
    final revenuePerPiece = widget.product.sellingPrice;
    final costPerPiece = result.maxPieces > 0
        ? result.totalCost / result.maxPieces
        : 0.0;
    final profitPerPiece = revenuePerPiece - costPerPiece;
    final totalPieces = result.maxPieces;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MONEY BREAKDOWN',
                style: TextStyle(
                    fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 16),

            // Per Piece Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Text('PER PIECE',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selling Price'),
                      Text(CurrencyFormatter.format(revenuePerPiece),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Material Cost'),
                      Text(CurrencyFormatter.format(costPerPiece),
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PROFIT PER PIECE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(CurrencyFormatter.format(profitPerPiece),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                              fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Total for Batch
            Text('TOTAL ($totalPieces pieces)',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            _moneyRow('Total Revenue', result.totalRevenue, AppColors.success),
            _moneyRow('Total Cost', result.totalCost, AppColors.error),
            const Divider(height: 24),
            _moneyRow(
                'NET PROFIT', result.netProfit, AppColors.navy, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(String label, double amount, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 18 : 14)),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
                color: color,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 18 : 14),
          ),
        ],
      ),
    );
  }
}