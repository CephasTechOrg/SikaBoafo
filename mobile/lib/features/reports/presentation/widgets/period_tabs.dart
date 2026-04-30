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

class PeriodTabs extends StatelessWidget {
  const PeriodTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['Today', 'This Week', 'This Month'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.forest : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.muted,
                    letterSpacing: 0.1,
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
