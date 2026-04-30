import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'widgets/report_hero_chip.dart';
import 'widgets/period_tabs.dart';
import 'widgets/kpi_row.dart';
import 'widgets/bar_chart_card.dart';
import 'widgets/donut_card.dart';
import 'widgets/top_customers_card.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/top_items_card.dart';
import 'widgets/debt_aging_card.dart';
import 'widgets/business_summary_card.dart';
import 'widgets/section_header.dart';
import 'widgets/empty_card.dart';
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            Stack(
              children: [
                const Positioned.fill(child: HeroBackdrop()),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reports',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Performance overview and business health',
                                  style: TextStyle(
                                    color: AppColors.heroSubtitle,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _periods[_periodIndex],
                                    style: const TextStyle(
                                      color: AppColors.heroSubtitle,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '\u20B5$salesStr',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'Constantia',
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ReportHeroChip(
                            label: '\u20B5$momoAmount',
                            value: 'MoMo Mix',
                            tone: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          ReportHeroChip(
                            label: '\u20B5$cashAmount',
                            value: 'Cash Mix',
                            tone: const Color(0xFF8BE0B2),
                          ),
                          const SizedBox(width: 8),
                          ReportHeroChip(
                            label: '${openRecs.length}',
                            value: 'Open Debts',
                            tone: AppColors.gold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
            Expanded(
              child: PremiumSurface(
                child: summaryAsync.when(
                  loading: () => const ReportsLoading(),
                  error: (e, _) => ErrorView(
                    message: humanizeDashboardError(e),
                    onRetry: _refresh,
                  ),
                  data: (_) => RefreshIndicator(
                    color: AppColors.forest,
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      children: [
                        PeriodTabs(
                          selected: _periodIndex,
                          onSelected: (i) => setState(() => _periodIndex = i),
                        ),
                        const SizedBox(height: 16),
                        KpiRow(
                          sales: salesStr,
                          expenses: expensesStr,
                          profit: profitStr,
                          grossProfit: grossProfitStr,
                        ),
                        const SizedBox(height: 16),
                        BarChartCard(
                          sales: double.tryParse(salesStr) ?? 0,
                          expenses: double.tryParse(expensesStr) ?? 0,
                          profit: double.tryParse(profitStr) ?? 0,
                          period: _periods[_periodIndex],
                        ),
                        const SizedBox(height: 16),
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
                        const SectionHeader(title: 'Debt Aging'),
                        const SizedBox(height: 10),
                        DebtAgingCard(aging: aging),
                        const SizedBox(height: 20),
                        BusinessSummaryCard(
                          debtOutstanding:
                              summary?.debtOutstandingTotal ?? '0.00',
                          lowStockCount: summary?.lowStockCount ?? 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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

// ── Header icon button ────────────────────────────────────────────────────────



// ── Period tabs ───────────────────────────────────────────────────────────────



// ── KPI row ───────────────────────────────────────────────────────────────────



// ── Bar chart card ────────────────────────────────────────────────────────────





// ── Donut chart card ──────────────────────────────────────────────────────────





// ── Top customers card ────────────────────────────────────────────────────────



// ── Payment breakdown card ────────────────────────────────────────────────────



// ── Top items card ────────────────────────────────────────────────────────────



// ── Debt aging card ───────────────────────────────────────────────────────────





// ── Business summary card ─────────────────────────────────────────────────────





// ── Shared helpers ────────────────────────────────────────────────────────────












