import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../providers/dashboard_providers.dart';

class DashboardRecentActivity extends StatelessWidget {
  const DashboardRecentActivity({super.key, required this.activityAsync});
  final AsyncValue<DashboardRecentActivityData> activityAsync;

  @override
  Widget build(BuildContext context) {
    return PremiumReveal(
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          PremiumPanel(
            padding: EdgeInsets.zero,
            child: activityAsync.when(
              loading: () => const Column(
                children: [
                  SkeletonActivityRow(),
                  Divider(height: 1, indent: 64),
                  SkeletonActivityRow(),
                ],
              ),
              error: (e, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Could not load activity',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ),
              data: (data) {
                final sales = data.recentSales;
                if (sales.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, color: AppColors.border, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No recent activity',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < sales.length; i++) ...[
                      _ActivityRow(sale: sales[i]),
                      if (i < sales.length - 1)
                        const Divider(height: 1, indent: 64, color: AppColors.border),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.sale});
  final DashboardRecentSale sale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.customerName ?? 'Guest Customer',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sale.timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₵${sale.totalAmount}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonActivityRow extends StatelessWidget {
  const SkeletonActivityRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(width: 36, height: 36, borderRadius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 100, height: 11),
                SizedBox(height: 6),
                SkeletonBox(width: 70, height: 9),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 60, height: 14),
        ],
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9EE),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
