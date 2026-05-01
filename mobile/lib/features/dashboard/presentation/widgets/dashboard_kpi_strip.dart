import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';

class DashboardKpiStrip extends StatelessWidget {
  const DashboardKpiStrip({
    super.key,
    required this.summaryAsync,
    required this.overlayAsync,
    required this.onNavigate,
  });

  final AsyncValue<DashboardSummary> summaryAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final overlay = overlayAsync.valueOrNull;

    final lowStock = summary?.lowStockCount ?? 0;
    final debtOutstanding = summary?.debtOutstandingTotal ?? '0.00';
    final todaySales = summary?.todaySalesTotal ?? '0.00';
    final todayProfit = summary?.todayEstimatedProfit ?? '0.00';

    return PremiumReveal(
      delay: const Duration(milliseconds: 100),
      child: Column(
        children: [
          _CoinsCard(
            todaySales: todaySales,
            todayProfit: todayProfit,
            onNavigate: onNavigate,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Debt Outstanding',
                  value: '₵$debtOutstanding',
                  color: const Color(0xFFB54848),
                  backgroundColor: const Color(0xFFFFF0F0),
                  onTapWithCtx: (ctx) => ctx.push(AppRoute.debts.path),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Low Stock',
                  value: lowStock == 0 ? '0' : lowStock.toString(),
                  color: AppColors.warning,
                  backgroundColor: AppColors.warningSoft,
                  onTapSimple: () => onNavigate(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Coins / Profit card ──────────────────────────────────────────────────────

class _CoinsCard extends StatelessWidget {
  const _CoinsCard({
    required this.todaySales,
    required this.todayProfit,
    required this.onNavigate,
  });
  final String todaySales;
  final String todayProfit;
  final ValueChanged<int> onNavigate;

  double _parse(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final sales = _parse(todaySales);
    final profit = _parse(todayProfit);
    // Profit margin as 0-1 ratio for the bar chart
    final ratio = (sales > 0) ? (profit / sales).clamp(0.0, 1.0) : 0.0;
    final pct = '${(ratio * 100).toStringAsFixed(0)}% margin';

    return GestureDetector(
      onTap: () => onNavigate(1),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D4023), Color(0xFF1A6840)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3A0D4023),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle flag pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child:
                    Image.asset('assets/images/flag.png', fit: BoxFit.cover),
              ),
            ),
            // Coins image — anchored bottom-right, bleeds slightly off edge
            Positioned(
              right: -6,
              bottom: -14,
              width: 108,
              height: 108,
              child: Image.asset('assets/images/coins.png',
                  fit: BoxFit.contain),
            ),
            // Content — single column, full card minus the coins image area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 118, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "TODAY'S EST. PROFIT",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // FittedBox auto-scales the number down if it grows large
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₵$todayProfit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Constantia',
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Animated profit margin bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LayoutBuilder(
                      builder: (ctx, bc) => Stack(
                        children: [
                          Container(
                            height: 6,
                            width: bc.maxWidth,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOut,
                            height: 6,
                            width: bc.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7FE0A0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pct,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat cards ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.onTapSimple,
    this.onTapWithCtx,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTapSimple;
  final ValueChanged<BuildContext>? onTapWithCtx;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onTapWithCtx != null) onTapWithCtx!(context);
            if (onTapSimple != null) onTapSimple!();
          },
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
