import 'dart:math' show sin, pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/sync_status_pill.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';
import 'business_settings_sheet.dart';
import 'reports_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_screen.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────

const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF08302A), Color(0xFF1A6655)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x07000000), blurRadius: 4, offset: Offset(0, 1)),
];

const _kSubtleShadow = [
  BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
];

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

  Future<void> _openSettings(
      BuildContext ctx, MerchantContext mc) async {
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
      decoration: const BoxDecoration(gradient: _kHeaderGradient),
      child: ctxAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                onSettings: () => _openSettings(context, mc),
              ),
              // White content card sweeps over green
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
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
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                      children: [
                        _SummarySection(
                          summaryAsync: summaryAsync,
                          onReport: () => onNavigate(5),
                        ),
                        const SizedBox(height: 24),
                        _QuickActions(onNavigate: onNavigate),
                        const SizedBox(height: 24),
                        const _InsightBanner(),
                        const SizedBox(height: 16),
                        _MiniStatRow(summaryAsync: summaryAsync),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Premium store icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.forest,
                  size: 28,
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
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mc.businessType ?? mc.businessName,
                      style: const TextStyle(
                        color: Color(0xFFAAD4CC),
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
              // Notification icon
              _IconBtn(
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              // Settings icon
              _IconBtn(
                icon: Icons.settings_outlined,
                onTap: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.location_on_outlined,
                label: mc.storeLocation ?? mc.storeName,
              ),
              _Pill(
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
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

// ─── Today's Summary ──────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.summaryAsync,
    required this.onReport,
  });

  final AsyncValue<DashboardSummary> summaryAsync;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final s = summaryAsync.valueOrNull;
    final sales = s?.todaySalesTotal ?? '0.00';
    final expenses = s?.todayExpensesTotal ?? '0.00';
    final profit = s?.todayEstimatedProfit ?? '0.00';
    final debt = s?.debtOutstandingTotal ?? '0.00';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Summary",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
                      'View report',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.forest.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.forest.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_up_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFDCF4ED), Color(0xFFBCEBDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: AppColors.forest,
                  label: 'Sales',
                  amount: sales,
                  amountColor: AppColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_down_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFFEEDEA), Color(0xFFFDD9D3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: AppColors.coral,
                  label: 'Expenses',
                  amount: expenses,
                  amountColor: AppColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.savings_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFDCF4ED), Color(0xFFBCEBDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: AppColors.forest,
                  label: 'Profit',
                  amount: profit,
                  amountColor: AppColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.credit_card_rounded,
                  iconGradient: const LinearGradient(
                    colors: [Color(0xFFFEEDEA), Color(0xFFFDD9D3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  iconColor: AppColors.coral,
                  label: 'Debt',
                  amount: debt,
                  amountColor: AppColors.coral,
                  bold: true,
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
    required this.iconGradient,
    required this.iconColor,
    required this.label,
    required this.amount,
    required this.amountColor,
    this.bold = false,
  });

  final IconData icon;
  final LinearGradient iconGradient;
  final Color iconColor;
  final String label;
  final String amount;
  final Color amountColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEEF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: iconGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'GHS',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
              color: amountColor,
              height: 1.05,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

const _kActions = [
  _ActionDef(
    label: 'Record Sale',
    subtitle: 'Add a new sale',
    icon: Icons.shopping_basket_rounded,
    iconGradient: LinearGradient(
      colors: [Color(0xFFDCF4ED), Color(0xFFB5E8CE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconColor: AppColors.forest,
    tabIndex: 1,
  ),
  _ActionDef(
    label: 'Add Expense',
    subtitle: 'Track expenses',
    icon: Icons.receipt_long_rounded,
    iconGradient: LinearGradient(
      colors: [Color(0xFFFFF4E0), Color(0xFFFFE8A3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconColor: AppColors.amber,
    tabIndex: 3,
  ),
  _ActionDef(
    label: 'Credit Owed',
    subtitle: 'Manage debtors',
    icon: Icons.group_rounded,
    iconGradient: LinearGradient(
      colors: [Color(0xFFEBF4FF), Color(0xFFCCE0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconColor: Color(0xFF3B82F6),
    tabIndex: 4,
  ),
  _ActionDef(
    label: 'Reports',
    subtitle: 'View insights',
    icon: Icons.bar_chart_rounded,
    iconGradient: LinearGradient(
      colors: [Color(0xFFF3EEFF), Color(0xFFE2CCFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    iconColor: Color(0xFF7C3AED),
    tabIndex: 5,
  ),
];

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                def: _kActions[0],
                onTap: () => onNavigate(_kActions[0].tabIndex),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                def: _kActions[1],
                onTap: () => onNavigate(_kActions[1].tabIndex),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                def: _kActions[2],
                onTap: () => onNavigate(_kActions[2].tabIndex),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionCard(
                def: _kActions[3],
                onTap: () => onNavigate(_kActions[3].tabIndex),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionDef {
  const _ActionDef({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconGradient,
    required this.iconColor,
    required this.tabIndex,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final LinearGradient iconGradient;
  final Color iconColor;
  final int tabIndex;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.def, required this.onTap});

  final _ActionDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEEF0)),
            boxShadow: _kSubtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: def.iconGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(def.icon, color: def.iconColor, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      def.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.muted.withValues(alpha: 0.6),
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
  const _InsightBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3028), Color(0xFF1E7060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: _kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Basket image — bottom-anchored, slightly overflows for depth
          SizedBox(
            width: 130,
            child: Image.asset(
              'assets/images/basket.png',
              height: 165,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
          // Text panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Row(
                    children: [
                      Text('✨', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 5),
                      Text(
                        'Business Insight',
                        style: TextStyle(
                          color: Color(0xFF6DE4C4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Keep tracking to \n',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: 'grow',
                          style: TextStyle(
                            color: Color(0xFF6DE4C4),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: ' your business',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You're on the right path! Consistent tracking leads to better profits.",
                    style: TextStyle(
                      color: Color(0xFFAAD4CC),
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
    );
  }
}

// ─── Mini Stat Cards ──────────────────────────────────────────────────────────

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow({required this.summaryAsync});

  final AsyncValue<DashboardSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final s = summaryAsync.valueOrNull;
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            dot: AppColors.forest,
            label: 'Healthy Profit',
            value: s == null ? '--' : 'GHS ${s.todayEstimatedProfit}',
            valueColor: AppColors.forest,
            waveColor: AppColors.forest,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            dot: AppColors.coral,
            label: 'Outstanding Debt',
            value: s == null ? '--' : 'GHS ${s.debtOutstandingTotal}',
            valueColor: AppColors.coral,
            waveColor: AppColors.coral,
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.dot,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.waveColor,
  });

  final Color dot;
  final String label;
  final String value;
  final Color valueColor;
  final Color waveColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _kSubtleShadow,
        border: Border.all(color: const Color(0xFFEDEEF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(22),
            ),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(color: waveColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Filled wave area beneath the curve
    final fillPaint = Paint()..style = PaintingStyle.fill;
    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.18),
        color.withValues(alpha: 0.04),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Stroke on the wave curve
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final fillPath = Path();
    final strokePath = Path();

    const startY = 0.6; // vertical midpoint of wave (60% down)
    const amplitude = 0.22; // wave height relative to canvas height
    const cycles = 2.4; // number of wave cycles

    fillPath.moveTo(0, size.height);
    strokePath.moveTo(0, size.height * startY);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * startY +
          sin((x / size.width) * 2 * pi * cycles) * size.height * amplitude;
      fillPath.lineTo(x, y);
      strokePath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

// ─── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.activityAsync});

  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context) {
    final rows = activityAsync.valueOrNull ?? const <DashboardActivity>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.forest.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: AppColors.forest.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (activityAsync.isLoading && rows.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
          )
        else if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEDEEF0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.inbox_outlined, color: AppColors.muted, size: 20),
                SizedBox(width: 10),
                Text(
                  'No recent activity yet.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: _kSubtleShadow,
              border: Border.all(color: const Color(0xFFEDEEF0)),
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(
                height: 20,
                color: Color(0xFFF0F1F3),
              ),
              itemBuilder: (_, i) => _ActivityRow(data: rows[i]),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data});

  final DashboardActivity data;

  @override
  Widget build(BuildContext context) {
    final v = _visual(data.activityType);
    final fmt = DateFormat('MMM d, yyyy • h:mm a');

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: v.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(v.icon, color: v.color, size: 22),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${data.detail} • ${fmt.format(data.createdAt.toLocal())}',
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
        const SizedBox(width: 8),
        Text(
          'GHS ${data.amount}',
          style: TextStyle(
            color: v.color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  _Visual _visual(String type) => switch (type) {
        'repayment' => const _Visual(
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
        'expense' => const _Visual(
            icon: Icons.receipt_long_rounded,
            color: AppColors.coral,
          ),
        _ => const _Visual(
            icon: Icons.shopping_basket_rounded,
            color: AppColors.amber,
          ),
      };
}

class _Visual {
  const _Visual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 44, color: Colors.white),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
