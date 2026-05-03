import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

enum ExpensesViewTab { log, history }

class ExpensesTabBar extends StatelessWidget {
  const ExpensesTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final ExpensesViewTab activeTab;
  final ValueChanged<ExpensesViewTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabPill(
              label: 'Log expense',
              selected: activeTab == ExpensesViewTab.log,
              onTap: () => onChanged(ExpensesViewTab.log),
            ),
          ),
          Expanded(
            child: _TabPill(
              label: 'History',
              selected: activeTab == ExpensesViewTab.history,
              onTap: () => onChanged(ExpensesViewTab.history),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
