import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _QuickTile(
            icon: Icons.add_rounded,
            label: 'New Sale',
            backgroundColor: const Color(0xFF155236),
            accentColor: const Color(0xFF1B6E4C),
            foregroundColor: Colors.white,
            iconColor: Colors.white,
            iconBackgroundColor: Colors.white.withValues(alpha: 0.15),
            borderColor: Colors.transparent,
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _QuickTile(
            icon: Icons.payments_outlined,
            label: 'Debts',
            backgroundColor: AppColors.surface,
            accentColor: const Color(0xFFFDFEFE),
            foregroundColor: AppColors.ink,
            iconColor: AppColors.forest,
            iconBackgroundColor: AppColors.successSoft,
            borderColor: AppColors.border,
            onTap: () => context.push(AppRoute.debts.path),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _QuickTile(
            icon: Icons.inventory_2_outlined,
            label: 'Restock',
            backgroundColor: AppColors.surface,
            accentColor: const Color(0xFFFDFEFE),
            foregroundColor: AppColors.ink,
            iconColor: AppColors.forest,
            iconBackgroundColor: AppColors.successSoft,
            borderColor: AppColors.border,
            onTap: () => onNavigate(2),
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.accentColor,
    required this.foregroundColor,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color accentColor;
  final Color foregroundColor;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: backgroundColor == AppColors.surface
            ? const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: iconColor, size: 15),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
