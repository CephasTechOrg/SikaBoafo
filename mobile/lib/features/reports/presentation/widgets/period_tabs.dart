import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class PeriodTabs extends StatelessWidget {
  const PeriodTabs({super.key, required this.selected, required this.onSelected});
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
