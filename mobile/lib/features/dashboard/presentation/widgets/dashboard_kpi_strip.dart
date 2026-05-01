import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final pendingSync = (overlay?.todayPendingSalesCount ?? 0);
    final todaySales = summary?.todaySalesTotal ?? '--';
    final todayProfit = summary?.todayEstimatedProfit ?? '--';

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
                  icon: Icons.sync_problem_rounded,
                  label: 'Pending Sync',
                  value: pendingSync == 0 ? '0' : pendingSync.toString(),
                  color: AppColors.info,
                  backgroundColor: AppColors.infoSoft,
                  onTap: () {},
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
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Coins card ───────────────────────────────────────────────────────────────

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
    final ratio = (sales > 0) ? (profit / sales).clamp(0.0, 1.0) : 0.0;
    final pct = '${(ratio * 100).toStringAsFixed(0)}% of revenue';

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
                child: Image.asset('assets/images/flag.png', fit: BoxFit.cover),
              ),
            ),
            // Coins image — bleeds off bottom-right
            Positioned(
              right: -6,
              bottom: -14,
              width: 108,
              height: 108,
              child: Image.asset('assets/images/coins.png', fit: BoxFit.contain),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 110, 0),
              child: Row(
                children: [
                  // ── Left column: Revenue ──────────────────────
                  Expanded(
                    flex: 55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "TODAY'S REVENUE",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '₵$todaySales',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Constantia',
                            letterSpacing: -0.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bar_chart_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.80)),
                              const SizedBox(width: 4),
                              Text(
                                'View Sales',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 62,
                    color: Colors.white.withValues(alpha: 0.14),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  // ── Right column: Profit + mini bar chart ──────
                  Expanded(
                    flex: 45,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'EST. PROFIT',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '₵$todayProfit',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Constantia',
                            letterSpacing: -0.3,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Mini animated progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LayoutBuilder(
                            builder: (ctx, bc) => Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: bc.maxWidth,
                                  color:
                                      Colors.white.withValues(alpha: 0.18),
                                ),
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 700),
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
                        const SizedBox(height: 4),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
