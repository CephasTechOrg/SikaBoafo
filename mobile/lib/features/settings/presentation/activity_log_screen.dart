import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
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
  bool _loading    = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final page =
          await ref.read(_activitySettingsApiProvider).fetchAuditLogs();
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
      if (mounted) setState(() => _loading = false);
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
        SnackBar(
          content: Text(userFriendlyError(error)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner =
        ref.watch(isMerchantOwnerProvider).valueOrNull ?? true;
    if (!isOwner) return const _OwnerOnlyGate();

    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: RefreshIndicator(
        color: DashboardMockup.green700,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  DashboardMockup.gutter, topPad + 14,
                  DashboardMockup.gutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: DashboardMockup.lineSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.arrowLeft,
                          size: 18, color: DashboardMockup.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activity Log',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: DashboardMockup.ink,
                            letterSpacing: -0.5, height: 1.1)),
                      Text('Owner audit trail',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5, fontWeight: FontWeight.w500,
                            color: DashboardMockup.ink2, height: 1.3)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  DashboardMockup.gutter, 24,
                  DashboardMockup.gutter, bottomPad + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header row
                  Row(
                    children: [
                      Text('RECENT ACTIVITY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: DashboardMockup.ink3)),
                      const Spacer(),
                      if (_items.isNotEmpty)
                        Text(
                          '${_items.length} event${_items.length == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: DashboardMockup.ink3)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Body
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: SizedBox(width: 28, height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: DashboardMockup.green700)),
                      ),
                    )
                  else if (_error != null && _items.isEmpty)
                    _EmptyCard(
                      icon: LucideIcons.alertCircle,
                      iconBg: DashboardMockup.dangerTint,
                      iconFg: DashboardMockup.danger,
                      title: 'Could not load activity',
                      message: userFriendlyError(_error!),
                      actionLabel: 'Try again',
                      onAction: _refresh,
                    )
                  else if (_items.isEmpty)
                    const _EmptyCard(
                      icon: LucideIcons.clock,
                      title: 'No activity yet',
                      message: 'Sensitive actions will appear here.',
                    )
                  else ...[
                    // Single card with all rows + dividers
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: DashboardMockup.cardShadow,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: DashboardMockup.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: DashboardMockup.lineSoft),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _items.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                    height: 1, thickness: 1,
                                    color: DashboardMockup.lineSoft),
                              _ActivityRow(entry: _items[i]),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Load more
                    if (_nextCursor != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          style: TextButton.styleFrom(
                            backgroundColor: DashboardMockup.card,
                            foregroundColor: DashboardMockup.green700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: DashboardMockup.lineSoft),
                            ),
                            textStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          child: _loadingMore
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DashboardMockup.green700))
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.arrowDown, size: 15),
                                    SizedBox(width: 6),
                                    Text('Load more'),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Activity row ──────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon     = _actionIcon(entry.action);
    final bg       = _actionBg(entry.action);
    final fg       = _actionFg(entry.action);
    final title    = _actionTitle(entry.action);
    final time     = DateFormat('MMM d, h:mm a')
        .format(entry.createdAt.toLocal());
    final actor    = entry.actorLabel ?? 'System';
    final meta     = _metaLabel(entry);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: bg,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: fg),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5, fontWeight: FontWeight.w700,
                      color: DashboardMockup.ink, height: 1.2)),
                const SizedBox(height: 3),
                Text('$actor · $time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5, fontWeight: FontWeight.w500,
                      color: DashboardMockup.ink3)),
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Text(meta,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w500,
                        color: DashboardMockup.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty card ────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.iconBg = DashboardMockup.greenTint,
    this.iconFg = DashboardMockup.green700,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: DashboardMockup.ink)),
                  const SizedBox(height: 2),
                  Text(message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: DashboardMockup.ink2)),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        backgroundColor: DashboardMockup.greenTint,
                        foregroundColor: DashboardMockup.green700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.refreshCw, size: 13),
                          const SizedBox(width: 5),
                          Text(actionLabel!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Owner-only gate ───────────────────────────────────────────────────────────

class _OwnerOnlyGate extends StatelessWidget {
  const _OwnerOnlyGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF041509),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Activity Log',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.white)),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: DashboardMockup.greenTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(LucideIcons.lock,
                    size: 28, color: DashboardMockup.green700),
              ),
              const SizedBox(height: 18),
              Text('Owner access only',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: DashboardMockup.ink),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Only the business owner can view activity logs.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w500,
                    color: DashboardMockup.ink2, height: 1.4),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  backgroundColor: DashboardMockup.greenTint,
                  foregroundColor: DashboardMockup.green700,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                child: const Text('Back to Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon / color helpers ──────────────────────────────────────────────────────

IconData _actionIcon(String action) => switch (action) {
      'sale.voided' || 'receivable.cancelled' => LucideIcons.x,
      'item.deleted'                          => LucideIcons.trash2,
      'sale.created'                          => LucideIcons.receipt,
      'sale.updated'                          => LucideIcons.pencil,
      'receivable.payment_recorded'           => LucideIcons.wallet,
      'inventory.stock_in' || 'inventory.adjusted' => LucideIcons.package,
      'payment.succeeded'                     => LucideIcons.check,
      'payment.failed'                        => LucideIcons.alertCircle,
      'customer.created'                      => LucideIcons.userPlus,
      _                                       => LucideIcons.clock,
    };

Color _actionBg(String action) {
  if (action.contains('voided') || action.contains('cancelled') ||
      action.contains('deleted') || action.contains('failed')) {
    return DashboardMockup.dangerTint;
  }
  if (action.contains('payment')) return DashboardMockup.warnTint;
  return DashboardMockup.greenTint;
}

Color _actionFg(String action) {
  if (action.contains('voided') || action.contains('cancelled') ||
      action.contains('deleted') || action.contains('failed')) {
    return DashboardMockup.danger;
  }
  if (action.contains('payment')) return DashboardMockup.warn;
  return DashboardMockup.green700;
}

String _actionTitle(String action) => switch (action) {
      'sale.voided'                  => 'Sale voided',
      'sale.created'                 => 'Sale recorded',
      'sale.updated'                 => 'Sale updated',
      'receivable.cancelled'         => 'Debt cancelled',
      'receivable.created'           => 'Debt created',
      'receivable.payment_recorded'  => 'Debt payment recorded',
      'customer.created'             => 'Customer added',
      'item.created'                 => 'Item created',
      'item.updated'                 => 'Item updated',
      'item.deleted'                 => 'Item deleted',
      'inventory.stock_in'           => 'Stock added',
      'inventory.adjusted'           => 'Stock adjusted',
      'expense.created'              => 'Expense recorded',
      'expense.updated'              => 'Expense updated',
      'payment.initiated'            => 'Payment initiated',
      'payment.succeeded'            => 'Payment succeeded',
      'payment.failed'               => 'Payment failed',
      _                              => action.replaceAll('.', ' '),
    };

String? _metaLabel(AuditLogEntry entry) {
  final meta = entry.meta;
  if (meta == null || meta.isEmpty) return null;
  final name =
      meta['name'] ?? meta['customer_name'] ?? meta['item_name'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  final reason = meta['reason'];
  if (reason is String && reason.trim().isNotEmpty) {
    return 'Reason: ${reason.trim()}';
  }
  return null;
}
