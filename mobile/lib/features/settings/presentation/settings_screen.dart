import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
import '../../dashboard/providers/dashboard_providers.dart';
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
        title: Text(
            enable ? 'Enable biometric unlock?' : 'Disable biometric unlock?'),
        content: Text(
          enable
              ? 'You will be able to unlock SikaBoafo with fingerprint/Face ID on this device.'
              : 'You will need to enter your phone number and PIN next time you sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(92, 44)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(92, 44)),
            child: const Text('Yes'),
          ),
        ],
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
            style: TextButton.styleFrom(minimumSize: const Size(92, 44)),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DashboardMockup.danger,
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
              backgroundColor: DashboardMockup.danger,
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
    final availability =
        await ref.read(_biometricAvailabilityProvider.future);

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
        ref.invalidate(_biometricAvailabilityProvider);
        final after =
            await ref.read(_biometricAvailabilityProvider.future);
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
              content: Text(msg), behavior: SnackBarBehavior.floating),
        );
        return;
      }
    }

    final persisted =
        await ref.read(biometricPrefProvider.notifier).setEnabled(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          persisted == next
              ? (next
                  ? 'Biometric unlock enabled.'
                  : 'Biometric unlock disabled.')
              : 'Saved, but could not verify the setting. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    ref.invalidate(_biometricAvailabilityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final businessName = ctxAsync.valueOrNull?.businessName;
    final subtitle = businessName ?? 'Account & preferences';
    final biometricAsync = ref.watch(biometricPrefProvider);
    final availabilityAsync = ref.watch(_biometricAvailabilityProvider);
    final notifPrefsAsync = ref.watch(notificationPrefsProvider);
    final isOwnerAsync = ref.watch(isMerchantOwnerProvider);
    final showOwnerOnly = isOwnerAsync.valueOrNull ?? true;

    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              DashboardMockup.gutter,
              topPad + 14,
              DashboardMockup.gutter,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DashboardMockup.lineSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.arrowLeft,
                      size: 18,
                      color: DashboardMockup.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: DashboardMockup.ink,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: DashboardMockup.ink2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sections ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              DashboardMockup.gutter,
              24,
              DashboardMockup.gutter,
              bottomPad + 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business (owner only)
                if (showOwnerOnly) ...[
                  const _SecLabel('Business'),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: LucideIcons.building,
                    iconBg: DashboardMockup.greenTint,
                    iconColor: DashboardMockup.green700,
                    label: 'Business Profile',
                    sub: 'Edit name, type and store details',
                    onTap: () =>
                        context.push(AppRoute.businessProfile.path),
                  ),
                  const SizedBox(height: 11),
                  _SettingsTile(
                    icon: LucideIcons.users,
                    iconBg: DashboardMockup.greenTint,
                    iconColor: DashboardMockup.green700,
                    label: 'Staff & Team',
                    sub: 'Invite teammates and manage access',
                    onTap: () => context.push(AppRoute.staff.path),
                  ),
                  const SizedBox(height: 11),
                  _SettingsTile(
                    icon: LucideIcons.creditCard,
                    iconBg: DashboardMockup.warnTint,
                    iconColor: DashboardMockup.warn,
                    label: 'Paystack Payments',
                    sub: 'Connect your Paystack account',
                    onTap: () => context.push(AppRoute.paystack.path),
                  ),
                  const SizedBox(height: 11),
                  _SettingsTile(
                    icon: LucideIcons.clipboardList,
                    iconBg: DashboardMockup.lineSoft,
                    iconColor: DashboardMockup.ink2,
                    label: 'Activity Log',
                    sub: 'Review owner audit trail',
                    onTap: () => context.push(AppRoute.activity.path),
                  ),
                  const SizedBox(height: 28),
                ],

                // Notifications
                const _SecLabel('Notifications'),
                const SizedBox(height: 12),
                notifPrefsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) =>
                      _InlineError(message: userFriendlyError(e)),
                  data: (prefs) => Column(
                    children: [
                      _SwitchTile(
                        icon: LucideIcons.refreshCw,
                        iconBg: DashboardMockup.greenTint,
                        iconColor: DashboardMockup.green700,
                        label: 'Sync status',
                        sub: 'Offline and syncing updates',
                        value: prefs.syncStatusEnabled,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .setSyncStatusEnabled(v),
                      ),
                      const SizedBox(height: 11),
                      _SwitchTile(
                        icon: LucideIcons.bell,
                        iconBg: DashboardMockup.warnTint,
                        iconColor: DashboardMockup.warn,
                        label: 'Debt reminders',
                        sub: 'Custom reminders you set per debt',
                        value: prefs.debtRemindersEnabled,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .setDebtRemindersEnabled(v),
                      ),
                      const SizedBox(height: 11),
                      _SwitchTile(
                        icon: LucideIcons.package,
                        iconBg: DashboardMockup.warnTint,
                        iconColor: DashboardMockup.warn,
                        label: 'Low stock',
                        sub: 'Alerts when stock hits your thresholds',
                        value: prefs.lowStockEnabled,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .setLowStockEnabled(v),
                      ),
                      const SizedBox(height: 11),
                      _SwitchTile(
                        icon: LucideIcons.wallet,
                        iconBg: DashboardMockup.greenTint,
                        iconColor: DashboardMockup.green700,
                        label: 'Payment events',
                        sub: 'Paystack success/failure alerts',
                        value: prefs.paymentEventsEnabled,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .setPaymentEventsEnabled(v),
                      ),
                      const SizedBox(height: 11),
                      _SwitchTile(
                        icon: LucideIcons.barChart2,
                        iconBg: DashboardMockup.lineSoft,
                        iconColor: DashboardMockup.ink2,
                        label: 'Daily summary',
                        sub: 'A daily snapshot of sales and activity',
                        value: prefs.dailySummaryEnabled,
                        onChanged: (v) => ref
                            .read(notificationPrefsProvider.notifier)
                            .setDailySummaryEnabled(v),
                      ),
                      const SizedBox(height: 11),
                      _SettingsTile(
                        icon: LucideIcons.clock,
                        iconBg: DashboardMockup.lineSoft,
                        iconColor: DashboardMockup.ink2,
                        label: 'Daily summary time',
                        sub: _formatTimeOfDay(
                            context, prefs.dailySummaryTime),
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
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Account
                const _SecLabel('Account'),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: LucideIcons.fingerprint,
                  iconBg: DashboardMockup.lineSoft,
                  iconColor: DashboardMockup.ink2,
                  label: 'Biometric unlock',
                  sub: _biometricCaption(
                    availabilityAsync.valueOrNull,
                    biometricAsync,
                  ),
                  onTap: availabilityAsync.valueOrNull ==
                          BiometricAvailability.available
                      ? () => _toggleBiometric(context, ref)
                      : () {
                          final msg =
                              switch (availabilityAsync.valueOrNull) {
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
                const SizedBox(height: 11),
                _SettingsTile(
                  icon: LucideIcons.logOut,
                  iconBg: DashboardMockup.dangerTint,
                  iconColor: DashboardMockup.danger,
                  label: 'Sign out',
                  sub: 'End this session on this device',
                  isDestructive: true,
                  onTap: () => _signOut(context, ref),
                ),
                if (showOwnerOnly) ...[
                  const SizedBox(height: 11),
                  _SettingsTile(
                    icon: LucideIcons.trash2,
                    iconBg: DashboardMockup.dangerTint,
                    iconColor: DashboardMockup.danger,
                    label: 'Delete account',
                    sub: 'Permanently delete your account access',
                    isDestructive: true,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SecLabel extends StatelessWidget {
  const _SecLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: DashboardMockup.ink3,
      ),
    );
  }
}

// ── Navigation tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isDestructive ? DashboardMockup.danger : DashboardMockup.ink;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Material(
        color: DashboardMockup.card,
        borderRadius:
            BorderRadius.circular(DashboardMockup.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: DashboardMockup.lineSoft),
              borderRadius:
                  BorderRadius.circular(DashboardMockup.cardRadius),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DashboardMockup.ink2,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: DashboardMockup.ink3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Material(
        color: DashboardMockup.card,
        borderRadius:
            BorderRadius.circular(DashboardMockup.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 15, 8, 15),
            decoration: BoxDecoration(
              border: Border.all(color: DashboardMockup.lineSoft),
              borderRadius:
                  BorderRadius.circular(DashboardMockup.cardRadius),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: DashboardMockup.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DashboardMockup.ink2,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: DashboardMockup.green700,
                  inactiveThumbColor: DashboardMockup.ink3,
                  inactiveTrackColor: DashboardMockup.lineSoft,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inline error ──────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DashboardMockup.dangerTint,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        border: Border.all(color: const Color(0xFFF2C9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            color: DashboardMockup.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DashboardMockup.danger,
                fontSize: 14,
              ),
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
