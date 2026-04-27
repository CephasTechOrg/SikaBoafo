import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import 'reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MockupScreenScaffold(
      title: 'More',
      subtitle: 'Quick access to the rest of your workspace',
      bottomNavSafeArea: true,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const _SectionLabel('Operations'),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.receipt_long_rounded,
            iconBg: AppColors.warningSoft,
            iconColor: AppColors.warning,
            title: 'Expenses',
            subtitle: 'Track costs and spending',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.handshake_rounded,
            iconBg: AppColors.successSoft,
            iconColor: AppColors.forest,
            title: 'Debts',
            subtitle: 'Receivables and repayments',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DebtsScreen(onNavigate: (_) {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.people_alt_rounded,
            iconBg: AppColors.infoSoft,
            iconColor: AppColors.navy,
            title: 'Customers',
            subtitle: 'Customer list and details',
            onTap: () => context.push(AppRoute.customers.path),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Insights'),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.bar_chart_rounded,
            iconBg: AppColors.surfaceAlt,
            iconColor: AppColors.navy,
            title: 'Reports',
            subtitle: 'Insights across sales and stock',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Account'),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.settings_rounded,
            iconBg: AppColors.surfaceAlt,
            iconColor: AppColors.inkSoft,
            title: 'Settings',
            subtitle: 'Business profile, staff and payments',
            onTap: () => context.push(AppRoute.settings.path),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
