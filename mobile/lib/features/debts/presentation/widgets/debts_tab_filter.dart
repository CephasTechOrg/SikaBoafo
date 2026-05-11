import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class DebtsTabFilter extends StatelessWidget {
  const DebtsTabFilter({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  final String activeTab;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TabPill(label: 'All', tab: 'all', activeTab: activeTab, onTap: onTabChanged),
          const SizedBox(width: 8),
          _TabPill(label: 'Overdue', tab: 'overdue', activeTab: activeTab, onTap: onTabChanged),
          const SizedBox(width: 8),
          _TabPill(label: 'Partial', tab: 'partial', activeTab: activeTab, onTap: onTabChanged),
          const SizedBox(width: 8),
          _TabPill(label: 'Settled', tab: 'settled', activeTab: activeTab, onTap: onTabChanged),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.tab,
    required this.activeTab,
    required this.onTap,
  });

  final String label;
  final String tab;
  final String activeTab;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = tab == activeTab;
    return GestureDetector(
      onTap: () => onTap(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.forest : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.forest : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
