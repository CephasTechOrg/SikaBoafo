import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../../../shared/widgets/mockup_ui.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../../shared/widgets/sync_status_pill.dart';
import '../../../sales/presentation/utils/sales_ui_utils.dart';
import '../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';
import '../utils/dashboard_ui_utils.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.mc,
    required this.summaryAsync,
    required this.onSettings,
    required this.onNavigate,
  });

  final MerchantContext mc;
  final AsyncValue<DashboardSummary> summaryAsync;
  final VoidCallback onSettings;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = summaryAsync.valueOrNull;
    final sales = summary?.todaySalesTotal ?? '--';
    final overlayAsync = ref.watch(localDashboardOverlayProvider);
    final overlay = overlayAsync.valueOrNull;
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final syncSnapshot = syncAsync.valueOrNull;
    final syncing = syncSnapshot?.isSyncing ?? syncAsync.isLoading;
    final overlayMinor = overlay?.todayPendingSalesMinor ?? 0;
    final overlayText = overlayMinor > 0 ? SalesUiUtils.minorToMoney(overlayMinor) : null;
    final displaySales =
        overlayText == null ? sales : DashboardUiUtils.addMoneyStrings(sales, overlayText);
    final trend = summary != null
        ? DashboardUiUtils.trendBadge(displaySales, summary.yesterdaySalesTotal)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    DashboardUiUtils.initials(mc.businessName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DashboardUiUtils.greeting(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                          Text(
                            mc.businessName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (syncSnapshot != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => showSyncDetailsSheet(context, ref),
                          child: SyncPill(snapshot: syncSnapshot),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DashboardHeaderBtn(
                icon: syncing ? Icons.sync_rounded : Icons.cloud_sync_outlined,
                onTap: () async {
                  final controller =
                      ref.read(syncStatusControllerProvider.notifier);
                  await controller.syncNow();
                  if (!context.mounted) return;
                  final latest =
                      ref.read(syncStatusControllerProvider).valueOrNull;
                  final reachable = latest?.backendReachable ?? false;
                  final failed = latest?.stats.failedCount ?? 0;
                  final pending = latest == null
                      ? 0
                      : latest.stats.pendingCount + latest.stats.sendingCount;

                  final message = !reachable
                      ? 'Offline — will sync when back online.'
                      : failed > 0
                          ? 'Sync completed with $failed failed items.'
                          : pending > 0
                              ? 'Sync in progress — $pending pending.'
                              : 'All synced.';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              DashboardHeaderBtn(
                icon: Icons.notifications_outlined,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PremiumReveal(
            child: Column(
              children: [
                Text(
                  'SALES TODAY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '₵$displaySales',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Constantia',
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                if (overlayText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Includes ₵$overlayText offline',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
                if (trend != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend.startsWith('-')
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trend,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHeaderBtn extends StatelessWidget {
  const DashboardHeaderBtn({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.18),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class SyncPill extends StatelessWidget {
  const SyncPill({super.key, required this.snapshot});
  final SyncStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final descriptor = _resolve(snapshot);
    if (descriptor == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: descriptor.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: descriptor.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (descriptor.spinner)
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            Icon(descriptor.icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              descriptor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static SyncPillDescriptor? _resolve(SyncStatusSnapshot s) {
    if (s.isSyncing) {
      return SyncPillDescriptor(
        label: 'Syncing…',
        icon: Icons.sync_rounded,
        spinner: true,
        background: Colors.white.withValues(alpha: 0.18),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (!s.backendReachable) {
      return SyncPillDescriptor(
        label: 'Offline',
        icon: Icons.cloud_off_rounded,
        spinner: false,
        background: const Color(0xFFB54848).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (s.hasFailures || s.hasConflicts) {
      final count = s.stats.failedCount + s.stats.conflictCount;
      return SyncPillDescriptor(
        label: 'Failed: $count',
        icon: Icons.error_outline_rounded,
        spinner: false,
        background: const Color(0xFFB54848).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (s.hasPendingWork) {
      final count = s.stats.pendingCount + s.stats.sendingCount;
      return SyncPillDescriptor(
        label: 'Pending: $count',
        icon: Icons.cloud_upload_outlined,
        spinner: false,
        background: const Color(0xFFC68A2E).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    return null;
  }
}

class SyncPillDescriptor {
  const SyncPillDescriptor({
    required this.label,
    required this.icon,
    required this.spinner,
    required this.background,
    required this.border,
  });
  final String label;
  final IconData icon;
  final bool spinner;
  final Color background;
  final Color border;
}
