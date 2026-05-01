import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';

class DashboardTopSellingSection extends StatelessWidget {
  const DashboardTopSellingSection({
    super.key,
    required this.insightsAsync,
    required this.overlayAsync,
  });

  final AsyncValue<DashboardInsights> insightsAsync;
  final AsyncValue<DashboardOverlay> overlayAsync;

  @override
  Widget build(BuildContext context) {
    return PremiumReveal(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products',
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
            child: insightsAsync.when(
              loading: () => const Column(
                children: [
                  SkeletonTopSellingRow(),
                  Divider(height: 1, indent: 60),
                  SkeletonTopSellingRow(),
                ],
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Could not load insights',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ),
              data: (insights) {
                final top = insights.monthlyTopSellingItems;
                if (top.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.analytics_outlined, color: AppColors.border, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No sales data yet',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < top.length; i++) ...[
                      _TopProductRow(product: top[i]),
                      if (i < top.length - 1)
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

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product});
  final DashboardTopSellingItem product;

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
            child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.itemName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantitySold} sold',
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
            '₵${product.salesTotal}',
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

class SkeletonTopSellingRow extends StatelessWidget {
  const SkeletonTopSellingRow({super.key});

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
                SkeletonBox(width: 120, height: 11),
                SizedBox(height: 6),
                SkeletonBox(width: 60, height: 9),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 50, height: 14),
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
