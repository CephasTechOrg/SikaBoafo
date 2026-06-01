import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../providers/notifications_inbox_providers.dart';

enum _NotifFilter { all, unread }

class NotificationsInboxScreen extends ConsumerStatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  ConsumerState<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends ConsumerState<NotificationsInboxScreen> {
  _NotifFilter _filter = _NotifFilter.all;

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(notificationsInboxControllerProvider);

    return MockupScreenScaffold(
      title: 'Notifications',
      subtitle: 'Updates and payment activity',
      heroHeight: 158,
      onBack: () => context.pop(),
      actions: [
        MockupHeaderAction(
          icon: Icons.done_all_rounded,
          tooltip: 'Mark all as read',
          onTap: () => ref
              .read(notificationsInboxControllerProvider.notifier)
              .markAllRead(),
        ),
        MockupHeaderAction(
          icon: Icons.delete_sweep_rounded,
          tooltip: 'Clear all',
          onTap: () => _confirm(
            context,
            title: 'Clear all notifications?',
            confirmLabel: 'Clear',
            onConfirm: () => ref
                .read(notificationsInboxControllerProvider.notifier)
                .clearAll(),
          ),
        ),
      ],
      body: inboxAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load notifications.\n${e.toString()}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allItems) {
          final items = _filter == _NotifFilter.unread
              ? allItems.where((n) => !n.isRead).toList(growable: false)
              : allItems;
          if (allItems.isEmpty) {
            return const _EmptyInbox();
          }
          final grouped = _groupByDay(items);
          return RefreshIndicator(
            onRefresh: () => ref
                .read(notificationsInboxControllerProvider.notifier)
                .refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filter == _NotifFilter.all,
                      onTap: () => setState(() => _filter = _NotifFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Unread',
                      selected: _filter == _NotifFilter.unread,
                      onTap: () => setState(() => _filter = _NotifFilter.unread),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} item${items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const _EmptyInbox(
                    title: 'No matching notifications',
                    subtitle: 'Try switching filter tabs.',
                  ),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  for (final n in entry.value) ...[
                    Dismissible(
                  key: ValueKey('notif-${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 18),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                  ),
                  confirmDismiss: (_) async {
                    var ok = false;
                    await _confirm(
                      context,
                      title: 'Delete this notification?',
                      confirmLabel: 'Delete',
                      onConfirm: () async {
                        ok = true;
                        await ref
                            .read(notificationsInboxControllerProvider.notifier)
                            .deleteOne(n.id);
                      },
                    );
                    return ok;
                  },
                      child: _NotificationTile(
                    title: n.title,
                    body: n.body,
                    timeLabel: _formatTime(n.createdAtMs),
                    unread: !n.isRead,
                    onTap: () async {
                      await ref
                          .read(notificationsInboxControllerProvider.notifier)
                          .markRead(n.id);
                      if (!context.mounted) return;
                      context.go(n.route);
                    },
                    onMarkRead: () => ref
                        .read(notificationsInboxControllerProvider.notifier)
                        .markRead(n.id),
                    onDelete: () => ref
                        .read(notificationsInboxControllerProvider.notifier)
                        .deleteOne(n.id),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('h:mm a').format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  static Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await onConfirm();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({
    this.title = 'No notifications yet',
    this.subtitle = 'When something important happens, it will show up here.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 44, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.unread,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread
                ? AppColors.forest.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 7, right: 12),
              decoration: BoxDecoration(
                color: unread ? AppColors.forest : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread ? FontWeight.w900 : FontWeight.w800,
                            color: AppColors.ink,
                            fontSize: 14.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.inkSoft, height: 1.3),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'read') onMarkRead();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                if (unread)
                  const PopupMenuItem(
                    value: 'read',
                    child: Text('Mark as read'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert_rounded, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

Map<String, List<dynamic>> _groupByDay(List<dynamic> items) {
  final now = DateTime.now();
  final grouped = <String, List<dynamic>>{};
  for (final n in items) {
    final dt = DateTime.fromMillisecondsSinceEpoch(n.createdAtMs);
    final key = DateUtils.isSameDay(dt, now)
        ? 'TODAY'
        : DateUtils.isSameDay(dt, now.subtract(const Duration(days: 1)))
            ? 'YESTERDAY'
            : DateFormat('EEE, MMM d').format(dt).toUpperCase();
    grouped.putIfAbsent(key, () => []).add(n);
  }
  return grouped;
}

