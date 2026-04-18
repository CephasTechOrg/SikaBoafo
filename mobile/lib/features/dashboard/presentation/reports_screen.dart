import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/theme/app_theme.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/data/expenses_repository.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF08302A), Color(0xFF1A6655)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _kPieColors = [
  Color(0xFF1A6655),
  Color(0xFF2D6BC4),
  Color(0xFFD97706),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFF558B2F),
  Color(0xFF9E9E9E),
];

// ── Helper ────────────────────────────────────────────────────────────────────

int _toMinor(String v) {
  final raw = v.trim();
  final m = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (m == null) return 0;
  final p = raw.split('.');
  final dec = p.length == 2 ? p[1].padRight(2, '0') : '00';
  return int.parse(p[0]) * 100 + int.parse(dec);
}

String _fmtMoney(String v) => 'GHS $v';

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

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
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

    // Compute KPI values based on selected period
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

    // Expense by category — O(n) grouping
    final Map<String, int> catMinors = {};
    for (final e in expenses) {
      catMinors[e.category] =
          (catMinors[e.category] ?? 0) + _toMinor(e.amount);
    }
    final catTotal = catMinors.values.fold(0, (a, b) => a + b);

    // Top 3 open receivables by outstanding amount
    final openRecs = receivables
        .where((r) => r.status == 'open')
        .toList(growable: false)
      ..sort((a, b) => _toMinor(b.outstandingAmount)
          .compareTo(_toMinor(a.outstandingAmount)));

    return Scaffold(
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: _kHeaderGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reports',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            summary != null
                                ? 'Today in ${summary.timezone}'
                                : 'Performance overview',
                            style: const TextStyle(
                              color: Color(0xFFB2D8CE),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _refresh(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F7F9),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: summaryAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(
                    message: humanizeDashboardError(e),
                    onRetry: _refresh,
                  ),
                  data: (_) => RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      children: [
                        // Period tabs
                        _PeriodTabs(
                          selected: _periodIndex,
                          onSelected: (i) =>
                              setState(() => _periodIndex = i),
                        ),
                        const SizedBox(height: 16),

                        // KPI row
                        _KpiRow(
                          sales: salesStr,
                          expenses: expensesStr,
                          profit: profitStr,
                        ),
                        const SizedBox(height: 16),

                        // Bar chart
                        _BarChartCard(
                          sales: double.tryParse(salesStr) ?? 0,
                          expenses: double.tryParse(expensesStr) ?? 0,
                          profit: double.tryParse(profitStr) ?? 0,
                          period: _periods[_periodIndex],
                        ),
                        const SizedBox(height: 16),

                        // Two-column: pie chart + top customers
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
                                    receivables: openRecs.take(4).toList()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment breakdown
                        const _SectionHeader(
                          title: 'Payment Breakdown',
                          subtitle: 'Monthly',
                        ),
                        const SizedBox(height: 10),
                        insightsAsync.when(
                          loading: () => const _LoadingCard(),
                          error: (_, __) => const _OfflineCard(),
                          data: (ins) => _PaymentBreakdownCard(
                              breakdown: ins.monthlyPaymentBreakdown),
                        ),
                        const SizedBox(height: 16),

                        // Top items
                        const _SectionHeader(
                          title: 'Top Selling Items',
                          subtitle: 'Monthly',
                        ),
                        const SizedBox(height: 10),
                        insightsAsync.when(
                          loading: () => const _LoadingCard(),
                          error: (_, __) => const _OfflineCard(),
                          data: (ins) => _TopItemsCard(
                              items: ins.monthlyTopSellingItems),
                        ),
                        const SizedBox(height: 16),

                        // Debt aging
                        const _SectionHeader(title: 'Debt Aging'),
                        const SizedBox(height: 10),
                        _DebtAgingCard(aging: aging),
                        const SizedBox(height: 16),

                        // Business summary
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
          ),
        ],
      ),
    );
  }

  void _refresh() {
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardInsightsProvider);
  }
}

