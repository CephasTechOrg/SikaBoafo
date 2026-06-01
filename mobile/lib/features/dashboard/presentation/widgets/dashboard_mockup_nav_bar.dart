import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'dashboard_mockup_ui.dart';

/// Mockup `.tabbar` — replaces Material [NavigationBar] on the dashboard shell.
class DashboardMockupNavBar extends StatelessWidget {
  const DashboardMockupNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Dashboard',
    ),
    _NavItem(
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale_rounded,
      label: 'Sales',
    ),
    _NavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: 'Inventory',
    ),
    _NavItem(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: DashboardMockup.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == selectedIndex;
            final color =
                selected ? DashboardMockup.green900 : DashboardMockup.ink3;
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
                          selected ? item.selectedIcon : item.icon,
                          size: 23,
                          color: color,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.01,
                            color: color,
                          ),
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
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
