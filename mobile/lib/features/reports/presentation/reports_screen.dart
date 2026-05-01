
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'widgets/period_tabs.dart';
import 'widgets/bar_chart_card.dart';
import 'widgets/donut_card.dart';
import 'widgets/top_customers_card.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/top_items_card.dart';
import 'widgets/debt_aging_card.dart';
import 'widgets/section_header.dart';
import 'widgets/offline_card.dart';
import 'widgets/reports_loading.dart';
import 'widgets/error_view.dart';
import 'widgets/reports_utils.dart';

// ── Reports screen ────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _periodIndex = 0; // 0=Today 1=Week 2=Month
  static const _periods = ['Today', 'This Week', 'This Month'];

  static final _compact = NumberFormat.compactCurrency(
    symbol: '₵',
    decimalDigits: 1,
  );


  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final insightsAsync = ref.watch(dashboardInsightsProvider);
    final debtsAsync = ref.watch(debtsControllerProvider);
    final expensesAsync = ref.watch(expensesControllerProvider);

    final summary = summaryAsync.valueOrNull;
    final insights = insightsAsync.valueOrNull;
    final receivables =
        debtsAsync.valueOrNull?.receivables ?? const <LocalReceivableRecord>[];
    final expenses = expensesAsync.valueOrNull ?? const <LocalExpenseRecord>[];
    final aging = computeAging(receivables);

    final (salesStr, expensesStr, profitStr, grossProfitStr) =
        switch (_periodIndex) {
      1 when insights != null => (
          insights.week.salesTotal,
          insights.week.expensesTotal,
          insights.week.estimatedProfit,
          insights.week.grossProfit,
        ),
      2 when insights != null => (
          insights.month.salesTotal,
          insights.month.expensesTotal,
          insights.month.estimatedProfit,
          insights.month.grossProfit,
        ),
      _ => (
          summary?.todaySalesTotal ?? '0.00',
          summary?.todayExpensesTotal ?? '0.00',
          summary?.todayEstimatedProfit ?? '0.00',
          summary?.todayGrossProfit ?? '0.00',
        ),
    };

    final Map<String, int> catMinors = {};
    for (final e in expenses) {
      catMinors[e.category] = (catMinors[e.category] ?? 0) + toMinor(e.amount);
    }
    final catTotal = catMinors.values.fold(0, (a, b) => a + b);

    final openRecs = receivables
        .where((r) => r.status == 'open')
        .toList(growable: false)
      ..sort((a, b) => toMinor(b.outstandingAmount)
          .compareTo(toMinor(a.outstandingAmount)));

    final paymentBreakdown = insights?.monthlyPaymentBreakdown ??
        const <DashboardPaymentBreakdown>[];
    final momoAmount = paymentBreakdown
        .where((item) => item.paymentMethodLabel == 'mobile_money')
        .fold<String>('0.00', (_, item) => item.totalAmount);
    final cashAmount = paymentBreakdown
        .where((item) => item.paymentMethodLabel == 'cash')
        .fold<String>('0.00', (_, item) => item.totalAmount);

    final hasGrossProfit = (double.tryParse(grossProfitStr) ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: summaryAsync.when(
        loading: () => const Center(child: ReportsLoading()),
        error: (e, _) => Center(
          child: ErrorView(
            message: humanizeDashboardError(e),
            onRetry: _refresh,
          ),
        ),
        data: (_) => NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── Collapsing Hero Header ────────────────────────
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF041C0B),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _ReportsHeroHeader(
                  period: _periods[_periodIndex],
                  salesStr: salesStr,
                  momoAmount: momoAmount,
                  cashAmount: cashAmount,
                  openDebtsCount: openRecs.length,
                ),
                title: innerBoxIsScrolled
                    ? const Text(
                        'Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      )
                    : null,
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
            ),

            // ── Sticky Period Tabs ────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabDelegate(
                child: Container(
                  color: AppColors.canvas,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: PeriodTabs(
                    selected: _periodIndex,
                    onSelected: (i) => setState(() => _periodIndex = i),
                  ),
                ),
              ),
            ),
          ],
          body: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: RefreshIndicator(
              color: AppColors.forest,
              onRefresh: () async => _refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // ── KPI Cards ─────────────────────────────────
                  _PremiumKpiRow(
                    salesStr: salesStr,
                    expensesStr: expensesStr,
                    profitStr: profitStr,
                    grossProfitStr: grossProfitStr,
                    hasGrossProfit: hasGrossProfit,
                  ),
                  const SizedBox(height: 16),

                  // ── Bar Chart ─────────────────────────────────
                  BarChartCard(
                    sales: double.tryParse(salesStr) ?? 0,
                    expenses: double.tryParse(expensesStr) ?? 0,
                    profit: double.tryParse(profitStr) ?? 0,
                    period: _periods[_periodIndex],
                  ),
                  const SizedBox(height: 16),

                  // ── Expense Breakdown + Top Customers (side by side) ──
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: DonutCard(
                            categoryMinors: catMinors,
                            totalMinor: catTotal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TopCustomersCard(
                            receivables: openRecs.take(4).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Payment Breakdown ─────────────────────────
                  const SectionHeader(
                    title: 'Payment Breakdown',
                    subtitle: 'Monthly',
                  ),
                  const SizedBox(height: 10),
                  insightsAsync.when(
                    loading: () => const AppSkeletonCard(lines: 3),
                    error: (_, __) => const OfflineCard(),
                    data: (ins) => PaymentBreakdownCard(
                      breakdown: ins.monthlyPaymentBreakdown,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Top Selling Items ─────────────────────────
                  const SectionHeader(
                    title: 'Top Selling Items',
                    subtitle: 'Monthly',
                  ),
                  const SizedBox(height: 10),
                  insightsAsync.when(
                    loading: () => const AppSkeletonCard(lines: 3),
                    error: (_, __) => const OfflineCard(),
                    data: (ins) =>
                        TopItemsCard(items: ins.monthlyTopSellingItems),
                  ),
                  const SizedBox(height: 20),

                  // ── Debt Aging ────────────────────────────────
                  const SectionHeader(title: 'Debt Aging'),
                  const SizedBox(height: 10),
                  DebtAgingCard(aging: aging),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardInsightsProvider);
    ref.invalidate(debtsControllerProvider);
    ref.invalidate(expensesControllerProvider);
  }
}

// ── Hero Header ───────────────────────────────────────────────────────────────

class _ReportsHeroHeader extends StatelessWidget {
  const _ReportsHeroHeader({
    required this.period,
    required this.salesStr,
    required this.momoAmount,
    required this.cashAmount,
    required this.openDebtsCount,
  });

  final String period;
  final String salesStr;
  final String momoAmount;
  final String cashAmount;
  final int openDebtsCount;

  static final _compact = NumberFormat.compactCurrency(
    symbol: '₵',
    decimalDigits: 1,
  );

  String _fmt(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return '₵$raw';
    return _compact.format(v);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Background gradient ──────────────────────────────
        Positioned.fill(
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF041C0B),
                  Color(0xFF083A1A),
                  Color(0xFF0F5A30),
                  Color(0xFF196E3D),
                ],
                stops: [0.0, 0.28, 0.62, 1.0],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
        ),
        // Radial bloom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.68, -0.72),
                radius: 0.92,
                colors: [
                  const Color(0xFF27A84E).withValues(alpha: 0.38),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom fade
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF010A04).withValues(alpha: 0.26),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),
        // Top highlight
        const Positioned(
          left: 0, right: 0, top: 0, height: 1.0,
          child: ColoredBox(color: Color(0x18FFFFFF)),
        ),

        // ── Content ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title row
              Row(
                children: [
                  Text(
                    'Reports',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Period badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hero revenue figure
              Text(
                'SALES REVENUE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fmt(salesStr),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Constantia',
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),

              // Stat pills row
              Row(
                children: [
                  _StatPill(
                    icon: Icons.phone_android_rounded,
                    value: _fmt(momoAmount),
                    label: 'MoMo',
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    icon: Icons.payments_rounded,
                    value: _fmt(cashAmount),
                    label: 'Cash',
                  ),
                  const SizedBox(width: 10),
                  _StatPill(
                    icon: Icons.people_alt_rounded,
                    value: '$openDebtsCount',
                    label: 'Open Debts',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Premium KPI Row ───────────────────────────────────────────────────────────

class _PremiumKpiRow extends StatelessWidget {
  const _PremiumKpiRow({
    required this.salesStr,
    required this.expensesStr,
    required this.profitStr,
    required this.grossProfitStr,
    required this.hasGrossProfit,
  });

  final String salesStr, expensesStr, profitStr, grossProfitStr;
  final bool hasGrossProfit;

  static final _compact = NumberFormat.compactCurrency(
    symbol: '₵',
    decimalDigits: 1,
  );

  String _fmt(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return '₵$raw';
    return _compact.format(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _KpiCard(
              label: 'Sales',
              value: _fmt(salesStr),
              icon: Icons.trending_up_rounded,
              accentColor: const Color(0xFF22C55E), // green
              iconBg: const Color(0xFF14532D),
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Expenses',
              value: _fmt(expensesStr),
              icon: Icons.receipt_long_outlined,
              accentColor: const Color(0xFFF87171), // soft red
              iconBg: const Color(0xFF450A0A),
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Est. Profit',
              value: _fmt(profitStr),
              icon: Icons.attach_money_rounded,
              accentColor: const Color(0xFFFBBF24), // amber
              iconBg: const Color(0xFF451A03),
            ),
          ],
        ),
        if (hasGrossProfit) ...[
          const SizedBox(height: 10),
          _GrossProfitBanner(value: '₵$grossProfitStr'),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.iconBg,
  });

  final String label, value;
  final IconData icon;
  final Color accentColor, iconBg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                fontFamily: 'Constantia',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrossProfitBanner extends StatelessWidget {
  const _GrossProfitBanner({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1A3B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insights_rounded,
                color: Color(0xFF60A5FA), size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gross Profit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  fontFamily: 'Constantia',
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Revenue minus\ncost of goods sold',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.muted.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat pill (shared hero pill style) ───────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.55), size: 13),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sliver delegate for sticky period tabs ────────────────────────────────────

class _SliverTabDelegate extends SliverPersistentHeaderDelegate {
  const _SliverTabDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverTabDelegate oldDelegate) => false;
}
