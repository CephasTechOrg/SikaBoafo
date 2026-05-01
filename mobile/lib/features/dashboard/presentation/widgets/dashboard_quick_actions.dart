import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return PremiumReveal(
      child: Row(
        children: [
          Expanded(
            child: QuickTile(
              icon: Icons.add_rounded,
              label: 'New Sale',
              backgroundColor: const Color(0xFF155236),
              accentColor: const Color(0xFF1B6E4C),
              foregroundColor: Colors.white,
              iconColor: Colors.white,
              iconBackgroundColor: Colors.white.withValues(alpha: 0.12),
              borderColor: Colors.transparent,
              onTap: () => onNavigate(1),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: QuickTile(
              icon: Icons.payments_outlined,
              label: 'Collect Debt',
              backgroundColor: AppColors.surface,
              accentColor: const Color(0xFFFDFEFE),
              foregroundColor: AppColors.ink,
              iconColor: AppColors.forest,
              iconBackgroundColor: AppColors.successSoft,
              borderColor: AppColors.border,
              onTap: () => context.push(AppRoute.debts.path),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: QuickTile(
              icon: Icons.inventory_2_outlined,
              label: 'Add Stock',
              backgroundColor: AppColors.surface,
              accentColor: const Color(0xFFFFFEFB),
              foregroundColor: AppColors.ink,
              iconColor: const Color(0xFFC58C02),
              iconBackgroundColor: AppColors.warningSoft,
              borderColor: AppColors.border,
              onTap: () => onNavigate(2),
            ),
          ),
        ],
      ),
    );
  }
}

class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: backgroundColor == AppColors.surface ? kCardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
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
