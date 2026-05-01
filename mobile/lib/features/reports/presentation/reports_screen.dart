import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        data: (_) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Minimal Action Header ────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.ink, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.muted, size: 22),
                    ),
                  ],
                ),
              ),

              // ── Period Tabs ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: PeriodTabs(
                  selected: _periodIndex,
                  onSelected: (i) => setState(() => _periodIndex = i),
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.forest,
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      // ── KPI Cards ─────────────────────────────────
                      _PremiumKpiRow(
                        salesStr: salesStr,
                        expensesStr: expensesStr,
                        profitStr: profitStr,
                        grossProfitStr: grossProfitStr,
                        hasGrossProfit: hasGrossProfit,
                      ),
                      const SizedBox(height: 20),

                      // ── Bar Chart ─────────────────────────────────
                      BarChartCard(
                        sales: double.tryParse(salesStr) ?? 0,
                        expenses: double.tryParse(expensesStr) ?? 0,
                        profit: double.tryParse(profitStr) ?? 0,
                        period: _periods[_periodIndex],
                      ),
                      const SizedBox(height: 20),

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
                      const SizedBox(height: 24),

                      // ── Payment Breakdown ─────────────────────────
                      const SectionHeader(
                        title: 'Payment Breakdown',
                        subtitle: 'Monthly insights',
                      ),
                      const SizedBox(height: 12),
                      insightsAsync.when(
                        loading: () => const AppSkeletonCard(lines: 3),
                        error: (_, __) => const OfflineCard(),
                        data: (ins) => PaymentBreakdownCard(
                          breakdown: ins.monthlyPaymentBreakdown,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Top Selling Items ─────────────────────────
                      const SectionHeader(
                        title: 'Top Selling Items',
                        subtitle: 'Monthly performance',
                      ),
                      const SizedBox(height: 12),
                      insightsAsync.when(
                        loading: () => const AppSkeletonCard(lines: 3),
                        error: (_, __) => const OfflineCard(),
                        data: (ins) =>
                            TopItemsCard(items: ins.monthlyTopSellingItems),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
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
              iconBg: const Color(0xFF22C55E).withValues(alpha: 0.12),
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Expenses',
              value: _fmt(expensesStr),
              icon: Icons.receipt_long_outlined,
              accentColor: const Color(0xFFF87171), // soft red
              iconBg: const Color(0xFFF87171).withValues(alpha: 0.12),
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Est. Profit',
              value: _fmt(profitStr),
              icon: Icons.auto_graph_rounded,
              accentColor: const Color(0xFFFBBF24), // amber
              iconBg: const Color(0xFFFBBF24).withValues(alpha: 0.12),
            ),
          ],
        ),
        if (hasGrossProfit) ...[
          const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
                fontFamily: 'Constantia',
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insights_rounded,
                color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gross Profit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                  fontFamily: 'Constantia',
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Revenue minus\ncost of items sold',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.mutedSoft,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
