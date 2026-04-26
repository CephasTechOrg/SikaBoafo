import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../expenses/presentation/expenses_screen.dart';
import 'reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          children: [
            Text(
              'More',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick access to the rest of your workspace.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
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
              icon: Icons.group_rounded,
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
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              subtitle: 'Insights across sales and stock',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
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
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Business profile, staff and payments',
              onTap: () => context.push(AppRoute.settings.path),
            ),
          ],
        ),
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      elevated: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.navy, size: 22),
          ),
          const SizedBox(width: 12),
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
    );
  }
}

