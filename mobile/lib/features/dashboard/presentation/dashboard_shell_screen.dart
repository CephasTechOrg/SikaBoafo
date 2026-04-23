import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/sync_status_pill.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';
import 'business_settings_sheet.dart';
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
      bottomNavigationBar: NavigationBar(
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
    );
  }
}

// ─── Home tab ─────────────────────────────────────────────────────────────────

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.onSignOut, required this.onNavigate});

  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;

  Future<void> _openSettings(BuildContext ctx, MerchantContext mc) async {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BusinessSettingsSheet(initialContext: mc),
    );
  }

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
              _Header(mc: mc, onSettings: () => _openSettings(context, mc)),
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
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                      children: [
                        _TodayPulse(
                          summaryAsync: summaryAsync,
                          onReport: () => onNavigate(5),
                        ),
                        const SizedBox(height: 24),
                        _QuickActions(onNavigate: onNavigate),
                        const SizedBox(height: 24),
                        const _InsightBanner(),
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

class _Header extends StatelessWidget {
  const _Header({required this.mc, required this.onSettings});

  final MerchantContext mc;
  final VoidCallback onSettings;

  String _firstName(String name) {
    final word = name.trim().split(' ').first;
    return word.isEmpty ? name : word;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.forest,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${_firstName(mc.businessName)} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mc.businessType ?? mc.businessName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeaderBtn(icon: Icons.notifications_outlined, onTap: () {}),
              const SizedBox(width: 8),
              _HeaderBtn(icon: Icons.settings_outlined, onTap: onSettings),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderPill(
                icon: Icons.location_on_outlined,
                label: mc.storeLocation ?? mc.storeName,
              ),
              _HeaderPill(
                icon: Icons.schedule_outlined,
                label: mc.timezone,
              ),
              const SyncStatusPill(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
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

class _TodayPulse extends StatelessWidget {
  const _TodayPulse({required this.summaryAsync, required this.onReport});

  final AsyncValue<DashboardSummary> summaryAsync;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final s = summaryAsync.valueOrNull;
    final sales = s?.todaySalesTotal ?? '--';
    final expenses = s?.todayExpensesTotal ?? '--';
    final profit = s?.todayEstimatedProfit ?? '--';
    final debt = s?.debtOutstandingTotal ?? '--';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's Pulse",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onReport,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Full report',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.forest.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.forest.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 2x2 grid using rows with dividers
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.forest,
                  label: 'Sales',
                  value: sales,
                  valueColor: AppColors.forest,
                  isLeft: true,
                  isTop: true,
                ),
              ),
              Container(width: 1, height: 88, color: AppColors.border),
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_down_rounded,
                  iconColor: AppColors.danger,
                  label: 'Expenses',
                  value: expenses,
                  valueColor: AppColors.danger,
                  isLeft: false,
                  isTop: true,
                ),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.savings_rounded,
                  iconColor: AppColors.success,
                  label: 'Profit',
                  value: profit,
                  valueColor: AppColors.success,
                  isLeft: true,
                  isTop: false,
                ),
              ),
              Container(width: 1, height: 88, color: AppColors.border),
              Expanded(
                child: _StatTile(
                  icon: Icons.account_balance_rounded,
                  iconColor: AppColors.warning,
                  label: 'Debt Owed',
                  value: debt,
                  valueColor: AppColors.warning,
                  isLeft: false,
                  isTop: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isLeft,
    required this.isTop,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final bool isLeft;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isLeft ? 18 : 16,
        isTop ? 14 : 14,
        isLeft ? 16 : 18,
        isTop ? 14 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'GHS ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    letterSpacing: -0.5,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Quick Actions'),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickTile(
              icon: Icons.shopping_basket_rounded,
              label: 'Record\nSale',
              iconColor: AppColors.forest,
              onTap: () => onNavigate(1),
            ),
            const SizedBox(width: 10),
            _QuickTile(
              icon: Icons.receipt_long_rounded,
              label: 'Add\nExpense',
              iconColor: AppColors.warning,
              onTap: () => onNavigate(3),
            ),
            const SizedBox(width: 10),
            _QuickTile(
              icon: Icons.group_rounded,
              label: 'Credit\nOwed',
              iconColor: AppColors.info,
              onTap: () => onNavigate(4),
            ),
            const SizedBox(width: 10),
            _QuickTile(
              icon: Icons.bar_chart_rounded,
              label: 'View\nReports',
              iconColor: AppColors.muted,
              onTap: () => onNavigate(5),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Business Insight Banner ──────────────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  const _InsightBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forestNight, AppColors.forest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle pattern overlay
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: Image.asset(
                  'assets/images/basket.png',
                  height: 160,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 22, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '✨  Business Tip',
                          style: TextStyle(
                            color: Color(0xFF6DE4C4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Track daily to\ngrow faster',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Consistent records reveal your best opportunities.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 11,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
        Row(
          children: [
            const Expanded(child: _SectionLabel('Recent Activity')),
            GestureDetector(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.forest.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppColors.forest.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
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
              if (i != 0)
                const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
