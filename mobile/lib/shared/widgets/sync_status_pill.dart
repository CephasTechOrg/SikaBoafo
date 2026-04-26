import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../data/local/sync_queue_repository.dart';
import '../providers/sync_providers.dart';

class SyncStatusPill extends ConsumerWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final snapshot = syncAsync.valueOrNull;
    final visual = _statusVisual(snapshot);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showSyncDetails(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: visual.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visual.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            syncAsync.isLoading && snapshot == null
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(visual.icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              visual.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  _SyncVisual _statusVisual(SyncStatusSnapshot? snapshot) {
    if (snapshot == null) {
      return const _SyncVisual(
        label: 'Checking',
        icon: Icons.sync_rounded,
        background: Color(0x296AA8E8),
        border: Color(0x556AA8E8),
      );
    }

    if (snapshot.isSyncing) {
      return const _SyncVisual(
        label: 'Syncing',
        icon: Icons.sync_rounded,
        background: Color(0x296AA8E8),
        border: Color(0x556AA8E8),
      );
    }
    if (snapshot.stats.conflictCount > 0) {
      return _SyncVisual(
        label: 'Conflict ${snapshot.stats.conflictCount}',
        icon: Icons.warning_amber_rounded,
        background: AppColors.warning.withValues(alpha: 0.2),
        border: AppColors.warning.withValues(alpha: 0.4),
      );
    }
    if (snapshot.stats.failedCount > 0) {
      return _SyncVisual(
        label: 'Retry ${snapshot.stats.failedCount}',
        icon: Icons.error_outline_rounded,
        background: AppColors.danger.withValues(alpha: 0.2),
        border: AppColors.danger.withValues(alpha: 0.4),
      );
    }
    if (!snapshot.backendReachable) {
      final pending = snapshot.stats.pendingCount;
      return _SyncVisual(
        label: pending > 0 ? 'Offline $pending' : 'Offline',
        icon: Icons.cloud_off_rounded,
        background: Colors.white.withValues(alpha: 0.16),
        border: Colors.white.withValues(alpha: 0.2),
      );
    }
    if (snapshot.stats.pendingCount > 0 || snapshot.stats.sendingCount > 0) {
      final pending = snapshot.stats.pendingCount + snapshot.stats.sendingCount;
      return _SyncVisual(
        label: 'Pending $pending',
        icon: Icons.schedule_send_rounded,
        background: AppColors.gold.withValues(alpha: 0.2),
        border: AppColors.gold.withValues(alpha: 0.4),
      );
    }
    return _SyncVisual(
      label: 'Synced',
      icon: Icons.cloud_done_rounded,
      background: AppColors.success.withValues(alpha: 0.2),
      border: AppColors.success.withValues(alpha: 0.4),
    );
  }

  Future<void> _showSyncDetails(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final syncAsync = ref.watch(syncStatusControllerProvider);
          final snapshot = syncAsync.valueOrNull;
          final controller = ref.read(syncStatusControllerProvider.notifier);
          final lastSynced = snapshot?.lastSyncedAt;
          final lastError = snapshot?.lastError;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync Status',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricCard(
                          label: 'Backend',
                          value: snapshot?.backendReachable == true
                              ? 'Reachable'
                              : 'Offline',
                        ),
                        _MetricCard(
                          label: 'Pending',
                          value: '${snapshot?.stats.pendingCount ?? 0}',
                        ),
                        _MetricCard(
                          label: 'Failed',
                          value: '${snapshot?.stats.failedCount ?? 0}',
                        ),
                        _MetricCard(
                          label: 'Conflict',
                          value: '${snapshot?.stats.conflictCount ?? 0}',
                        ),
                      ],
                    ),
                    if (lastSynced != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Last synced ${_formatTimestamp(lastSynced)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (lastError != null && lastError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          lastError,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if ((snapshot?.failedEntries.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      Text('Needs Attention',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ...snapshot!.failedEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FailedRow(entry: entry),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: syncAsync.isLoading
                                ? null
                                : () async {
                                    await controller.retryFailed();
                                  },
                            child: const Text('Retry Failed'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: syncAsync.isLoading
                                ? null
                                : () async {
                                    await controller.syncNow();
                                  },
                            child: const Text('Sync Now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _SyncVisual {
  const _SyncVisual({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color border;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.entry});

  final SyncQueueEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.entityType}:${entry.operation}',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.lastError != null && entry.lastError!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.lastError!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            entry.status,
            style: TextStyle(
              color: entry.status == 'conflict'
                  ? AppColors.warning
                  : AppColors.danger,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
