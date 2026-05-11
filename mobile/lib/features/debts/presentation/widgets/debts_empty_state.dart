import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class DebtsEmptyState extends StatelessWidget {
  const DebtsEmptyState({
    super.key,
    this.hasSearch = false,
    this.activeTab = 'all',
  });

  final bool hasSearch;
  final String activeTab;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    final IconData icon;
    final Color iconColor;
    final Color iconBg;

    if (hasSearch) {
      title = 'No debts match your search.';
      message = 'Try a different name or clear the search.';
      icon = Icons.search_off_rounded;
      iconColor = AppColors.muted;
      iconBg = AppColors.surfaceAlt;
    } else if (activeTab == 'overdue') {
      title = 'No overdue debts.';
      message = 'All debts are current — great news!';
      icon = Icons.check_circle_outline_rounded;
      iconColor = AppColors.success;
      iconBg = AppColors.successSoft;
    } else if (activeTab == 'partial') {
      title = 'No partially paid debts.';
      message = 'Partially paid debts will appear here.';
      icon = Icons.timelapse_rounded;
      iconColor = AppColors.warning;
      iconBg = AppColors.warningSoft;
    } else if (activeTab == 'settled') {
      title = 'No settled debts yet.';
      message = 'Settled debts will appear here once paid.';
      icon = Icons.receipt_long_rounded;
      iconColor = AppColors.muted;
      iconBg = AppColors.surfaceAlt;
    } else {
      title = 'No debts recorded yet.';
      message = 'Tap "New Debt" to get started.';
      icon = Icons.add_card_rounded;
      iconColor = AppColors.forest;
      iconBg = AppColors.successSoft;
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