// ── Period tabs ───────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs(
      {required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['Today', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : AppColors.muted,
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
  const _KpiRow(
      {required this.sales,
      required this.expenses,
      required this.profit});
  final String sales, expenses, profit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'Sales',
            value: sales,
            icon: Icons.shopping_bag_outlined,
            iconBg: const Color(0xFFE8F5E9),
            iconFg: const Color(0xFF2E7D32),
            valueColor: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Expenses',
            value: expenses,
            icon: Icons.receipt_long_outlined,
            iconBg: const Color(0xFFFFEBEE),
            iconFg: const Color(0xFFC62828),
            valueColor: const Color(0xFFC62828),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiCard(
            label: 'Profit',
            value: profit,
            icon: Icons.trending_up_rounded,
            iconBg: const Color(0xFFFFF3E0),
            iconFg: const Color(0xFFD97706),
            valueColor: const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.valueColor,
  });

  final String label, value;
  final IconData icon;
  final Color iconBg, iconFg, valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconFg, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            'GHS $value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: valueColor,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
    final peak = math.max(1.0,
        [sales, expenses, profit].fold(0.0, (a, b) => math.max(a, b)));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales vs Expenses',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  period,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _BarChartPainter(
                bars: [
                  (
                    label: 'Sales',
                    value: sales,
                    color: const Color(0xFF2E7D32),
                    colorDark: const Color(0xFF1A6655),
                  ),
                  (
                    label: 'Expenses',
                    value: expenses,
                    color: const Color(0xFFE53935),
                    colorDark: const Color(0xFFC62828),
                  ),
                  (
                    label: 'Profit',
                    value: profit,
                    color: const Color(0xFFFFA000),
                    colorDark: const Color(0xFFD97706),
                  ),
                ],
                maxValue: peak,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Color(0xFF2E7D32), label: 'Sales'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFFE53935), label: 'Expenses'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFFFFA000), label: 'Profit'),
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
    const topPad = 20.0;
    const botPad = 28.0;
    const sidePad = 12.0;
    final chartH = size.height - topPad - botPad;
    final chartW = size.width - sidePad * 2;
    final slotW = chartW / bars.length;
    final barW = slotW * 0.5;

    // Grid lines (4)
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F1F3)
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
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
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

      // Value label
      if (bar.value > 0) {
        final v = bar.value >= 1000
            ? '${(bar.value / 1000).toStringAsFixed(1)}k'
            : bar.value.toStringAsFixed(0);
        final tp = TextPainter(
          text: TextSpan(
            text: v,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(
                x + barW / 2 - tp.width / 2, y - tp.height - 3));
      }

      // Category label
      final ltp = TextPainter(
        text: TextSpan(
          text: bar.label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(
        canvas,
        Offset(
          x + barW / 2 - ltp.width / 2,
          size.height - botPad + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars || old.maxValue != maxValue;
}

// ── Donut chart card ──────────────────────────────────────────────────────────

class _DonutCard extends StatelessWidget {
  const _DonutCard(
      {required this.categoryMinors, required this.totalMinor});
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
        ? 'GHS 0'
        : 'GHS ${(totalMinor / 100).toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By Category',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(110, 110),
                    painter: _DonutPainter(slices: pieSlices),
                  ),
                  Text(
                    centerLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          ...slices.take(4).toList().asMap().entries.map((e) {
            final color = _kPieColors[e.key % _kPieColors.length];
            final label = _catLabel(e.value.key);
            final pct = totalMinor == 0
                ? 0
                : (e.value.value / totalMinor * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (categoryMinors.isEmpty)
            const Text(
              'No expense data',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
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

    // Background track
    canvas.drawCircle(
      center,
      arcR,
      Paint()
        ..color = const Color(0xFFF0F1F3)
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Customers',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'By debt',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (receivables.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No open debts',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 12),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: isOverdue
                              ? const Color(0xFFC62828)
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'GHS ${r.outstandingAmount}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : 'Open',
                        style: TextStyle(
                          color: isOverdue
                              ? const Color(0xFFC62828)
                              : const Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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
}

// ── Payment breakdown card ────────────────────────────────────────────────────

class _PaymentBreakdownCard extends StatelessWidget {
  const _PaymentBreakdownCard({required this.breakdown});
  final List<DashboardPaymentBreakdown> breakdown;

  static const _methodColors = {
    'cash': (bg: Color(0xFFE8F5E9), fg: Color(0xFF2E7D32)),
    'mobile_money': (bg: Color(0xFFE8F1FB), fg: Color(0xFF2D6BC4)),
    'bank_transfer': (bg: Color(0xFFF3E5F5), fg: Color(0xFF6A1B9A)),
  };

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const _EmptyCard(
        icon: Icons.payments_outlined,
        message: 'No payment data this month.',
      );
    }

    final totalMinor =
        breakdown.fold(0, (a, b) => a + _toMinor(b.totalAmount));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: breakdown.asMap().entries.map((e) {
          final item = e.value;
          final pct = totalMinor == 0
              ? 0.0
              : _toMinor(item.totalAmount) / totalMinor;
          final colors = _methodColors[item.paymentMethodLabel] ??
              (
                bg: const Color(0xFFF5F5F5),
                fg: AppColors.muted,
              );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.payments_rounded,
                          color: colors.fg, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.paymentMethodDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor:
                                        const Color(0xFFF0F1F3),
                                    color: colors.fg,
                                    minHeight: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                  color: colors.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '${item.saleCount} sale${item.saleCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (e.key < breakdown.length - 1)
                const Divider(height: 1, color: Color(0xFFF0F1F3)),
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

  static const _rankColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(
        icon: Icons.inventory_2_outlined,
        message: 'No sales recorded this month.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final rank = e.key + 1;
          final item = e.value;
          final rankColor = rank <= 3
              ? _rankColors[rank - 1]
              : AppColors.muted;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: rankColor == AppColors.muted
                              ? AppColors.muted
                              : rankColor.withValues(alpha: 1),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.quantitySold} sold',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _fmtMoney(item.salesTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < items.length - 1)
                const Divider(height: 1, color: Color(0xFFF0F1F3)),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}

// ── Debt aging card ────────────────────────────────────────────────────────────

class _DebtAgingCard extends StatelessWidget {
  const _DebtAgingCard({required this.aging});
  final _DebtAging aging;

  @override
  Widget build(BuildContext context) {
    final total = aging.total == 0 ? 1 : aging.total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _AgingRow(
            label: 'Overdue',
            count: aging.overdue,
            total: total,
            color: const Color(0xFFC62828),
            bgColor: const Color(0xFFFFEBEE),
          ),
          const SizedBox(height: 10),
          _AgingRow(
            label: 'Due within 7 days',
            count: aging.dueSoon,
            total: total,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFF3E0),
          ),
          const SizedBox(height: 10),
          _AgingRow(
            label: 'Current',
            count: aging.current,
            total: total,
            color: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFE8F5E9),
          ),
          const SizedBox(height: 10),
          _AgingRow(
            label: 'No due date',
            count: aging.noDue,
            total: total,
            color: AppColors.muted,
            bgColor: const Color(0xFFF5F5F5),
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
    required this.bgColor,
  });

  final String label;
  final int count, total;
  final Color color, bgColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: count / total,
              backgroundColor: const Color(0xFFF0F1F3),
              color: color,
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3028), Color(0xFF1E7060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A0A3028),
              blurRadius: 16,
              offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Business Summary',
                  style: TextStyle(
                    color: Color(0xFF6DE4C4),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You've made 0 sales today. Keep going! 🔥",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryChip(
                        label: 'Debt', value: _fmtMoney(debtOutstanding)),
                    const SizedBox(width: 8),
                    _SummaryChip(
                        label: 'Low Stock', value: '$lowStockCount items'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Color(0xFFB2D8CE), fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
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
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.forest,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
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
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 11)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppColors.muted, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Weekly/monthly data unavailable offline.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
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
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
