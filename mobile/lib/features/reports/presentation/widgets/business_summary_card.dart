import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'reports_utils.dart';

class BusinessSummaryCard extends StatelessWidget {
  const BusinessSummaryCard({super.key, 
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
                child: SummaryStat(
                  label: 'Outstanding Debt',
                  value: fmtMoney(debtOutstanding),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryStat(
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

class SummaryStat extends StatelessWidget {
  const SummaryStat({super.key, required this.label, required this.value});
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
