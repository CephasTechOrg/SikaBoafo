import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import 'payment_breakdown_card.dart';

class BarChartCard extends StatelessWidget {
  const BarChartCard({super.key, 
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
              painter: BarChartPainter(
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
              LegendDot(color: AppColors.forest, label: 'Sales'),
              SizedBox(width: 16),
              LegendDot(color: AppColors.danger, label: 'Expenses'),
              SizedBox(width: 16),
              LegendDot(color: AppColors.warning, label: 'Profit'),
            ],
          ),
        ],
      ),
    );
  }
}

class BarChartPainter extends CustomPainter {
  const BarChartPainter({required this.bars, required this.maxValue});

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
  bool shouldRepaint(BarChartPainter old) =>
      old.bars != bars || old.maxValue != maxValue;
}
