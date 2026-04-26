import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../dashboard/presentation/business_settings_sheet.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionServiceProvider).signOut();
    if (!context.mounted) return;
    context.go(AppRoute.auth.path);
  }

  void _openBusinessSettings(BuildContext context, WidgetRef ref) {
    final mc = ref.read(merchantContextProvider).valueOrNull;
    if (mc == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BusinessSettingsSheet(initialContext: mc),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final businessName = ctxAsync.valueOrNull?.businessName;
    final subtitle = businessName ?? 'Manage your account';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            PremiumPageHeader(
              leading: PremiumHeaderButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
                tooltip: 'Back',
              ),
              title: 'Settings',
              subtitle: subtitle,
            ),
            Expanded(
              child: PremiumSurface(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  children: [
                    _SettingsTile(
                      icon: Icons.business_outlined,
                      label: 'Business Profile',
                      caption: 'Edit name, type and store details',
                      onTap: () => _openBusinessSettings(context, ref),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.group_outlined,
                      label: 'Staff & Team',
                      caption: 'Invite teammates and manage access',
                      onTap: () => context.push(AppRoute.staff.path),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.payment_outlined,
                      label: 'Paystack Payments',
                      caption: 'Connect your Paystack account',
                      onTap: () => context.push(AppRoute.paystack.path),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      caption: null,
                      isDestructive: true,
                      onTap: () => _signOut(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final iconBg = isDestructive ? AppColors.dangerSoft : AppColors.infoSoft;
    final iconColor = isDestructive ? AppColors.danger : AppColors.navy;
    final labelColor = isDestructive ? AppColors.danger : AppColors.ink;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isDestructive)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
        ],
      ),
    );
  }
}
