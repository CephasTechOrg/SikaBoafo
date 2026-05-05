import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/streak_hero_header.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/biometric_pref_provider.dart';
import '../providers/notification_prefs_provider.dart';
import '../../../core/services/biometric_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static final _biometricAvailabilityProvider =
      FutureProvider<BiometricAvailability>((ref) async {
    return ref.watch(biometricServiceProvider).availability();
  });

  static String _biometricCaption(
    BiometricAvailability? availability,
    AsyncValue<bool> enabledAsync,
  ) {
    if (enabledAsync.isLoading) return 'Checking…';
    if (availability == BiometricAvailability.notSupported) {
      return 'Not available on this device';
    }
    if (availability == BiometricAvailability.notEnrolled) {
      return 'Not set up — enable Face/Fingerprint in phone settings';
    }
    return enabledAsync.valueOrNull == true
        ? 'Enabled — unlock with fingerprint/Face ID'
        : 'Disabled';
  }

  Future<bool?> _confirmBiometricToggle(
    BuildContext context, {
    required bool enable,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsAlignment: MainAxisAlignment.end,
        title: Text(enable ? 'Enable biometric unlock?' : 'Disable biometric unlock?'),
        content: Text(
          enable
              ? 'You will be able to unlock SikaBoafo with fingerprint/Face ID on this device.'
              : 'You will need to enter your phone number and PIN next time you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(92, 44),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(92, 44),
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification(
    BuildContext context,
    WidgetRef ref, {
    required int id,
    required String title,
    required String body,
  }) async {
    await ref.read(notificationsServiceProvider).showTestNotification(
          id: id,
          title: title,
          body: body,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsAlignment: MainAxisAlignment.end,
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to enter your phone number and PIN again to log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(92, 44),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(92, 44),
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

  Future<bool?> _confirmDeleteAccount(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        actionsAlignment: MainAxisAlignment.end,
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your account access on this device. '
              'You will be signed out immediately.\n\n'
              'Type DELETE to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Confirmation',
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(92, 44)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ok = ctrl.text.trim().toUpperCase() == 'DELETE';
              Navigator.of(ctx).pop(ok);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(92, 44),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDeleteAccount(context);
    if (ok != true) return;
    if (!context.mounted) return;
    try {
      await ref.read(authApiProvider).deleteAccount();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${humanizeDioError(e)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await ref.read(sessionServiceProvider).signOut();
    if (!context.mounted) return;
    context.go(AppRoute.auth.path);
  }

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref) async {
    final enabled = ref.read(biometricPrefProvider).valueOrNull ?? false;
    final bio = ref.read(biometricServiceProvider);
    // Re-check real availability right before toggling.
    final availability = await ref.read(_biometricAvailabilityProvider.future);

    if (availability != BiometricAvailability.available) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            availability == BiometricAvailability.notEnrolled
                ? 'No biometrics enrolled for apps. Enable Face/Fingerprint in phone settings first.'
                : 'Biometrics not available on this device.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final next = !enabled;

    if (context.mounted) {
      final ok = await _confirmBiometricToggle(context, enable: next);
      if (ok != true) return;
    }
    if (!context.mounted) return;

    if (next) {
      final ok = await bio.authenticate(
        reason: 'Enable biometric unlock for SikaBoafo.',
      );
      if (!ok) {
        // If the device never showed a prompt, local_auth may consider the
        // biometric not enrolled/supported. Refresh the availability and surface it.
        ref.invalidate(_biometricAvailabilityProvider);
        final after = await ref.read(_biometricAvailabilityProvider.future);
        if (!context.mounted) return;
        final msg = switch (after) {
          BiometricAvailability.notEnrolled =>
            'Biometrics are not enrolled for apps on this device. Enable Face/Fingerprint in phone settings.',
          BiometricAvailability.notSupported =>
            'Biometrics are not supported on this device.',
          _ => 'Biometric authentication was cancelled or failed.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final persisted = await ref.read(biometricPrefProvider.notifier).setEnabled(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          persisted == next
              ? (next ? 'Biometric unlock enabled.' : 'Biometric unlock disabled.')
              : 'Saved, but could not verify the setting. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Keep the tile caption accurate after a toggle.
    ref.invalidate(_biometricAvailabilityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final businessName = ctxAsync.valueOrNull?.businessName;
    final subtitle = businessName ?? 'Manage your account';
    final biometricAsync = ref.watch(biometricPrefProvider);
    final availabilityAsync = ref.watch(_biometricAvailabilityProvider);
    final notifPrefsAsync = ref.watch(notificationPrefsProvider);

    const kLeadingGutter = 56.0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            stretch: true,
            leadingWidth: kLeadingGutter,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: StreakHeroHeader(
                leadingContentInset: kLeadingGutter,
                title: 'Settings',
                subtitle: subtitle,
                badge: const PremiumBadge(
                  label: 'Account & device',
                  icon: Icons.tune_rounded,
                  foreground: Colors.white,
                  background: Color(0x24FFFFFF),
                ),
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    )
                  : null,
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: kLeadingGutter,
                bottom: 16,
              ),
            ),
          ),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: ListView(
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
              const _SectionLabel('Notifications'),
              const SizedBox(height: 12),
              notifPrefsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _InlineError(message: e.toString()),
                data: (prefs) => Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.sync_rounded,
                      iconBg: AppColors.infoSoft,
                      iconColor: AppColors.navy,
                      label: 'Sync status',
                      caption: 'Offline and syncing updates',
                      value: prefs.syncStatusEnabled,
                      onChanged: (v) => ref
                          .read(notificationPrefsProvider.notifier)
                          .setSyncStatusEnabled(v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      icon: Icons.event_note_rounded,
                      iconBg: AppColors.warningSoft,
                      iconColor: AppColors.warning,
                      label: 'Debt reminders',
                      caption: 'Custom reminders you set per debt',
                      value: prefs.debtRemindersEnabled,
                      onChanged: (v) => ref
                          .read(notificationPrefsProvider.notifier)
                          .setDebtRemindersEnabled(v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      icon: Icons.inventory_2_outlined,
                      iconBg: AppColors.warningSoft,
                      iconColor: AppColors.warning,
                      label: 'Low stock',
                      caption: 'Alerts when stock hits your thresholds',
                      value: prefs.lowStockEnabled,
                      onChanged: (v) => ref
                          .read(notificationPrefsProvider.notifier)
                          .setLowStockEnabled(v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      icon: Icons.payments_outlined,
                      iconBg: AppColors.successSoft,
                      iconColor: AppColors.forest,
                      label: 'Payment events',
                      caption: 'Paystack success/failure alerts',
                      value: prefs.paymentEventsEnabled,
                      onChanged: (v) => ref
                          .read(notificationPrefsProvider.notifier)
                          .setPaymentEventsEnabled(v),
                    ),
                    const SizedBox(height: 10),
                    _SwitchTile(
                      icon: Icons.summarize_outlined,
                      iconBg: AppColors.surfaceAlt,
                      iconColor: AppColors.ink,
                      label: 'Daily summary',
                      caption: 'A daily snapshot of sales and activity',
                      value: prefs.dailySummaryEnabled,
                      onChanged: (v) => ref
                          .read(notificationPrefsProvider.notifier)
                          .setDailySummaryEnabled(v),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.schedule_rounded,
                      iconBg: AppColors.surfaceAlt,
                      iconColor: AppColors.ink,
                      label: 'Daily summary time',
                      caption:
                          _formatTimeOfDay(context, prefs.dailySummaryTime),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: prefs.dailySummaryTime,
                        );
                        if (picked == null || !context.mounted) return;
                        await ref
                            .read(notificationPrefsProvider.notifier)
                            .setDailySummaryTime(picked);
                      },
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel('Notification tests'),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.point_of_sale_rounded,
                      iconBg: AppColors.successSoft,
                      iconColor: AppColors.success,
                      label: 'Test: Sale completed',
                      caption: 'Sends a sample “sale done” notification',
                      onTap: () => _sendTestNotification(
                        context,
                        ref,
                        id: 9101,
                        title: 'Sale recorded',
                        body: '₵ 120.00 received · Cash · 3 items',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.inventory_2_outlined,
                      iconBg: AppColors.warningSoft,
                      iconColor: AppColors.warning,
                      label: 'Test: Low stock',
                      caption: 'Sends a sample low stock alert',
                      onTap: () => _sendTestNotification(
                        context,
                        ref,
                        id: 9102,
                        title: 'Low stock alert',
                        body: 'Sugar (1 left) · Restock soon',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.verified_rounded,
                      iconBg: AppColors.infoSoft,
                      iconColor: AppColors.navy,
                      label: 'Test: Payment successful',
                      caption: 'Sends a sample payment success event',
                      onTap: () => _sendTestNotification(
                        context,
                        ref,
                        id: 9103,
                        title: 'Payment successful',
                        body: 'Paystack · ₵ 80.00 · Ref: PSK_123456',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Account'),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.fingerprint_rounded,
                iconBg: AppColors.surfaceAlt,
                iconColor: AppColors.ink,
                label: 'Biometric unlock',
                caption: _biometricCaption(
                  availabilityAsync.valueOrNull,
                  biometricAsync,
                ),
                onTap: availabilityAsync.valueOrNull ==
                        BiometricAvailability.available
                    ? () => _toggleBiometric(context, ref)
                    : () {
                        final msg = switch (availabilityAsync.valueOrNull) {
                          BiometricAvailability.notEnrolled =>
                            'No biometrics enrolled. Enable Face/Fingerprint in phone settings first.',
                          BiometricAvailability.notSupported =>
                            'Biometrics not supported on this device.',
                          _ => 'Biometrics not available right now.',
                        };
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconBg: AppColors.dangerSoft,
                iconColor: AppColors.danger,
                label: 'Sign Out',
                caption: 'End this session on this device',
                isDestructive: true,
                onTap: () => _signOut(context, ref),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconBg: AppColors.dangerSoft,
                iconColor: AppColors.danger,
                label: 'Delete account',
                caption: 'Permanently delete your account access',
                isDestructive: true,
                onTap: () => _deleteAccount(context, ref),
              ),
            ],
          ),
        ),
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

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => onChanged(!value),
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
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.forest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: const Color(0xFFF2C9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTimeOfDay(BuildContext context, TimeOfDay t) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(t, alwaysUse24HourFormat: false);
}
