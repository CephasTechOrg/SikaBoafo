import 'package:flutter/material.dart';

enum ExpensesViewTab { log, history }

/// Two-pill segmented control matching the mockup's `Segmented` chip style.
///
/// Active pill: #073B2A bg, white text.
/// Inactive pill: white bg, #6B7280 text, #E5E7EB border.
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
    return Row(
      children: [
        Expanded(
          child: _TabPill(
            label: 'Log expense',
            selected: activeTab == ExpensesViewTab.log,
            onTap: () => onChanged(ExpensesViewTab.log),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabPill(
            label: 'History',
            selected: activeTab == ExpensesViewTab.history,
            onTap: () => onChanged(ExpensesViewTab.history),
          ),
        ),
      ],
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF073B2A) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE5E7EB),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
