import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../data/local/sync_queue_repository.dart';
import '../providers/sync_providers.dart';

/// Opens the sync detail bottom sheet. Call from any widget with a [WidgetRef].
Future<void> showSyncDetailsSheet(BuildContext context, WidgetRef ref) =>
    _showSyncDetails(context, ref);

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
                    if ((snapshot?.deadEntries.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      Text('Discarded',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ...snapshot!.deadEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DeadRow(entry: entry),
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

class _FailedRow extends ConsumerWidget {
  const _FailedRow({required this.entry});

  final SyncQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(syncStatusControllerProvider.notifier);
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final busy = syncAsync.isLoading;
    final attempts = entry.attempts;

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
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$attempts attempt${attempts == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.retryFailed(queueId: entry.id),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.moveToDeadLetter(queueId: entry.id),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeadRow extends ConsumerWidget {
  const _DeadRow({required this.entry});

  final SyncQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(syncStatusControllerProvider.notifier);
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final busy = syncAsync.isLoading;

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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${entry.attempts} attempt${entry.attempts == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
              const Spacer(),
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.reviveEntry(queueId: entry.id),
                child: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
