import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        onNavigate: (index) => setState(() => _index = index),
      ),
      const SalesScreen(),
      const InventoryScreen(),
      const ExpensesScreen(),
      const DebtsScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined), label: 'Sales'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Expenses'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined), label: 'Debts'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Report'),
        ],
      ),
    );
  }
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({
    required this.onSignOut,
    required this.onNavigate,
  });

  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;

  Future<void> _openBusinessSettings(
    BuildContext context,
    MerchantContext merchantContext,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BusinessSettingsSheet(initialContext: merchantContext),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(merchantContextProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final recentActivityAsync = ref.watch(dashboardRecentActivityProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F4E43), Color(0xFF1A6B5B), AppColors.canvas],
          stops: [0.0, 0.26, 0.26],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: contextAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DashboardErrorView(
          message: humanizeDashboardError(error),
          onRetry: () {
            ref.invalidate(merchantContextProvider);
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(dashboardRecentActivityProvider);
          },
        ),
        data: (merchantContext) {
          return SafeArea(
            child: Column(
              children: [
                _DashboardHeader(
                  merchantContext: merchantContext,
                  onEditBusiness: () =>
                      _openBusinessSettings(context, merchantContext),
                  onSignOut: onSignOut,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(merchantContextProvider);
                      ref.invalidate(dashboardSummaryProvider);
                      ref.invalidate(dashboardRecentActivityProvider);
                      await ref.read(merchantContextProvider.future);
                      await ref.read(dashboardSummaryProvider.future);
                      await ref.read(dashboardRecentActivityProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _SummaryCard(summaryAsync: summaryAsync),
                        const SizedBox(height: 16),
                        _QuickActionGrid(onNavigate: onNavigate),
                        const SizedBox(height: 18),
                        _InsightStrip(summaryAsync: summaryAsync),
                        const SizedBox(height: 18),
                        _RecentActivityCard(activityAsync: recentActivityAsync),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.merchantContext,
    required this.onEditBusiness,
    required this.onSignOut,
  });

  final MerchantContext merchantContext;
  final VoidCallback onEditBusiness;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${merchantContext.businessName}.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      merchantContext.businessType ?? 'Business overview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD9EFE9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEditBusiness,
                    icon:
                        const Icon(Icons.settings_rounded, color: Colors.white),
                    tooltip: 'Business settings',
                  ),
                  IconButton(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    tooltip: 'Sign out',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderBadge(
                icon: Icons.location_on_outlined,
                label:
                    merchantContext.storeLocation ?? merchantContext.storeName,
              ),
              _HeaderBadge(
                icon: Icons.schedule_outlined,
                label: merchantContext.timezone,
              ),
              const SyncStatusPill(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summaryAsync});

  final AsyncValue<DashboardSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final rows = [
      _SummaryMetric('Sales', 'GHS ${summary?.todaySalesTotal ?? '--'}'),
      _SummaryMetric('Expenses', 'GHS ${summary?.todayExpensesTotal ?? '--'}'),
      _SummaryMetric('Profit', 'GHS ${summary?.todayEstimatedProfit ?? '--'}'),
      _SummaryMetric('Debt', 'GHS ${summary?.debtOutstandingTotal ?? '--'}'),
    ];
    final lowStock = summary?.lowStockCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C7A67), Color(0xFF1A5F52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F2E28),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.auto_graph_rounded, color: Color(0xFFD7F3EA)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final tileWidth = isCompact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: rows
                    .map(
                      (row) => SizedBox(
                        width: tileWidth,
                        child: _SummaryTile(metric: row),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(
                icon: Icons.inventory_2_outlined,
                label:
                    lowStock == null ? 'Low stock --' : 'Low stock $lowStock',
              ),
              _StatusChip(
                icon: Icons.sync_alt_rounded,
                label: summary == null ? 'Syncing summary' : 'Live summary',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric(this.label, this.value);

  final String label;
  final String value;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: Color(0xFFD7F3EA),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    const actions = [
      _ActionItem(
          'Record Sale', Icons.point_of_sale_rounded, AppColors.forest, 1),
      _ActionItem('Add Expense', Icons.receipt_long_rounded, AppColors.gold, 3),
      _ActionItem('Credit Owed', Icons.group_rounded, AppColors.coral, 4),
      _ActionItem('Reports', Icons.bar_chart_rounded, AppColors.sky, 5),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions
              .map(
                (action) => SizedBox(
                  width: tileWidth,
                  child: _ActionButton(
                    item: action,
                    onTap: () => onNavigate(action.tabIndex),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem(this.label, this.icon, this.color, this.tabIndex);

  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.onTap,
  });

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.summaryAsync});

  final AsyncValue<DashboardSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final tileWidth =
            isCompact ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: tileWidth,
              child: _InsightCard(
                title: 'Healthy Profit',
                value: summary == null
                    ? '--'
                    : 'GHS ${summary.todayEstimatedProfit}',
                tint: AppColors.gold,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _InsightCard(
                title: 'Outstanding Debt',
                value: summary == null
                    ? '--'
                    : 'GHS ${summary.debtOutstandingTotal}',
                tint: AppColors.coral,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.tint,
  });

  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: tint, borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activityAsync});

  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context) {
    final rows = activityAsync.valueOrNull ?? const <DashboardActivity>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            if (activityAsync.isLoading && rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (activityAsync.hasError && rows.isEmpty)
              Text(
                humanizeDashboardError(
                  activityAsync.error ??
                      const FormatException('Unexpected activity error.'),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (rows.isEmpty)
              const Text('No recent activity yet.')
            else
              for (final row in rows) ...[
                _ActivityRow(data: row),
                if (row != rows.last) const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data});

  final DashboardActivity data;

  @override
  Widget build(BuildContext context) {
    final visual = _activityVisual(data.activityType);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: visual.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(visual.icon, color: visual.color),
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
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.detail} | ${_formatActivityTime(data.createdAt)}',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          'GHS ${data.amount}',
          style: TextStyle(
            color: visual.color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  _ActivityVisual _activityVisual(String raw) {
    return switch (raw) {
      'repayment' => const _ActivityVisual(
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
      'expense' => const _ActivityVisual(
          icon: Icons.receipt_long_rounded,
          color: AppColors.coral,
        ),
      _ => const _ActivityVisual(
          icon: Icons.shopping_basket_rounded,
          color: AppColors.amber,
        ),
    };
  }

  String _formatActivityTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}

class _ActivityVisual {
  const _ActivityVisual({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({
    required this.message,
    required this.onRetry,
  });

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
            const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
