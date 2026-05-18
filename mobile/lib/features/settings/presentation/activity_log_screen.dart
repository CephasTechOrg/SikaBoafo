import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/streak_hero_header.dart';
import '../data/settings_api.dart';

final _activitySettingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(
    ref.watch(apiClientProvider),
    cache: KvCacheRepository(ref.watch(appDatabaseProvider)),
  ),
);

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final List<AuditLogEntry> _items = [];
  String? _nextCursor;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(_activitySettingsApiProvider).fetchAuditLogs();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(_activitySettingsApiProvider)
          .fetchAuditLogs(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isMerchantOwnerProvider).valueOrNull ?? true;
    if (!isOwner) {
      return const _OwnerOnlyActivityGate();
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: const FlexibleSpaceBar(
              background: StreakHeroHeader(
                leadingContentInset: 56,
                title: 'Activity',
                subtitle: 'Owner audit trail',
                badge: PremiumBadge(
                  label: 'Owner only',
                  icon: Icons.verified_user_outlined,
                  foreground: Colors.white,
                  background: Color(0x24FFFFFF),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _SheetCap()),
          SliverFillRemaining(
            hasScrollBody: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.surface),
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _body(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null && _items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        children: [
          _ActivityEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load activity',
            message: userFriendlyError(error),
            actionLabel: 'Try again',
            onAction: _refresh,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        children: const [
          _ActivityEmptyState(
            icon: Icons.history_rounded,
            title: 'No activity yet',
            message: 'Sensitive business actions will appear here.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        return _ActivityTile(entry: _items[index]);
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _items.length + (_nextCursor == null ? 0 : 1),
    );
  }
}

class _OwnerOnlyActivityGate extends StatelessWidget {
  const _OwnerOnlyActivityGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Only the business owner can view activity logs.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = _actionIcon(entry.action);
    final title = _actionTitle(entry.action);
    final time = DateFormat('MMM d, h:mm a').format(entry.createdAt.toLocal());
    final actor = entry.actorLabel == null ? 'System' : 'User ${entry.actorLabel}';
    final metaLabel = _metaLabel(entry);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.forest, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metaLabel == null ? '$actor • $time' : '$actor • $time\n$metaLabel',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.forest, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetCap extends StatelessWidget {
  const _SheetCap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: ColoredBox(
        color: Color(0xFF041C0B),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: AppRadii.heroRadius),
          child: ColoredBox(color: AppColors.surface),
        ),
      ),
    );
  }
}

IconData _actionIcon(String action) {
  return switch (action) {
    'sale.voided' => Icons.block_rounded,
    'receivable.cancelled' => Icons.money_off_rounded,
    'item.deleted' => Icons.delete_forever_rounded,
    'sale.created' => Icons.receipt_long_rounded,
    'sale.updated' => Icons.edit_note_rounded,
    'receivable.payment_recorded' => Icons.payments_rounded,
    'inventory.stock_in' => Icons.add_box_rounded,
    'inventory.adjusted' => Icons.tune_rounded,
    _ => Icons.history_rounded,
  };
}

String _actionTitle(String action) {
  return switch (action) {
    'sale.voided' => 'Sale voided',
    'sale.created' => 'Sale recorded',
    'sale.updated' => 'Sale updated',
    'receivable.cancelled' => 'Debt cancelled',
    'receivable.created' => 'Debt created',
    'receivable.payment_recorded' => 'Debt payment recorded',
    'customer.created' => 'Customer created',
    'item.created' => 'Item created',
    'item.updated' => 'Item updated',
    'item.deleted' => 'Item deleted',
    'inventory.stock_in' => 'Stock added',
    'inventory.adjusted' => 'Stock adjusted',
    'expense.created' => 'Expense recorded',
    'expense.updated' => 'Expense updated',
    'payment.initiated' => 'Payment initiated',
    'payment.succeeded' => 'Payment succeeded',
    'payment.failed' => 'Payment failed',
    _ => action.replaceAll('.', ' '),
  };
}

String? _metaLabel(AuditLogEntry entry) {
  final meta = entry.meta;
  if (meta == null || meta.isEmpty) return null;
  final name = meta['name'] ?? meta['customer_name'] ?? meta['item_name'];
  if (name is String && name.trim().isNotEmpty) {
    return name.trim();
  }
  final reason = meta['reason'];
  if (reason is String && reason.trim().isNotEmpty) {
    return 'Reason: ${reason.trim()}';
  }
  return null;
}
