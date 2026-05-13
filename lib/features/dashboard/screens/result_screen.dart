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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
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

      if (mounted) {
        setState(() {
          _result = result;
          _materialNames = names;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.navy),
                  SizedBox(height: 16),
                  Text('Calculating...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.error_outline,
                              color: AppColors.error, size: 40),
                        ),
                        const SizedBox(height: 16),
                        Text('Something went wrong',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _runSimulation();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('TRY AGAIN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildResult(),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildYieldCard(result),
              const SizedBox(height: 16),
              _buildMaterialsCheckCard(result),
              const SizedBox(height: 16),
              _buildMoneyCard(result),
              const SizedBox(height: 24),
              _buildActionButtons(result),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYieldCard(SimulationResult result) {
    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          children: [
            // Input summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2,
                          color: AppColors.navy, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${widget.availableQuantity} ${widget.material.unit} ${widget.material.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (widget.material.isFabric && widget.material.gsm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('(${widget.material.gsm!.toInt()} GSM)',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.arrow_downward_rounded,
                color: AppColors.gold, size: 28),
            const SizedBox(height: 16),
            Text(
              '${widget.product.name} (${widget.sizeVariant.sizeName})',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Yield number
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy.withOpacity(0.04),
                    AppColors.navy.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.navy.withOpacity(0.08), width: 1.5),
              ),
              child: Column(
                children: [
                  const Text('YOU CAN MAKE',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    '${result.maxPieces}',
                    style: const TextStyle(
                        fontSize: 68,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.product.name}S',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                  ),
                ],
              ),
            ),

            // Limiting factor
            if (result.limitingFactor != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Limited by: ${result.limitingFactor}',
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsCheckCard(SimulationResult result) {
    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, color: AppColors.navy, size: 20),
                const SizedBox(width: 8),
                const Text('MATERIALS CHECK',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        color: AppColors.navy)),
              ],
            ),
            const SizedBox(height: 16),
            if (result.materialSufficiency.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.textSecondary, size: 18),
                    SizedBox(width: 8),
                    Text('No recipe items found for this product.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              )
            else
              ...result.materialSufficiency.entries.map((entry) {
                final materialId = entry.key;
                final needed = result.materialsNeeded[materialId] ?? 0;
                final isEnough = entry.value;
                final name =
                    _materialNames[materialId] ?? 'Material #$materialId';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnough
                        ? AppColors.success.withOpacity(0.04)
                        : AppColors.error.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnough
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isEnough
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEnough
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          color: isEnough
                              ? AppColors.success
                              : AppColors.error,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isEnough
                                    ? AppColors.textPrimary
                                    : AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${needed.toStringAsFixed(2)} needed',
                              style: TextStyle(
                                fontSize: 11,
                                color: isEnough
                                    ? AppColors.textSecondary
                                    : AppColors.error.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isEnough
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: isEnough
                            ? AppColors.success
                            : AppColors.error,
                        size: 22,
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
    final profitMargin = revenuePerPiece > 0
        ? (profitPerPiece / revenuePerPiece * 100)
        : 0.0;
    final totalPieces = result.maxPieces;

    return Card(
      elevation: 1,
      shadowColor: AppColors.navy.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: AppColors.navy, size: 20),
                const SizedBox(width: 8),
                const Text('MONEY BREAKDOWN',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        color: AppColors.navy)),
              ],
            ),
            const SizedBox(height: 16),

            // Per Piece Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy.withOpacity(0.03),
                    AppColors.navy.withOpacity(0.01),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('PER PIECE',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 1)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: profitMargin >= 30
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${profitMargin.toStringAsFixed(1)}% margin',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: profitMargin >= 30
                                    ? AppColors.success
                                    : AppColors.warning)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _perPieceRow(
                      'Selling Price', revenuePerPiece, AppColors.navy, false),
                  const SizedBox(height: 8),
                  _perPieceRow(
                      'Material Cost', costPerPiece, AppColors.error, false),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _perPieceRow('PROFIT', profitPerPiece, AppColors.success,
                      true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Total for Batch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('TOTAL BATCH ($totalPieces pieces)',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _totalRow('Total Revenue', result.totalRevenue,
                      AppColors.success),
                  const SizedBox(height: 6),
                  _totalRow(
                      'Total Cost', result.totalCost, AppColors.error),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _totalRow('NET PROFIT', result.netProfit, AppColors.navy,
                      isBold: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perPieceRow(
      String label, double amount, Color color, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isBold ? color : AppColors.textSecondary)),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color),
        ),
      ],
    );
  }

  Widget _totalRow(String label, double amount, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textSecondary)),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SimulationResult result) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('BACK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.navy,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.cardBorder)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: result.maxPieces > 0
                ? () {
                    Navigator.pop(context);
                  }
                : null,
            icon: const Icon(Icons.play_circle_rounded, size: 22),
            label: const Text('RECORD PRODUCTION',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.success.withOpacity(0.4),
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}