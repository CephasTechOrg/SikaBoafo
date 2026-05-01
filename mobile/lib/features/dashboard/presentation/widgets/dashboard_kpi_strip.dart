import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../sales/presentation/utils/sales_ui_utils.dart';
import '../../providers/dashboard_providers.dart';

class DashboardKpiStrip extends StatelessWidget {
  const DashboardKpiStrip({
    super.key,
    required this.summaryAsync,
    required this.overlayAsync,
    required this.onNavigate,
  });

  final AsyncValue<DashboardSummary> summaryAsync;
  final AsyncValue<DashboardOverlay> overlayAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final overlay = overlayAsync.valueOrNull;

    final margin = summary?.profitMargin ?? '--';
    final orders = (summary?.todaySalesCount ?? 0) + (overlay?.todayPendingSalesCount ?? 0);

    return PremiumReveal(
      delay: const Duration(milliseconds: 100),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.shopping_bag_outlined,
              label: 'Total Orders',
              value: orders == 0 ? '--' : orders.toString(),
              color: AppColors.info,
              backgroundColor: AppColors.infoSoft,
              onTap: () => onNavigate(1),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: StatCard(
              icon: Icons.pie_chart_outline_rounded,
              label: 'Avg Margin',
              value: margin == '--' ? '--' : '$margin%',
              color: AppColors.success,
              backgroundColor: AppColors.successSoft,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
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
