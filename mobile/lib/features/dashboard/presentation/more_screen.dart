import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../expenses/presentation/expenses_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'More',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your business operations and settings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: AppGradients.hero,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0x24FFFFFF),
                    child: Icon(Icons.storefront_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage operations, staff and reports',
                          style: TextStyle(
                            color: AppColors.heroSubtitle,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _SectionLabel(label: 'OPERATIONS'),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.receipt_long_rounded,
              title: 'Expenses',
              subtitle: 'Track costs and daily spending',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.handshake_rounded,
              title: 'Debts',
              subtitle: 'Manage receivables and repayments',
              onTap: () => context.push(AppRoute.debts.path),
            ),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.people_alt_rounded,
              title: 'Customers',
              subtitle: 'Client directory and history',
              onTap: () => context.push(AppRoute.customers.path),
            ),

            const SizedBox(height: 32),

            const _SectionLabel(label: 'BUSINESS MANAGEMENT'),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              subtitle: 'Deep insights into performance',
              onTap: () => context.push(AppRoute.reports.path),
            ),
            const SizedBox(height: 12),
            _MoreTile(
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'Profile, staff, and preferences',
              onTap: () => context.push(AppRoute.settings.path),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Consistent rich icon container (Neutral Grey)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.surfaceAlt,
                      AppColors.border.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                ),
                child: Icon(
                  icon,
                  color: AppColors.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
