import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to enter your phone number and PIN again to log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    await ref.read(sessionServiceProvider).signOut();
    if (!context.mounted) return;
    context.go(AppRoute.auth.path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final businessName = ctxAsync.valueOrNull?.businessName;
    final subtitle = businessName ?? 'Manage your account';

    return MockupScreenScaffold(
      title: 'Settings',
      subtitle: subtitle,
      onBack: () => context.pop(),
      bottomNavSafeArea: true,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          const _SectionLabel('Business'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.business_outlined,
            iconBg: AppColors.infoSoft,
            iconColor: AppColors.navy,
            label: 'Business Profile',
            caption: 'Edit name, type and store details',
            onTap: () => context.push(AppRoute.businessProfile.path),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.group_outlined,
            iconBg: AppColors.successSoft,
            iconColor: AppColors.forest,
            label: 'Staff & Team',
            caption: 'Invite teammates and manage access',
            onTap: () => context.push(AppRoute.staff.path),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.payment_outlined,
            iconBg: AppColors.warningSoft,
            iconColor: AppColors.warning,
            label: 'Paystack Payments',
            caption: 'Connect your Paystack account',
            onTap: () => context.push(AppRoute.paystack.path),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Account'),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconBg: AppColors.dangerSoft,
            iconColor: AppColors.danger,
            label: 'Sign Out',
            caption: 'End this session on this device',
            isDestructive: true,
            onTap: () => _signOut(context, ref),
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.caption,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? caption;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDestructive ? AppColors.danger : AppColors.ink;
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
                      label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        caption!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
