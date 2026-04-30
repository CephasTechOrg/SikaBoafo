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

class PaymentBreakdownCard extends StatelessWidget {
  const PaymentBreakdownCard({required this.breakdown});
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

class LegendDot extends StatelessWidget {
  const LegendDot({required this.color, required this.label});
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
