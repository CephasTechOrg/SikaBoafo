import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/dashboard_api.dart';
import 'dashboard_mockup_ui.dart';

class DashboardRecentActivity extends ConsumerWidget {
  const DashboardRecentActivity({super.key, required this.activityAsync});

  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashSectionHead(title: 'Recent Activity', actionLabel: 'View all'),
        const SizedBox(height: 10),
        DashboardCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: activityAsync.when(
            loading: () => const _SkeletonRows(),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Could not load activity', style: DSText.cardLabel()),
              ),
            ),
            data: (activity) {
              if (activity.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          color: DashboardMockup.lineSoft,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text('No recent activity', style: DSText.cardLabel()),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < activity.length; i++) ...[
                    _ActivityRow(activity: activity[i]),
                    if (i < activity.length - 1) const DashRowDivider(),
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

// ── Visual config per activity type ─────────────────────────────────────────

class _Visual {
  const _Visual({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.isIncome,
    required this.payLabel,
  });

  final IconData icon;
  final Color iconColor;
  final Color bg;
  final bool isIncome;
  final String payLabel;

  static _Visual from(DashboardActivity a) {
    final t = a.activityType;
    final title = a.title.toLowerCase();
    if (t == 'expense') {
      return const _Visual(
        icon: Icons.receipt_long_outlined,
        iconColor: DashboardMockup.ink2,
        bg: Color(0xFFF1F3F5),
        isIncome: false,
        payLabel: 'Expense',
      );
    }
    if (t == 'repayment' || title.startsWith('repayment')) {
      return const _Visual(
        icon: Icons.handshake_outlined,
        iconColor: DashboardMockup.green700,
        bg: DashboardMockup.greenTint,
        isIncome: true,
        payLabel: 'Repayment',
      );
    }
    if (t == 'stock_addition' || title.startsWith('restock')) {
      return const _Visual(
        icon: Icons.inventory_2_outlined,
        iconColor: DashboardMockup.ink2,
        bg: Color(0xFFF1F3F5),
        isIncome: false,
        payLabel: 'Stock',
      );
    }
    return const _Visual(
      icon: Icons.point_of_sale_outlined,
      iconColor: DashboardMockup.green700,
      bg: DashboardMockup.greenTint,
      isIncome: true,
      payLabel: 'Sale',
    );
  }
}

// ── Activity row ─────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final DashboardActivity activity;

  String _time(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1)   return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)  return '${diff.inHours}h ago';
    if (diff.inDays < 7)    return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final v = _Visual.from(activity);
    final sub = activity.detail.trim().isNotEmpty
        ? activity.detail.trim()
        : (activity.itemName?.trim().isNotEmpty == true
            ? activity.itemName!.trim()
            : v.payLabel);

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Row(
        children: [
          // ── Icon badge ─────────────────────────────────────────────────
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: v.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, size: 19, color: v.iconColor),
          ),
          const SizedBox(width: 13),

          // ── Title + sub ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.activityTitle(),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sub · ${_time(activity.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.activitySub(),
                ),
              ],
            ),
          ),

          // ── Amount + pay label ─────────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${v.isIncome ? '+' : ''}₵${activity.amount}',
                style: DSText.activityAmount(income: v.isIncome),
              ),
              const SizedBox(height: 1),
              Text(v.payLabel, style: DSText.activityPayLabel()),
            ],
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
          DashSkeletonBox(width: 42, height: 42, radius: 12),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashSkeletonBox(width: 110, height: 11),
                SizedBox(height: 6),
                DashSkeletonBox(width: 90, height: 10),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DashSkeletonBox(width: 55, height: 11),
              SizedBox(height: 4),
              DashSkeletonBox(width: 36, height: 9),
            ],
          ),
        ],
      ),
    );
  }
}
