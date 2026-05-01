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
  final AsyncValue<LocalDashboardOverlay> overlayAsync;

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
                  _SkeletonTopRow(),
                  Divider(height: 1, indent: 68, color: AppColors.border),
                  _SkeletonTopRow(),
                  Divider(height: 1, indent: 68, color: AppColors.border),
                  _SkeletonTopRow(),
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
                          Icon(Icons.analytics_outlined,
                              color: AppColors.border, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No sales data yet',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < top.length; i++) ...[
                      _TopProductRow(product: top[i], rank: i + 1),
                      if (i < top.length - 1)
                        const Divider(
                            height: 1, indent: 68, color: AppColors.border),
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

// ─── Product row ──────────────────────────────────────────────────────────────

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({required this.product, required this.rank});
  final DashboardTopSellingItem product;
  final int rank;

  @override
  Widget build(BuildContext context) {
    // Rank-based accent colors
    final rankColor = rank == 1
        ? const Color(0xFFC58C02)
        : rank == 2
            ? AppColors.muted
            : AppColors.forest;
    final rankBg = rank == 1
        ? AppColors.warningSoft
        : rank == 2
            ? const Color(0xFFF0F0F0)
            : AppColors.successSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Product image placeholder with rank badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              // Rank badge
              Positioned(
                top: -5,
                left: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${product.quantitySold} sold',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₵${product.salesTotal}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonTopRow extends StatelessWidget {
  const _SkeletonTopRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _SkeletonBox(width: 42, height: 42, borderRadius: 11),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 120, height: 11),
                SizedBox(height: 6),
                _SkeletonBox(width: 60, height: 9),
              ],
            ),
          ),
          SizedBox(width: 10),
          _SkeletonBox(width: 52, height: 13),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
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
