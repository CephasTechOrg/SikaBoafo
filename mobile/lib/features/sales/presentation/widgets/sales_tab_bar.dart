import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

enum SalesViewTab { newSale, history }

class SalesTabBar extends StatelessWidget {
  const SalesTabBar({
    super.key,
    required this.activeTab,
    required this.onChanged,
  });

  final SalesViewTab activeTab;
  final ValueChanged<SalesViewTab> onChanged;

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
            child: _SalesTabPill(
              label: 'New Sale',
              selected: activeTab == SalesViewTab.newSale,
              onTap: () => onChanged(SalesViewTab.newSale),
            ),
          ),
          Expanded(
            child: _SalesTabPill(
              label: 'History',
              selected: activeTab == SalesViewTab.history,
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
