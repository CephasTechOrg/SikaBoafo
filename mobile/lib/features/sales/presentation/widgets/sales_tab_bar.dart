import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

enum SalesViewTab { newSale, history }

class SalesTabBar extends StatelessWidget {
  const SalesTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.darkMode = false,
  });

  final SalesViewTab activeTab;
  final ValueChanged<SalesViewTab> onChanged;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: darkMode ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: darkMode
              ? Colors.white.withValues(alpha: 0.18)
              : AppColors.border,
        ),
        boxShadow: darkMode ? null : AppShadows.subtle,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SalesTabPill(
              label: 'New Sale',
              selected: activeTab == SalesViewTab.newSale,
              darkMode: darkMode,
              onTap: () => onChanged(SalesViewTab.newSale),
            ),
          ),
          Expanded(
            child: _SalesTabPill(
              label: 'History',
              selected: activeTab == SalesViewTab.history,
              darkMode: darkMode,
              onTap: () => onChanged(SalesViewTab.history),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTabPill extends StatelessWidget {
  const _SalesTabPill({
    required this.label,
    required this.selected,
    required this.darkMode,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool darkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color pillColor;
    final Color textColor;
    if (darkMode) {
      pillColor = selected ? Colors.white : Colors.transparent;
      textColor = selected ? AppColors.forest : Colors.white.withValues(alpha: 0.78);
    } else {
      pillColor = selected ? AppColors.forest : Colors.transparent;
      textColor = selected ? Colors.white : AppColors.inkSoft;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
