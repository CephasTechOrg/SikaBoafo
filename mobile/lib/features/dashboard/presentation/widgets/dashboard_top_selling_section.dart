import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../inventory/providers/inventory_providers.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';
import 'dashboard_mockup_ui.dart';

class DashboardTopSellingSection extends ConsumerWidget {
  const DashboardTopSellingSection({
    super.key,
    required this.insightsAsync,
    required this.overlayAsync,
    required this.onNavigate,
  });

  final AsyncValue<DashboardInsights> insightsAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory  = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
    final imageByName = <String, String>{
      for (final item in inventory)
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          item.name.trim().toLowerCase(): item.imageUrl!,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashSectionHead(
          title: 'Top Selling Products',
          actionLabel: 'See all',
          onAction: () => onNavigate(2),
        ),
        const SizedBox(height: 10),
        DashboardCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: insightsAsync.when(
            loading: () => const _SkeletonRows(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load insights',
                  style: DSText.cardLabel(),
                ),
              ),
            ),
            data: (insights) {
              final top = insights.monthlyTopSellingItems;
              if (top.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          color: DashboardMockup.lineSoft,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text('No sales data yet', style: DSText.cardLabel()),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < top.length; i++) ...[
                    _ProductRow(
                      product: top[i],
                      rank: i + 1,
                      imageUrl:
                          imageByName[top[i].itemName.trim().toLowerCase()],
                    ),
                    if (i < top.length - 1) const DashRowDivider(),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Product row ──────────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.rank,
    this.imageUrl,
  });

  final DashboardTopSellingItem product;
  final int rank;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final rankBg =
        rank == 1 ? DashboardMockup.green700 : DashboardMockup.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Row(
        children: [
          // ── Thumbnail + rank badge ─────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: DashboardMockup.lineSoft),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 22,
                          color: DashboardMockup.ink3,
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 22,
                          color: DashboardMockup.ink3,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        size: 22,
                        color: DashboardMockup.ink3,
                      ),
              ),
              Positioned(
                top: -6,
                left: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    '$rank',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),

          // ── Name + units ───────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.rowTitle(),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantitySold} units sold',
                  style: DSText.rowSub(),
                ),
              ],
            ),
          ),

          // ── Revenue ────────────────────────────────────────────────────
          Text(
            '₵${product.salesTotal}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DashboardMockup.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonRow(),
        DashRowDivider(),
        _SkeletonRow(),
        DashRowDivider(),
        _SkeletonRow(),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(13),
      child: Row(
        children: [
          DashSkeletonBox(width: 48, height: 48, radius: 13),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashSkeletonBox(width: 120, height: 12),
                SizedBox(height: 6),
                DashSkeletonBox(width: 80, height: 10),
              ],
            ),
          ),
          DashSkeletonBox(width: 52, height: 12),
        ],
      ),
    );
  }
}
