import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../expenses/presentation/expenses_screen.dart';

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
          _MoreTile(
            icon: Icons.receipt_long_rounded,
            title: 'Expenses',
            subtitle: 'Track costs and spending',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExpensesScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.handshake_rounded,
            title: 'Debts',
            subtitle: 'Receivables and repayments',
            onTap: () => context.push(AppRoute.debts.path),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.people_alt_rounded,
            title: 'Customers',
            subtitle: 'Customer list and details',
            onTap: () => context.push(AppRoute.customers.path),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.bar_chart_rounded,
            title: 'Reports',
            subtitle: 'Insights across sales and stock',
            onTap: () => context.push(AppRoute.reports.path),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Business profile, staff and payments',
            onTap: () => context.push(AppRoute.settings.path),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.ink, size: 22),
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
