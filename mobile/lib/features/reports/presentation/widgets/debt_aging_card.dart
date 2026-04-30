import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import 'reports_utils.dart';

class DebtAgingCard extends StatelessWidget {
  const DebtAgingCard({super.key, required this.aging});
  final DebtAging aging;

  @override
  Widget build(BuildContext context) {
    final total = aging.total == 0 ? 1 : aging.total;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AgingRow(
            label: 'Overdue',
            count: aging.overdue,
            total: total,
            color: AppColors.danger,
            softBg: AppColors.dangerSoft,
          ),
          const SizedBox(height: 12),
          AgingRow(
            label: 'Due within 7 days',
            count: aging.dueSoon,
            total: total,
            color: AppColors.warning,
            softBg: AppColors.warningSoft,
          ),
          const SizedBox(height: 12),
          AgingRow(
            label: 'Current',
            count: aging.current,
            total: total,
            color: AppColors.success,
            softBg: AppColors.successSoft,
          ),
          const SizedBox(height: 12),
          AgingRow(
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

class AgingRow extends StatelessWidget {
  const AgingRow({super.key, 
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
