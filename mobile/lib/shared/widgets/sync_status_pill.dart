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

          final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                                  value:
                                      '${snapshot?.stats.pendingCount ?? 0}',
                                ),
                                _MetricCard(
                                  label: 'Failed',
                                  value:
                                      '${snapshot?.stats.failedCount ?? 0}',
                                ),
                                _MetricCard(
                                  label: 'Conflict',
                                  value:
                                      '${snapshot?.stats.conflictCount ?? 0}',
                                ),
                              ],
                            ),
                            if (lastSynced != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Last synced ${_formatTimestamp(lastSynced)}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            if (lastError != null && lastError.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _ErrorBanner(message: lastError),
                            ],
                            if ((snapshot?.failedEntries.isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 16),
                              Text('Needs Attention',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 10),
                              ...snapshot!.failedEntries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _FailedRow(entry: entry),
                                ),
                              ),
                            ],
                            if ((snapshot?.conflictEntries.isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 16),
                              Text('Sync Conflicts',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                'These were changed on another device or by '
                                'your team while you were offline. We kept the '
                                'latest saved version. Choose what to do with '
                                'your offline change.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              ...snapshot!.conflictEntries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ConflictRow(entry: entry),
                                ),
                              ),
                            ],
                            if ((snapshot?.deadEntries.isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 16),
                              Text('Discarded',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              const SizedBox(height: 10),
                              ...snapshot!.deadEntries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _DeadRow(entry: entry),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      child: Row(
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
    final rawError = entry.lastError ?? '';
    final friendly = _humanizeSyncError(rawError);

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
            _humanizeOperationLabel(entry.entityType, entry.operation),
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (friendly.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              friendly,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _StatusPill(status: entry.status),
              const SizedBox(width: 8),
              Text(
                '$attempts attempt${attempts == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (rawError.isNotEmpty)
                TextButton(
                  onPressed: () => _showErrorDetails(context, rawError),
                  child: const Text('Details'),
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
    final rawError = entry.lastError ?? '';
    final friendly = _humanizeSyncError(rawError);

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
            _humanizeOperationLabel(entry.entityType, entry.operation),
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (friendly.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              friendly,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
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
                    ?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              if (rawError.isNotEmpty)
                TextButton(
                  onPressed: () => _showErrorDetails(context, rawError),
                  child: const Text('Details'),
                ),
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

class _ConflictRow extends ConsumerWidget {
  const _ConflictRow({required this.entry});

  final SyncQueueEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(syncStatusControllerProvider.notifier);
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final busy = syncAsync.isLoading;
    final rawError = entry.lastError ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _StatusPill(status: 'conflict'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _humanizeOperationLabel(entry.entityType, entry.operation),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re showing the latest version that was saved. You can keep that '
            'and drop your offline change, or try sending your change again.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (rawError.isNotEmpty)
                TextButton(
                  onPressed: () => _showErrorDetails(context, rawError),
                  child: const Text('Details'),
                ),
              const Spacer(),
              TextButton(
                onPressed: busy
                    ? null
                    : () => controller.retryConflict(queueId: entry.id),
                child: const Text('Try again'),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => controller.keepServerVersion(queueId: entry.id),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Keep latest'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final friendly = _humanizeSyncError(message);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friendly,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message.length > friendly.length) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showErrorDetails(context, message),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 0),
                  minimumSize: const Size(0, 28),
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('View details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isConflict = status == 'conflict';
    final color = isConflict ? AppColors.warning : AppColors.danger;
    final label = switch (status) {
      'conflict' => 'Conflict',
      'failed' => 'Failed',
      'sending' => 'Sending',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

void _showErrorDetails(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Error details'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: SelectableText(
            message,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _humanizeOperationLabel(String entity, String operation) {
  final entityLabel = switch (entity) {
    'sale' => 'Sale',
    'item' => 'Inventory item',
    'inventory' => 'Inventory',
    'expense' => 'Expense',
    'receivable' => 'Customer credit',
    'receivable_payment' => 'Credit payment',
    _ => entity.isEmpty ? 'Unknown' : entity,
  };
  final actionLabel = switch (operation) {
    'create' => 'recording',
    'update' => 'updating',
    'void' => 'voiding',
    'delete' => 'deleting',
    _ => operation,
  };
  return '$entityLabel · $actionLabel';
}

String _humanizeSyncError(String raw) {
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable')) {
    return 'No internet connection. We\'ll retry automatically when you\'re back online.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The server took too long to respond. Tap Retry to try again.';
  }
  if (lower.contains('insufficient stock')) {
    return 'Not enough stock on hand. Update inventory and retry.';
  }
  if (lower.contains('item not found') ||
      lower.contains('saleitemnotfounderror')) {
    return 'One of the items in this sale no longer exists. Discard this entry and re-record the sale.';
  }
  if (lower.contains('exceeded') && lower.contains('retry attempts')) {
    return 'Backend kept rejecting this operation. Open Details to see why, then Retry or Discard.';
  }
  if (lower.contains('paystack') &&
      (lower.contains('not connect') || lower.contains('not_connected'))) {
    return 'Paystack is not connected. Connect it in Settings before taking MoMo payments.';
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'Your session has expired. Sign in again to resume syncing.';
  }
  if (lower.contains('409') || lower.contains('conflict')) {
    return 'The server has a newer version of this record. Refresh and try again.';
  }
  if (lower.contains('500') || lower.contains('internal server error')) {
    return 'The server hit an unexpected error. Tap Retry — if it keeps happening, contact support.';
  }
  if (lower.contains('for update cannot be applied') ||
      lower.contains('featurenotsupported')) {
    return 'Server-side database conflict. This was patched — tap Retry to re-send.';
  }

  // Fallback: return the first line, truncated, so the user never sees a wall
  // of SQL or stack-trace.
  final firstLine = raw.split('\n').first.trim();
  if (firstLine.length > 180) {
    return '${firstLine.substring(0, 180)}…';
  }
  return firstLine;
}
