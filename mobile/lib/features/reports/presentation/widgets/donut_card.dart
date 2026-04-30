import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/mockup_ui.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../dashboard/data/dashboard_api.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../debts/data/debts_repository.dart';
import '../../../debts/providers/debts_providers.dart';
import '../../../expenses/data/expenses_repository.dart';
import '../../../expenses/providers/expenses_providers.dart';
import 'reports_utils.dart';

class DonutCard extends StatelessWidget {
  const DonutCard({required this.categoryMinors, required this.totalMinor});
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
                    painter: DonutPainter(slices: pieSlices),
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
              final color = kPieColors[e.key % kPieColors.length];
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
