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

class TopItemsCard extends StatelessWidget {
  const TopItemsCard({required this.items});
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
