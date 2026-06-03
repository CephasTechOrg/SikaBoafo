import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import 'reports_utils.dart';

class DonutCard extends StatelessWidget {
  const DonutCard({super.key, required this.categoryMinors, required this.totalMinor});
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
      final color = kPieColors[e.key % kPieColors.length];
      return (color: color, fraction: e.value.value / total);
    }).toList(growable: false);

    final centerAmount = totalMinor == 0
        ? '₵0'
        : '₵${(totalMinor / 100).toStringAsFixed(0)}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      borderColor: const Color(0xFFEEF1F0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: donut 124×124 ──────────────────────────────────────────
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(124, 124),
                  painter: DonutPainter(slices: pieSlices),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9AA3AF),
                        letterSpacing: 0.05 * 10.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerAmount,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // ── Right: legend ────────────────────────────────────────────────
          Expanded(
            child: categoryMinors.isEmpty
                ? const Center(
                    child: Text(
                      'No expense data',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: slices.take(5).toList().asMap().entries.map((e) {
                      final color = kPieColors[e.key % kPieColors.length];
                      final label = _catLabel(e.value.key);
                      final amount = e.value.value / 100.0;
                      final amountStr =
                          '₵${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: e.key < (slices.length > 5 ? 4 : slices.length - 1)
                              ? 9
                              : 0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              amountStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
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

class DonutPainter extends CustomPainter {
  const DonutPainter({required this.slices});
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
  bool shouldRepaint(DonutPainter old) => old.slices != slices;
}
