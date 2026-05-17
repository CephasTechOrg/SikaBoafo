import 'package:flutter/material.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';

enum CustomersFilterTab { all, withBalance, cleared }

extension CustomersFilterTabX on CustomersFilterTab {
  String get label {
    switch (this) {
      case CustomersFilterTab.all:
        return 'All';
      case CustomersFilterTab.withBalance:
        return 'With balance';
      case CustomersFilterTab.cleared:
        return 'Cleared';
    }
  }
}

class CustomersTabFilter extends StatelessWidget {
  const CustomersTabFilter({
    super.key,
    required this.activeTab,
    required this.onChanged,
    this.counts = const {},
  });

  final CustomersFilterTab activeTab;
  final ValueChanged<CustomersFilterTab> onChanged;
  final Map<CustomersFilterTab, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in CustomersFilterTab.values) ...[
            _Pill(
              label: tab.label,
              badge: counts[tab],
              selected: activeTab == tab,
              onTap: () => onChanged(tab),
            ),
            if (tab != CustomersFilterTab.values.last) const SizedBox(width: 8),
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
          color: selected ? DebtsUi.tabSelectedFill : DebtsUi.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? DebtsUi.tabSelectedFill : DebtsUi.borderNeutral,
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
                fontWeight: FontWeight.w700,
                color:
                    selected ? DebtsUi.tabSelectedFg : DebtsUi.textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : DebtsUi.avatarNeutralBg,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? null
                      : Border.all(color: DebtsUi.avatarNeutralBorder),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? DebtsUi.tabSelectedFg
                        : DebtsUi.textSecondary,
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
