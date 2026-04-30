import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../debts/data/debts_repository.dart';

class TopCustomersCard extends StatelessWidget {
  const TopCustomersCard({super.key, required this.receivables});
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
