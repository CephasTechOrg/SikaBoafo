import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

enum DebtsFilterTab { all, unpaid, overdue, paid }

extension DebtsFilterTabX on DebtsFilterTab {
  String get label {
    switch (this) {
      case DebtsFilterTab.all:
        return 'All';
      case DebtsFilterTab.unpaid:
        return 'Unpaid';
      case DebtsFilterTab.overdue:
        return 'Overdue';
      case DebtsFilterTab.paid:
        return 'Paid';
    }
  }
}

/// Horizontally-arranged filter pills (`debts UI mockup` `.filter-tabs`).
///
/// Active tab fills with `green-900` (#073B2A) and shows white text.
/// Inactive tabs are white bordered chips with #6B7280 text.
/// No count badges — mockup has none.
class DebtsTabFilter extends StatelessWidget {
  const DebtsTabFilter({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.counts = const {},
  });

  final DebtsFilterTab activeTab;
  final ValueChanged<DebtsFilterTab> onChanged;
  final Map<DebtsFilterTab, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in DebtsFilterTab.values) ...[
            _Pill(
              label: tab.label,
              selected: activeTab == tab,
              onTap: () => onChanged(tab),
            ),
            if (tab != DebtsFilterTab.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: DebtsUiTokens.tabSwitchAnimation,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF073B2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF073B2A) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
