import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
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
        const DashboardSectionHead(
          title: 'Recent Activity',
          actionLabel: 'View all',
        ),
        const SizedBox(height: 12),
        DashboardMockupCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: activityAsync.when(
            loading: () => const Column(
              children: [
                _SkeletonActivityRow(),
                _MockupRowDivider(),
                _SkeletonActivityRow(),
                _MockupRowDivider(),
                _SkeletonActivityRow(),
              ],
            ),
            error: (e, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Could not load activity',
                  style: TextStyle(color: DashboardMockup.ink3, fontSize: 13),
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
                            color: DashboardMockup.ink3,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < activity.length; i++) ...[
                    _ActivityRow(activity: activity[i]),
                    if (i < activity.length - 1) const _MockupRowDivider(),
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

class _ActivityVisual {
  const _ActivityVisual({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.isIncome,
    required this.payLabel,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool isIncome;
  final String payLabel;

  static _ActivityVisual forActivity(DashboardActivity a) {
    final title = a.title.toLowerCase();
    if (a.activityType == 'expense') {
      return const _ActivityVisual(
        icon: Icons.receipt_long_outlined,
        iconColor: DashboardMockup.ink2,
        bgColor: Color(0xFFF1F3F5),
        isIncome: false,
        payLabel: 'Expense',
      );
    }
    if (a.activityType == 'repayment' || title.startsWith('repayment')) {
      return const _ActivityVisual(
        icon: Icons.handshake_outlined,
        iconColor: DashboardMockup.green700,
        bgColor: DashboardMockup.greenTint,
        isIncome: true,
        payLabel: 'Repayment',
      );
    }
    if (a.activityType == 'stock_addition' || title.startsWith('restock')) {
      return const _ActivityVisual(
        icon: Icons.inventory_2_outlined,
        iconColor: DashboardMockup.ink2,
        bgColor: Color(0xFFF1F3F5),
        isIncome: false,
        payLabel: 'Stock',
      );
    }
    return const _ActivityVisual(
      icon: Icons.point_of_sale_outlined,
      iconColor: DashboardMockup.green700,
      bgColor: DashboardMockup.greenTint,
      isIncome: true,
      payLabel: 'Sale',
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final DashboardActivity activity;

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final v = _ActivityVisual.forActivity(activity);
    final sub = activity.detail.trim().isNotEmpty
        ? activity.detail.trim()
        : (activity.itemName?.trim().isNotEmpty == true
            ? activity.itemName!.trim()
            : v.payLabel);
    final timeStr = _relativeTime(activity.createdAt);
    final amountPrefix = v.isIncome ? '+' : '';
    final amountStr = '$amountPrefix₵${activity.amount}';

    return Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: v.bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, size: 19, color: v.iconColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: DashboardMockup.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sub · $timeStr',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: DashboardMockup.ink2,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color:
                      v.isIncome ? DashboardMockup.green700 : DashboardMockup.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                v.payLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: DashboardMockup.ink3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockupRowDivider extends StatelessWidget {
  const _MockupRowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: DashboardMockup.lineSoft,
    );
  }
}

class _SkeletonActivityRow extends StatelessWidget {
  const _SkeletonActivityRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(13),
      child: Row(
        children: [
          _SkeletonBox(width: 42, height: 42, borderRadius: 12),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 110, height: 11),
                SizedBox(height: 6),
                _SkeletonBox(width: 90, height: 10),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SkeletonBox(width: 55, height: 11),
              SizedBox(height: 4),
              _SkeletonBox(width: 36, height: 9),
            ],
          ),
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
