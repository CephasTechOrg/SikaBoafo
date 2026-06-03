import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/app_components.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'widgets/period_tabs.dart';
import 'widgets/bar_chart_card.dart';
import 'widgets/line_chart_card.dart';
import 'widgets/donut_card.dart';
import 'widgets/top_customers_card.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/top_items_card.dart';
import 'widgets/offline_card.dart';
import 'widgets/reports_loading.dart';
import 'widgets/error_view.dart';
import 'widgets/reports_utils.dart';
import 'widgets/debt_aging_card.dart';

// ── Reports screen ────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _periodIndex = 0; // 0=Today 1=Week 2=Month
  static const _periodKeys = ['today', 'week', 'month'];

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

    final (salesStr, expensesStr, profitStr) = switch (_periodIndex) {
      1 when insights != null => (
          insights.week.salesTotal,
          insights.week.expensesTotal,
          insights.week.estimatedProfit,
        ),
      2 when insights != null => (
          insights.month.salesTotal,
          insights.month.expensesTotal,
          insights.month.estimatedProfit,
        ),
      _ => (
          summary?.todaySalesTotal ?? '0.00',
          summary?.todayExpensesTotal ?? '0.00',
          summary?.todayEstimatedProfit ?? '0.00',
        ),
    };

    final Map<String, int> catMinors = {};
    for (final e in expenses) {
      catMinors[e.category] = (catMinors[e.category] ?? 0) + toMinor(e.amount);
    }
    final catTotal = catMinors.values.fold(0, (a, b) => a + b);

    final openRecs = receivables
        .where((r) => r.status == 'open' || r.status == 'partially_paid')
        .toList(growable: false)
      ..sort((a, b) => toMinor(b.outstandingAmount)
          .compareTo(toMinor(a.outstandingAmount)));

    // Sum of outstanding amounts for the Receivables KPI card
    final receivablesMinor =
        openRecs.fold(0, (sum, r) => sum + toMinor(r.outstandingAmount));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: summaryAsync.when(
        loading: () => const Center(child: ReportsLoading()),
        error: (e, _) => Center(
          child: ErrorView(
            message: humanizeDashboardError(e),
            onRetry: _refresh,
          ),
        ),
        data: (_) => Column(
          children: [
            _ReportsHero(onBack: () => Navigator.of(context).maybePop(), onRefresh: _refresh),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF6F8F7),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: RefreshIndicator(
                    color: DebtsUi.greenMid,
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      children: [
                        const SizedBox(height: 14),

                        // ── Period Tabs (inside sheet) ─────────────────────
                        PeriodTabs(
                          selected: _periodIndex,
                          onSelected: (i) => setState(() => _periodIndex = i),
                        ),
                        const SizedBox(height: 16),

                        // ── KPI Grid (2×2) ─────────────────────────────────
                        _KpiGrid(
                          salesStr: salesStr,
                          expensesStr: expensesStr,
                          profitStr: profitStr,
                          receivablesMinor: receivablesMinor,
                        ),
                        const SizedBox(height: 16),

                        // ── Line Chart (trend) — falls back to bar chart if
                        // the /reports/trend endpoint isn't live yet on this
                        // backend deployment.
                        ref.watch(dashboardTrendProvider(
                          _periodKeys[_periodIndex],
                        )).when(
                          loading: () => const AppSkeletonCard(lines: 4),
                          error: (_, __) => BarChartCard(
                            sales: double.tryParse(salesStr) ?? 0,
                            expenses: double.tryParse(expensesStr) ?? 0,
                            profit: double.tryParse(profitStr) ?? 0,
                            period: _periodKeys[_periodIndex],
                          ),
                          data: (points) => LineChartCard(
                            points: points,
                            period: _periodKeys[_periodIndex],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Expenses by Category ───────────────────────────
                        const _SectionTitle('Expenses by Category'),
                        const SizedBox(height: 12),
                        DonutCard(
                          categoryMinors: catMinors,
                          totalMinor: catTotal,
                        ),
                        const SizedBox(height: 14),

                        // ── Payment Methods ────────────────────────────────
                        const _SectionTitle('Payment Methods'),
                        const SizedBox(height: 12),
                        insightsAsync.when(
                          loading: () => const AppSkeletonCard(lines: 3),
                          error: (_, __) => const OfflineCard(),
                          data: (ins) => PaymentBreakdownCard(
                            breakdown: ins.monthlyPaymentBreakdown,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Top Selling Items ──────────────────────────────
                        const _SectionTitle('Top Selling Items', pill: 'By revenue'),
                        const SizedBox(height: 12),
                        insightsAsync.when(
                          loading: () => const AppSkeletonCard(lines: 3),
                          error: (_, __) => const OfflineCard(),
                          data: (ins) =>
                              TopItemsCard(items: ins.monthlyTopSellingItems),
                        ),
                        const SizedBox(height: 14),

                        // ── Top Receivables ────────────────────────────────
                        const _SectionTitle('Top Receivables', pill: 'By balance'),
                        const SizedBox(height: 12),
                        TopCustomersCard(receivables: openRecs.take(3).toList()),
                        const SizedBox(height: 14),

                        // ── Debt Aging ─────────────────────────────────────
                        const _SectionTitle('Debt Aging', pill: 'Receivables'),
                        const SizedBox(height: 12),
                        debtsAsync.when(
                          loading: () => const AppSkeletonCard(lines: 4),
                          error: (_, __) => const OfflineCard(),
                          data: (_) => DebtAgingCard(
                            aging: computeAging(receivables),
                          ),
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

// ── Reports Hero ──────────────────────────────────────────────────────────────

class _ReportsHero extends StatelessWidget {
  const _ReportsHero({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + 14;
    return Stack(
      children: [
        // ── Gradient background ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(gradient: DebtsUi.heroGradient),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPad, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button (36×36, radius 12)
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.arrowLeft,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Reports',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Business insights',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh glass button (38×38, circle)
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.refreshCw,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Glow orb top-right ───────────────────────────────────────────────
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }
}

// ── KPI Grid (2×2, 4 cards) ────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.salesStr,
    required this.expensesStr,
    required this.profitStr,
    required this.receivablesMinor,
  });

  final String salesStr, expensesStr, profitStr;
  final int receivablesMinor;

  static final _compact = NumberFormat.compactCurrency(
    symbol: '₵',
    decimalDigits: 1,
  );

  String _fmt(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return '₵$raw';
    return _compact.format(v);
  }

  String _fmtMinor(int minor) {
    return _compact.format(minor / 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.trendingUp,
                label: 'Sales',
                value: _fmt(salesStr),
                tone: _KpiTone.green,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.receipt,
                label: 'Expenses',
                value: _fmt(expensesStr),
                tone: _KpiTone.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.coins,
                label: 'Est. Profit',
                value: _fmt(profitStr),
                tone: _KpiTone.green,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _KpiCard(
                icon: LucideIcons.wallet,
                label: 'Receivables',
                value: _fmtMinor(receivablesMinor),
                tone: _KpiTone.neutral,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _KpiTone { green, warn, neutral }

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label, value;
  final _KpiTone tone;

  Color get _iconBg => switch (tone) {
        _KpiTone.green => const Color(0xFFEAF6EF),
        _KpiTone.warn => const Color(0xFFFAF3E1),
        _KpiTone.neutral => const Color(0xFFF1F3F5),
      };

  Color get _iconFg => switch (tone) {
        _KpiTone.green => const Color(0xFF0F7A4A),
        _KpiTone.warn => const Color(0xFFBE8A2C),
        _KpiTone.neutral => const Color(0xFF6B7280),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF1F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: _iconFg, size: 17),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.pill});

  final String title;
  final String? pill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.01 * 18,
            ),
          ),
        ),
        if (pill != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pill!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F7A4A),
              ),
            ),
          ),
      ],
    );
  }
}
