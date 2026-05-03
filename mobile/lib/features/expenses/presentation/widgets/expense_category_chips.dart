import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../expenses_category_meta.dart';

class ExpenseCategoryChips extends StatelessWidget {
  const ExpenseCategoryChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kExpenseCategories.entries.map((entry) {
        final isSel = entry.key == selected;
        final meta = entry.value;
        return GestureDetector(
          onTap: () => onChanged(entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isSel
                  ? meta.color.withValues(alpha: 0.14)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSel ? meta.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meta.icon,
                  color: isSel ? meta.color : AppColors.muted,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  meta.label,
                  style: TextStyle(
                    color: isSel ? meta.color : AppColors.muted,
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
