import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_components.dart';
import '../../../dashboard/data/dashboard_api.dart';

/// Sales-vs-Expenses line / area chart.
///
/// - Sales  → green filled area
/// - Expenses → muted red line
///
/// X-axis label density adapts to the period so the chart never feels crowded:
///   today   → show every 6th label (12AM 6AM 12PM 6PM)
///   week    → show all 7 labels (Mon–Sun)
///   month   → show every 5th label
class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.points,
    required this.period,
  });

  final List<DashboardTrendPoint> points;
  final String period;

  // How often to show an x-axis label
  int get _labelStep {
    if (period == 'today') return 6;
    if (period == 'month') return 5;
    return 1; // week: show all
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        radius: 20,
        borderColor: const Color(0xFFEEF1F0),
        child: const SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'No data for this period',
              style: TextStyle(fontSize: 13, color: Color(0xFF9AA3AF)),
            ),
          ),
        ),
      );
    }

    final maxY = _computeMaxY();
    final salesSpots = _toSpots((p) => p.sales);
    final expensesSpots = _toSpots((p) => p.expenses);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 18),
      radius: 20,
      borderColor: const Color(0xFFEEF1F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sales vs Expenses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.18,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F7A4A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Chart ────────────────────────────────────────────────────────
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFEEF1F0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: _labelStep.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (idx % _labelStep != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            points[idx].label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9AA3AF),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.white,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isSales = spot.barIndex == 0;
                      return LineTooltipItem(
                        '₵${spot.y.toStringAsFixed(2)}',
                        TextStyle(
                          color: isSales
                              ? const Color(0xFF0F7A4A)
                              : const Color(0xFFC66A57),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  // Sales — green area
                  LineChartBarData(
                    spots: salesSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF0F7A4A),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F7A4A).withValues(alpha: 0.18),
                          const Color(0xFF0F7A4A).withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Expenses — muted red line only
                  LineChartBarData(
                    spots: expensesSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFC66A57),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                    dashArray: [4, 3],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Legend ───────────────────────────────────────────────────────
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Color(0xFF0F7A4A), label: 'Sales'),
              SizedBox(width: 20),
              _LegendItem(color: Color(0xFFC66A57), label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  String get _periodLabel {
    if (period == 'today') return 'Today';
    if (period == 'week') return 'This Week';
    return 'This Month';
  }

  List<FlSpot> _toSpots(double Function(DashboardTrendPoint) value) {
    return points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), value(e.value));
    }).toList(growable: false);
  }

  double _computeMaxY() {
    double max = 1;
    for (final p in points) {
      if (p.sales > max) max = p.sales;
      if (p.expenses > max) max = p.expenses;
    }
    // Round up to a clean ceiling so grid lines land on round numbers
    final step = max / 4;
    final magnitude = step == 0
        ? 1.0
        : pow10(step.toString().split('.').first.length - 1);
    final cleanStep = ((step / magnitude).ceil() * magnitude);
    return cleanStep * 5;
  }

  double pow10(int exp) {
    double result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
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
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA3AF),
          ),
        ),
      ],
    );
  }
}
