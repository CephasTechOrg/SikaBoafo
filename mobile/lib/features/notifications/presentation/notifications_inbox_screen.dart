import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
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
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not load notifications. Pull down to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
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
                    type: n.type,
                    onTap: () async {
                      await ref
                          .read(notificationsInboxControllerProvider.notifier)
                          .markRead(n.id);
                      if (!context.mounted) return;
                      // push preserves the notifications screen in the stack
                      // so the user can press back to return here.
                      context.push(n.route);
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
    required this.type,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  static _TonePair _tone(String type) => switch (type) {
        'debt' || 'receivable' => const _TonePair(
            DashboardMockup.warnTint, DashboardMockup.warn),
        'payment' => const _TonePair(
            DashboardMockup.greenTint, DashboardMockup.green700),
        'stock' || 'inventory' => const _TonePair(
            DashboardMockup.warnTint, DashboardMockup.warn),
        'sale' => const _TonePair(
            DashboardMockup.greenTint, DashboardMockup.green700),
        'danger' || 'error' => const _TonePair(
            DashboardMockup.dangerTint, DashboardMockup.danger),
        _ => const _TonePair(Color(0xFFF1F3F5), Color(0xFF6B7280)),
      };

  static IconData _icon(String type) => switch (type) {
        'debt' || 'receivable' => LucideIcons.wallet,
        'payment' => LucideIcons.checkCircle,
        'stock' || 'inventory' => LucideIcons.package,
        'sale' => LucideIcons.receipt,
        'danger' || 'error' => LucideIcons.alertCircle,
        _ => LucideIcons.bell,
      };

  @override
  Widget build(BuildContext context) {
    final tone = _tone(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unread
                ? DashboardMockup.green700.withValues(alpha: 0.22)
                : DashboardMockup.lineSoft,
          ),
          boxShadow: DashboardMockup.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icon(type), size: 19, color: tone.fg),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                            color: unread
                                ? DashboardMockup.ink
                                : DashboardMockup.ink2,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: DashboardMockup.ink3,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DashboardMockup.ink2,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Unread dot on right (mockup pattern)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: unread
                      ? DashboardMockup.green600
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TonePair {
  const _TonePair(this.bg, this.fg);
  final Color bg;
  final Color fg;
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

