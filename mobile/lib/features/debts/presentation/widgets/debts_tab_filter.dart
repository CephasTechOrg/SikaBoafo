import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DebtsUiTokens.pillRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          for (final tab in DebtsFilterTab.values)
            Expanded(
              child: _Pill(
                label: tab.label,
                badge: counts[tab],
                selected: activeTab == tab,
                onTap: () => onChanged(tab),
              ),
            ),
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
    final pillColor = selected ? const Color(0xFF0C3A24) : Colors.transparent;
    final textColor = selected ? Colors.white : AppColors.inkSoft;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: DebtsUiTokens.tabSwitchAnimation,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(DebtsUiTokens.pillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.inkSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
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
