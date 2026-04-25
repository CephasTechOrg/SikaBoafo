import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../../../shared/widgets/sync_status_pill.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';
import 'reports_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_screen.dart';

// ─── Shell ────────────────────────────────────────────────────────────────────

class DashboardShellScreen extends ConsumerStatefulWidget {
  const DashboardShellScreen({super.key});

  @override
  ConsumerState<DashboardShellScreen> createState() =>
      _DashboardShellScreenState();
}

class _DashboardShellScreenState extends ConsumerState<DashboardShellScreen> {
  int _index = 0;

  Future<void> _signOut() async {
    await ref.read(secureTokenStorageProvider).clearSession();
    if (!mounted) return;
    context.go(AppRoute.auth.path);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeDashboard(
        onSignOut: _signOut,
        onNavigate: (i) => setState(() => _index = i),
      ),
      const SalesScreen(),
      const InventoryScreen(),
      const ExpensesScreen(),
      DebtsScreen(onNavigate: (i) => setState(() => _index = i)),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (v) => setState(() => _index = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded),
                label: 'Sales',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Debts',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home tab ─────────────────────────────────────────────────────────────────

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.onSignOut, required this.onNavigate});

  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;

  void _openSettings(BuildContext ctx) => ctx.push(AppRoute.settings.path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);

    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: ctxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, _) => _ErrorView(
          message: humanizeDashboardError(e),
          onRetry: () {
            ref.invalidate(merchantContextProvider);
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(dashboardRecentActivityProvider);
          },
        ),
        data: (mc) => SafeArea(
          child: Column(
            children: [
              _Header(
                mc: mc,
                summaryAsync: summaryAsync,
                onSettings: () => _openSettings(context),
                onNavigate: onNavigate,
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.vertical(
                      top: AppRadii.heroRadius,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RefreshIndicator(
                    color: AppColors.forest,
                    onRefresh: () async {
                      ref.invalidate(merchantContextProvider);
                      ref.invalidate(dashboardSummaryProvider);
                      ref.invalidate(dashboardRecentActivityProvider);
                      await Future.wait([
                        ref.read(merchantContextProvider.future),
                        ref.read(dashboardSummaryProvider.future),
                        ref.read(dashboardRecentActivityProvider.future),
                      ]);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
                      children: [
                        _QuickActions(onNavigate: onNavigate),
                        const SizedBox(height: 24),
                        _InsightBanner(summary: summaryAsync.valueOrNull),
                        const SizedBox(height: 24),
                        _RecentActivity(activityAsync: activityAsync),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({
    required this.mc,
    required this.summaryAsync,
    required this.onSettings,
    required this.onNavigate,
  });

  final MerchantContext mc;
  final AsyncValue<DashboardSummary> summaryAsync;
  final VoidCallback onSettings;
  final ValueChanged<int> onNavigate;

  String _firstName(String name) {
    final word = name.trim().split(' ').first;
    return word.isEmpty ? name : word;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = summaryAsync.valueOrNull;
    final syncSnapshot = ref.watch(syncStatusControllerProvider).valueOrNull;
    final sales = summary?.todaySalesTotal ?? '--';
    final debt = summary?.debtOutstandingTotal ?? '--';
    final lowStock = summary?.lowStockCount ?? 0;
    final connectivity = _syncHeadline(syncSnapshot);
    final descriptor = [mc.businessType, mc.storeName]
        .whereType<String>()
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(' · ');
    final location = (mc.storeLocation?.trim().isNotEmpty ?? false)
        ? mc.storeLocation!.trim()
        : mc.storeName;
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SikaBoafo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              _HeaderBtn(
                icon: Icons.notifications_outlined,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.settings_outlined, onTap: onSettings),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Column(
              children: [
                Text(
                  'Hi, ${_firstName(mc.businessName)}${descriptor.isEmpty ? '' : ' · $descriptor'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\u20B5$sales',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Constantia',
                    letterSpacing: -0.9,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sales Today',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStatTile(
                    label: 'Debt Owed',
                    value: '\u20B5$debt',
                    tone: AppColors.gold,
                    onTap: () => onNavigate(4),
                  ),
                ),
                _HeroDivider(),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Low Stock',
                    value: '$lowStock items',
                    tone: const Color(0xFFF6A6A6),
                    onTap: () => onNavigate(2),
                  ),
                ),
                _HeroDivider(),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Connectivity',
                    value: connectivity.$1,
                    tone: connectivity.$2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _HeaderPill(
                  icon: Icons.location_on_outlined,
                  label: location,
                ),
                const SizedBox(width: 8),
                _HeaderPill(
                  icon: Icons.schedule_outlined,
                  label: mc.timezone,
                ),
                const SizedBox(width: 8),
                const SyncStatusPill(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _syncHeadline(SyncStatusSnapshot? snapshot) {
    if (snapshot == null || snapshot.isSyncing) {
      return ('Syncing', const Color(0xFF9FD2FF));
    }
    if (!snapshot.backendReachable) {
      final pending = snapshot.stats.pendingCount;
      return (
        pending > 0 ? 'Offline $pending' : 'Offline',
        const Color(0xFFF6A6A6)
      );
    }
    if (snapshot.stats.failedCount > 0 || snapshot.stats.conflictCount > 0) {
      return ('Needs retry', AppColors.gold);
    }
    if (snapshot.stats.pendingCount > 0 || snapshot.stats.sendingCount > 0) {
      final pending = snapshot.stats.pendingCount + snapshot.stats.sendingCount;
      return ('Pending $pending', AppColors.gold);
    }
    return ('Online', const Color(0xFF8BE0B2));
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.label,
    required this.value,
    required this.tone,
    this.onTap,
  });

  final String label;
  final String value;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tone,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
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

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Pulse (stat grid) ────────────────────────────────────────────────

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Quick Actions')),
            Text(
              'Daily shortcuts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: _QuickTile(
                  icon: Icons.shopping_basket_rounded,
                  label: 'New Sale',
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  onTap: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTile(
                  icon: Icons.group_rounded,
                  label: 'Collect Debt',
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  onTap: () => onNavigate(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickTile(
                  icon: Icons.inventory_2_rounded,
                  label: 'Add Stock',
                  backgroundColor: AppColors.goldSoft,
                  foregroundColor: AppColors.gold,
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: backgroundColor == AppColors.surface
                  ? AppColors.border
                  : backgroundColor.withValues(alpha: 0.14),
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Business Insight Banner ──────────────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.summary});

  final DashboardSummary? summary;

  ({String title, String body, IconData icon, Color iconBg, Color iconColor}) _insight() {
    final s = summary;
    if (s == null) {
      return (
        title: 'Loading insights…',
        body: 'Fetching your business data.',
        icon: Icons.insights_rounded,
        iconBg: const Color(0xFFEAF0FF),
        iconColor: AppColors.info,
      );
    }
    if (s.lowStockCount > 0) {
      final n = s.lowStockCount;
      return (
        title: '$n item${n == 1 ? '' : 's'} running low on stock',
        body: 'Restock soon to avoid missed sales opportunities.',
        icon: Icons.inventory_2_rounded,
        iconBg: const Color(0xFFFFF3CD),
        iconColor: AppColors.warning,
      );
    }
    final debtIsZero =
        s.debtOutstandingTotal == '0.00' || s.debtOutstandingTotal == '0';
    if (!debtIsZero) {
      return (
        title: 'GHS ${s.debtOutstandingTotal} outstanding',
        body: 'Follow up with customers to collect unpaid balances.',
        icon: Icons.people_rounded,
        iconBg: const Color(0xFFFFF8E1),
        iconColor: AppColors.gold,
      );
    }
    return (
      title: 'All caught up today',
      body: 'No low stock or outstanding debts — great work!',
      icon: Icons.check_circle_rounded,
      iconBg: const Color(0xFFE8F5E9),
      iconColor: AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tip = _insight();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tip.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tip.icon, size: 20, color: tip.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.activityAsync});
  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = activityAsync.valueOrNull ?? const <DashboardActivity>[];
    final inventory = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
    // Build a lookup: itemId → imageAsset
    final imageByItemId = <String, String?>{
      for (final item in inventory)
        if (item.imageAsset != null) item.id: item.imageAsset,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Recent Activity'),
        const SizedBox(height: 12),
        if (activityAsync.isLoading && rows.isEmpty)
          _ActivitySkeleton()
        else if (rows.isEmpty)
          _ActivityEmpty()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, thickness: 1, color: AppColors.border),
              itemBuilder: (_, i) => _ActivityRow(
                data: rows[i],
                imageAsset: rows[i].itemId != null
                    ? imageByItemId[rows[i].itemId]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data, this.imageAsset});
  final DashboardActivity data;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final v = _visual(data.activityType);
    final timeStr = _relativeTime(data.createdAt);
    final isIncome =
        data.activityType == 'sale' || data.activityType == 'repayment';
    final amountStr = '${isIncome ? '+' : '−'} GHS ${data.amount}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Left: product image or type icon
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: imageAsset != null
                ? Image.asset(
                    imageAsset!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: v.color.withValues(alpha: 0.10),
                    child: Icon(v.icon, color: v.color, size: 22),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${data.detail}  ·  $timeStr',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amountStr,
            style: TextStyle(
              color: isIncome ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  _ActivityVisual _visual(String type) => switch (type) {
        'repayment' => const _ActivityVisual(
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
        'expense' => const _ActivityVisual(
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
          ),
        _ => const _ActivityVisual(
            icon: Icons.shopping_basket_rounded,
            color: AppColors.forest,
          ),
      };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActivityVisual {
  const _ActivityVisual({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

class _ActivitySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(
          3,
          (i) => Column(
            children: [
              if (i != 0) const Divider(height: 1, color: AppColors.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _shimmer(44, 44, radius: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shimmer(120, 13),
                          const SizedBox(height: 6),
                          _shimmer(80, 11),
                        ],
                      ),
                    ),
                    _shimmer(70, 13),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer(double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.muted, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No recent activity yet.\nRecord a sale to get started.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 28, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.forest,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
