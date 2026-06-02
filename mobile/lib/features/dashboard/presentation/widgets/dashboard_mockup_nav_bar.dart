import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'dashboard_mockup_ui.dart';

/// Mockup `.tabbar` — 4-tab bottom navigation bar.
class DashboardMockupNavBar extends StatelessWidget {
  const DashboardMockupNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_NavItem>[
    _NavItem(icon: LucideIcons.home,         label: 'Dashboard'),
    _NavItem(icon: LucideIcons.shoppingBag,  label: 'Sales'),
    _NavItem(icon: LucideIcons.package,      label: 'Inventory'),
    _NavItem(icon: LucideIcons.layoutGrid,   label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DashboardMockup.card,
        border: Border(top: BorderSide(color: DashboardMockup.line)),
        boxShadow: DashboardMockup.navShadow,
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item     = _items[i];
            final selected = i == selectedIndex;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? DashboardMockup.green900
                              : DashboardMockup.ink3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: DSText.navLabel(selected: selected),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
