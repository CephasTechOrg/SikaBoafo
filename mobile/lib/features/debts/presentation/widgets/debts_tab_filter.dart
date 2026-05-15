import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

enum DebtsFilterTab { all, open, overdue, settled }

extension DebtsFilterTabX on DebtsFilterTab {
  String get label {
    switch (this) {
      case DebtsFilterTab.all:
        return 'All';
      case DebtsFilterTab.open:
        return 'Open';
      case DebtsFilterTab.overdue:
        return 'Overdue';
      case DebtsFilterTab.settled:
        return 'Settled';
    }
  }
}

/// Horizontally-arranged filter pills (`index (2).html` `.filter-tabs`).
///
/// Active tab fills with `green-deep` and shows white text + translucent
/// badge. Inactive tabs are bordered surface chips with green-pale badges.
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
              badge: counts[tab],
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
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: DebtsUiTokens.tabSwitchAnimation,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? DebtsUi.greenDeep : DebtsUi.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DebtsUi.greenDeep : DebtsUi.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : DebtsUi.textSecondary,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : DebtsUi.greenLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : DebtsUi.greenMid,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
