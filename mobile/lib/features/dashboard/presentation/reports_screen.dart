import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

// ── Chart palette ─────────────────────────────────────────────────────────────

const _kPieColors = [
  AppColors.forest,
  AppColors.info,
  AppColors.warning,
  AppColors.gold,
  AppColors.danger,
  AppColors.success,
  AppColors.muted,
];

// ── Helpers ───────────────────────────────────────────────────────────────────

int _toMinor(String v) {
  final raw = v.trim();
  final m = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (m == null) return 0;
  final p = raw.split('.');
  final dec = p.length == 2 ? p[1].padRight(2, '0') : '00';
  return int.parse(p[0]) * 100 + int.parse(dec);
}

String _fmtMoney(String v) => '\u20B5$v';

// O(n) single-pass debt aging — YYYY-MM-DD lexicographic order is valid.
class _DebtAging {
  const _DebtAging(
      {required this.overdue,
      required this.dueSoon,
      required this.current,
      required this.noDue});
  final int overdue, dueSoon, current, noDue;
  int get total => overdue + dueSoon + current + noDue;
}

_DebtAging _computeAging(List<LocalReceivableRecord> receivables) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final soon = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 7)));
  int ov = 0, ds = 0, cu = 0, nd = 0;
  for (final r in receivables) {
    if (r.status != 'open') continue;
    final d = r.dueDateIso;
    if (d == null || d.isEmpty) {
      nd++;
    } else if (d.compareTo(today) < 0) {
      ov++;
    } else if (d.compareTo(soon) <= 0) {
      ds++;
    } else {
      cu++;
    }
  }
  return _DebtAging(overdue: ov, dueSoon: ds, current: cu, noDue: nd);
}

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
    final aging = _computeAging(receivables);

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
      catMinors[e.category] = (catMinors[e.category] ?? 0) + _toMinor(e.amount);
    }
    final catTotal = catMinors.values.fold(0, (a, b) => a + b);

    final openRecs = receivables
        .where((r) => r.status == 'open')
        .toList(growable: false)
      ..sort((a, b) => _toMinor(b.outstandingAmount)
          .compareTo(_toMinor(a.outstandingAmount)));
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
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.hero),
              child: SafeArea(
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
                          _ReportHeroChip(
                            label: '\u20B5$momoAmount',
                            value: 'MoMo Mix',
                            tone: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          _ReportHeroChip(
                            label: '\u20B5$cashAmount',
                            value: 'Cash Mix',
                            tone: const Color(0xFF8BE0B2),
                          ),
                          const SizedBox(width: 8),
                          _ReportHeroChip(
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
            ),
            Expanded(
              child: PremiumSurface(
                child: summaryAsync.when(
                  loading: () => const _ReportsLoading(),
                  error: (e, _) => _ErrorView(
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
                        _PeriodTabs(
                          selected: _periodIndex,
                          onSelected: (i) => setState(() => _periodIndex = i),
                        ),
                        const SizedBox(height: 16),
                        _KpiRow(
                          sales: salesStr,
                          expenses: expensesStr,
                          profit: profitStr,
                          grossProfit: grossProfitStr,
                        ),
                        const SizedBox(height: 16),
                        _BarChartCard(
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
                                child: _DonutCard(
                                  categoryMinors: catMinors,
                                  totalMinor: catTotal,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TopCustomersCard(
                                  receivables: openRecs.take(4).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionHeader(
                          title: 'Payment Breakdown',
                          subtitle: 'Monthly',
                        ),
                        const SizedBox(height: 10),
                        insightsAsync.when(
                          loading: () => const AppSkeletonCard(lines: 3),
                          error: (_, __) => const _OfflineCard(),
                          data: (ins) => _PaymentBreakdownCard(
                            breakdown: ins.monthlyPaymentBreakdown,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionHeader(
                          title: 'Top Selling Items',
                          subtitle: 'Monthly',
                        ),
                        const SizedBox(height: 10),
                        insightsAsync.when(
                          loading: () => const AppSkeletonCard(lines: 3),
                          error: (_, __) => const _OfflineCard(),
                          data: (ins) =>
                              _TopItemsCard(items: ins.monthlyTopSellingItems),
                        ),
                        const SizedBox(height: 20),
                        const _SectionHeader(title: 'Debt Aging'),
                        const SizedBox(height: 10),
                        _DebtAgingCard(aging: aging),
                        const SizedBox(height: 20),
                        _BusinessSummaryCard(
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

class _ReportHeroChip extends StatelessWidget {
  const _ReportHeroChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period tabs ───────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['Today', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.forest : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.muted,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.sales,
    required this.expenses,
    required this.profit,
    this.grossProfit = '0.00',
  });
  final String sales, expenses, profit, grossProfit;
  static final NumberFormat _compactMoneyFormatter =
      NumberFormat.compactCurrency(
    symbol: '\u20B5',
    decimalDigits: 1,
  );

  bool get _hasGrossProfit {
    final v = double.tryParse(grossProfit) ?? 0.0;
    return v > 0;
  }

  String _compactMoney(String raw) {
    final value = double.tryParse(raw);
    if (value == null) return '\u20B5$raw';
    return _compactMoneyFormatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final compactSales = _compactMoney(sales);
    final compactExpenses = _compactMoney(expenses);
    final compactProfit = _compactMoney(profit);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatCard(
                label: 'Sales',
                value: compactSales,
                icon: Icons.trending_up_rounded,
                accent: AppColors.forest,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatCard(
                label: 'Expenses',
                value: compactExpenses,
                icon: Icons.receipt_long_outlined,
                accent: AppColors.danger,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppStatCard(
                label: 'Est. Profit',
                value: compactProfit,
                icon: Icons.attach_money_rounded,
                accent: AppColors.warning,
              ),
            ),
          ],
        ),
        if (_hasGrossProfit) ...[
          const SizedBox(height: 10),
          AppStatCard(
            label: 'Gross Profit',
            value: '\u20B5$grossProfit',
            caption: 'Revenue minus cost of goods sold',
            icon: Icons.insights_rounded,
            accent: AppColors.info,
          ),
        ],
      ],
    );
  }
}

// ── Bar chart card ────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.sales,
    required this.expenses,
    required this.profit,
    required this.period,
  });

  final double sales, expenses, profit;
  final String period;

  @override
  Widget build(BuildContext context) {
    final peak = math.max(
        1.0, [sales, expenses, profit].fold(0.0, (a, b) => math.max(a, b)));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales vs Expenses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              AppStatusPill(
                label: period,
                variant: AppPillVariant.neutral,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _BarChartPainter(
                bars: [
                  (
                    label: 'Sales',
                    value: sales,
                    color: AppColors.forest,
                    colorDark: AppColors.forestDark,
                  ),
                  (
                    label: 'Expenses',
                    value: expenses,
                    color: AppColors.danger,
                    colorDark: const Color(0xFF991B1B),
                  ),
                  (
                    label: 'Profit',
                    value: profit,
                    color: AppColors.warning,
                    colorDark: const Color(0xFFB45309),
                  ),
                ],
                maxValue: peak,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.forest, label: 'Sales'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.danger, label: 'Expenses'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.warning, label: 'Profit'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.bars, required this.maxValue});

  final List<
      ({
        String label,
        double value,
        Color color,
        Color colorDark,
      })> bars;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 22.0;
    const botPad = 28.0;
    const sidePad = 8.0;
    final chartH = size.height - topPad - botPad;
    final chartW = size.width - sidePad * 2;
    final slotW = chartW / bars.length;
    final barW = slotW * 0.45;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH * (1 - i / 4);
      canvas.drawLine(
        Offset(sidePad, y),
        Offset(size.width - sidePad, y),
        gridPaint,
      );
    }

    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final ratio =
          maxValue <= 0 ? 0.0 : (bar.value / maxValue).clamp(0.0, 1.0);
      final barH = math.max(4.0, chartH * ratio);
      final x = sidePad + slotW * i + (slotW - barW) / 2;
      final y = topPad + chartH - barH;

      final rect = Rect.fromLTWH(x, y, barW, barH);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [bar.color, bar.colorDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );

      if (bar.value > 0) {
        final v = bar.value >= 1000
            ? '${(bar.value / 1000).toStringAsFixed(1)}k'
            : bar.value.toStringAsFixed(0);
        final tp = TextPainter(
          text: TextSpan(
            text: v,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas, Offset(x + barW / 2 - tp.width / 2, y - tp.height - 4));
      }

      final ltp = TextPainter(
        text: TextSpan(
          text: bar.label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(
        canvas,
        Offset(x + barW / 2 - ltp.width / 2, size.height - botPad + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars || old.maxValue != maxValue;
}

// ── Donut chart card ──────────────────────────────────────────────────────────

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.categoryMinors, required this.totalMinor});
  final Map<String, int> categoryMinors;
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final total = totalMinor == 0 ? 1 : totalMinor;

    final slices = categoryMinors.entries
        .where((e) => e.value > 0)
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    final pieSlices = slices.asMap().entries.map((e) {
      final color = _kPieColors[e.key % _kPieColors.length];
      return (color: color, fraction: e.value.value / total);
    }).toList(growable: false);

    final centerLabel = totalMinor == 0
        ? '\u20B50'
        : '\u20B5${(totalMinor / 100).toStringAsFixed(0)}';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By Category',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(120, 120),
                    painter: _DonutPainter(slices: pieSlices),
                  ),
                  Text(
                    centerLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (categoryMinors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No expense data',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...slices.take(4).toList().asMap().entries.map((e) {
              final color = _kPieColors[e.key % _kPieColors.length];
              final label = _catLabel(e.value.key);
              final pct = totalMinor == 0
                  ? 0
                  : (e.value.value / totalMinor * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _catLabel(String k) => switch (k) {
        'inventory_purchase' => 'Inventory',
        'transport' => 'Transport',
        'utilities' => 'Utilities',
        'rent' => 'Rent',
        'salary' => 'Salary',
        'tax' => 'Tax',
        _ => 'Other',
      };
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.slices});
  final List<({Color color, double fraction})> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2 - 2;
    const stroke = 18.0;
    final arcR = outerR - stroke / 2;

    canvas.drawCircle(
      center,
      arcR,
      Paint()
        ..color = AppColors.surfaceAlt
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (slices.isEmpty) return;

    final total = slices.fold(0.0, (a, b) => a + b.fraction);
    if (total <= 0) return;

    double angle = -math.pi / 2;
    const gap = 0.04;

    for (final s in slices) {
      if (s.fraction <= 0) continue;
      final sweep = (s.fraction / total) * 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcR),
        angle + gap / 2,
        math.max(0, sweep - gap),
        false,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

// ── Top customers card ────────────────────────────────────────────────────────

class _TopCustomersCard extends StatelessWidget {
  const _TopCustomersCard({required this.receivables});
  final List<LocalReceivableRecord> receivables;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Customers',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'By outstanding debt',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (receivables.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No open debts',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            ...receivables.map((r) {
              final isOverdue = r.dueDateIso != null &&
                  r.dueDateIso!.isNotEmpty &&
                  r.dueDateIso!.compareTo(today) < 0;
              final initials = r.customerName.trim().isEmpty
                  ? '?'
                  : r.customerName
                      .trim()
                      .split(' ')
                      .take(2)
                      .map((w) => w[0])
                      .join()
                      .toUpperCase();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? AppColors.dangerSoft
                            : AppColors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color:
                              isOverdue ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '\u20B5${r.outstandingAmount}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11.5,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppStatusPill(
                      label: isOverdue ? 'Overdue' : 'Open',
                      variant: isOverdue
                          ? AppPillVariant.danger
                          : AppPillVariant.warning,
                      dense: true,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Payment breakdown card ────────────────────────────────────────────────────

class _PaymentBreakdownCard extends StatelessWidget {
  const _PaymentBreakdownCard({required this.breakdown});
  final List<DashboardPaymentBreakdown> breakdown;

  static const _methodColors = {
    'cash': AppColors.success,
    'mobile_money': AppColors.info,
    'bank_transfer': AppColors.forest,
  };

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const _EmptyCard(
        icon: Icons.payments_outlined,
        message: 'No payment data this month.',
      );
    }

    final totalMinor = breakdown.fold(0, (a, b) => a + _toMinor(b.totalAmount));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: breakdown.asMap().entries.map((e) {
          final item = e.value;
          final pct =
              totalMinor == 0 ? 0.0 : _toMinor(item.totalAmount) / totalMinor;
          final methodColor =
              _methodColors[item.paymentMethodLabel] ?? AppColors.muted;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: methodColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.payments_rounded,
                          color: methodColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.paymentMethodDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: AppColors.surfaceAlt,
                                    color: methodColor,
                                    minHeight: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                  color: methodColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _fmtMoney(item.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.ink,
                            letterSpacing: -0.1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.saleCount} sale${item.saleCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (e.key < breakdown.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}

// ── Top items card ────────────────────────────────────────────────────────────

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.items});
  final List<DashboardTopSellingItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(
        icon: Icons.inventory_2_outlined,
        message: 'No sales recorded this month.',
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((e) {
          final rank = e.key + 1;
          final item = e.value;
          final rankColor = rank == 1
              ? AppColors.warning
              : rank == 2
                  ? AppColors.mutedSoft
                  : rank == 3
                      ? AppColors.gold
                      : AppColors.muted;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: rankColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantitySold} sold',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtMoney(item.salesTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink,
                        letterSpacing: -0.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < items.length - 1)
                const Divider(height: 1, color: AppColors.border),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}

// ── Debt aging card ───────────────────────────────────────────────────────────

class _DebtAgingCard extends StatelessWidget {
  const _DebtAgingCard({required this.aging});
  final _DebtAging aging;

  @override
  Widget build(BuildContext context) {
    final total = aging.total == 0 ? 1 : aging.total;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _AgingRow(
            label: 'Overdue',
            count: aging.overdue,
            total: total,
            color: AppColors.danger,
            softBg: AppColors.dangerSoft,
          ),
          const SizedBox(height: 12),
          _AgingRow(
            label: 'Due within 7 days',
            count: aging.dueSoon,
            total: total,
            color: AppColors.warning,
            softBg: AppColors.warningSoft,
          ),
          const SizedBox(height: 12),
          _AgingRow(
            label: 'Current',
            count: aging.current,
            total: total,
            color: AppColors.success,
            softBg: AppColors.successSoft,
          ),
          const SizedBox(height: 12),
          _AgingRow(
            label: 'No due date',
            count: aging.noDue,
            total: total,
            color: AppColors.muted,
            softBg: AppColors.surfaceAlt,
          ),
        ],
      ),
    );
  }
}

class _AgingRow extends StatelessWidget {
  const _AgingRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.softBg,
  });

  final String label;
  final int count, total;
  final Color color, softBg;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: count / total,
              backgroundColor: AppColors.surfaceAlt,
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: softBg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Business summary card ─────────────────────────────────────────────────────

class _BusinessSummaryCard extends StatelessWidget {
  const _BusinessSummaryCard({
    required this.debtOutstanding,
    required this.lowStockCount,
  });

  final String debtOutstanding;
  final int lowStockCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Business Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Outstanding receivables and stock alerts at a glance.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Outstanding Debt',
                  value: _fmtMoney(debtOutstanding),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Low Stock',
                  value: '$lowStockCount item${lowStockCount == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionHeading(
      title: title,
      trailing: subtitle == null
          ? null
          : AppStatusPill(
              label: subtitle!,
              variant: AppPillVariant.brand,
              dense: true,
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.muted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Weekly/monthly data unavailable offline.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsLoading extends StatelessWidget {
  const _ReportsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: const [
        AppSkeleton(height: 42, radius: 14),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: AppSkeletonCard(lines: 2)),
            SizedBox(width: 10),
            Expanded(child: AppSkeletonCard(lines: 2)),
            SizedBox(width: 10),
            Expanded(child: AppSkeletonCard(lines: 2)),
          ],
        ),
        SizedBox(height: 16),
        AppSkeletonCard(lines: 4),
        SizedBox(height: 16),
        AppSkeletonCard(lines: 3),
      ],
    );
  }
}

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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 26,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            AppButton.primary(
              label: 'Retry',
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
