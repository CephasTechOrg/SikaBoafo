import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../inventory/providers/inventory_providers.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';

class DashboardRecentActivity extends ConsumerWidget {
  const DashboardRecentActivity({super.key, required this.activityAsync});
  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build imageUrl lookup from local inventory by itemId
    final inventory = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
    final imageByItemId = <String, String>{
      for (final item in inventory)
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          item.id: item.imageUrl!,
    };

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
                  _SkeletonActivityRow(),
                  Divider(height: 1, indent: 68),
                  _SkeletonActivityRow(),
                  Divider(height: 1, indent: 68),
                  _SkeletonActivityRow(),
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
              data: (activity) {
                if (activity.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded,
                              color: AppColors.border, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'No recent activity',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < activity.length; i++) ...[
                      _ActivityRow(
                        activity: activity[i],
                        imageUrl: activity[i].itemId != null
                            ? imageByItemId[activity[i].itemId!]
                            : null,
                      ),
                      if (i < activity.length - 1)
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

// ─── Activity type visual ─────────────────────────────────────────────────────

class _ActivityVisual {
  const _ActivityVisual({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.badgeLabel,
    required this.badgeColor,
    required this.isIncome,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String badgeLabel;
  final Color badgeColor;
  final bool isIncome;

  static _ActivityVisual forType(String type) {
    switch (type) {
      case 'expense':
        return const _ActivityVisual(
          icon: Icons.outbox_rounded,
          iconColor: Color(0xFFB54848),
          bgColor: Color(0xFFFFF0F0),
          badgeLabel: 'Expense',
          badgeColor: Color(0xFFB54848),
          isIncome: false,
        );
      case 'repayment':
        return _ActivityVisual(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: AppColors.info,
          bgColor: AppColors.infoSoft,
          badgeLabel: 'Repayment',
          badgeColor: AppColors.info,
          isIncome: true,
        );
      case 'stock_addition':
        return _ActivityVisual(
          icon: Icons.add_box_outlined,
          iconColor: const Color(0xFFC58C02),
          bgColor: AppColors.warningSoft,
          badgeLabel: 'Stock',
          badgeColor: const Color(0xFFC58C02),
          isIncome: false,
        );
      case 'sale':
      default:
        return _ActivityVisual(
          icon: Icons.receipt_long_outlined,
          iconColor: AppColors.forest,
          bgColor: AppColors.successSoft,
          badgeLabel: 'Sale',
          badgeColor: AppColors.forest,
          isIncome: true,
        );
    }
  }
}

// ─── Activity row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, this.imageUrl});
  final DashboardActivity activity;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final v = _ActivityVisual.forType(activity.activityType);
    final timeStr = DateFormat.jm().format(activity.createdAt);
    final amountStr = '${v.isIncome ? '+' : '-'}₵${activity.amount}';
    final detailText = activity.detail.trim().isNotEmpty
        ? activity.detail
        : (activity.itemName?.trim().isNotEmpty == true
            ? activity.itemName!
            : 'Activity');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          // Icon/image card
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: v.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Icon(v.icon,
                        size: 20, color: v.iconColor),
                    errorWidget: (_, __, ___) =>
                        Icon(v.icon, size: 20, color: v.iconColor),
                  )
                : Icon(v.icon, size: 20, color: v.iconColor),
          ),
          const SizedBox(width: 12),
          // Text section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
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
                Text(
                  '$timeStr · $detailText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount - clearly shows +/- and value
          SizedBox(
            width: 75,
            child: Text(
              amountStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: v.isIncome ? AppColors.forest : const Color(0xFFB54848),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonActivityRow extends StatelessWidget {
  const _SkeletonActivityRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          _SkeletonBox(width: 42, height: 42, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 110, height: 11),
                SizedBox(height: 6),
                _SkeletonBox(width: 75, height: 9),
              ],
            ),
          ),
          SizedBox(width: 10),
          _SkeletonBox(width: 55, height: 13),
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
