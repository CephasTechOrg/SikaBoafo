import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/settings_api.dart';

final paystackSettingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(ref.watch(apiClientProvider)),
);

final paystackConnectionProvider = FutureProvider<PaystackConnectionSettings>(
  (ref) => ref.watch(paystackSettingsApiProvider).fetchPaystackConnection(),
);

class ConnectPaystackScreen extends ConsumerStatefulWidget {
  const ConnectPaystackScreen({super.key});

  @override
  ConsumerState<ConnectPaystackScreen> createState() =>
      _ConnectPaystackScreenState();
}

class _ConnectPaystackScreenState extends ConsumerState<ConnectPaystackScreen> {
  final TextEditingController _accountLabelCtrl = TextEditingController();
  final TextEditingController _publicKeyCtrl = TextEditingController();
  final TextEditingController _secretKeyCtrl = TextEditingController();
  String _mode = 'test';
  bool _saving = false;
  bool _disconnecting = false;
  bool _hydratedFromServer = false;

  @override
  void dispose() {
    _accountLabelCtrl.dispose();
    _publicKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(paystackConnectionProvider);
    final connection = connectionAsync.valueOrNull;
    if (connection != null) {
      _hydrateForm(connection);
    }

    final isConnected = connection?.isConnected ?? false;
    final activeModeState = _activeModeState(connection);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.hero),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderActionButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => context.pop(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connect Paystack',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Store merchant-owned credentials securely on the backend',
                                  style: TextStyle(
                                    color: Color(0xFFC7D0E5),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ConnectionPill(isConnected: isConnected),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: PremiumSurface(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(paystackConnectionProvider);
                    await ref.read(paystackConnectionProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      _StatusCard(
                        isConnected: isConnected,
                        mode: connection?.mode ?? _mode,
                        accountLabel: connection?.accountLabel,
                        test: connection?.test,
                        live: connection?.live,
                      ),
                      const SizedBox(height: 14),
                      _ConnectionFormCard(
                        accountLabelCtrl: _accountLabelCtrl,
                        publicKeyCtrl: _publicKeyCtrl,
                        secretKeyCtrl: _secretKeyCtrl,
                        mode: _mode,
                        saving: _saving,
                        disconnecting: _disconnecting,
                        isConnected: isConnected,
                        activeModeState: activeModeState,
                        onModeChanged: (value) => setState(() => _mode = value),
                        onSave: _saving ? null : _saveConnection,
                        onDisconnect:
                            (isConnected && !_disconnecting && !_saving)
                                ? _disconnectConnection
                                : null,
                      ),
                      const SizedBox(height: 14),
                      const _InfoCard(
                        title: 'How this works',
                        body:
                            'The app only collects the merchant secret key. The backend verifies it, encrypts it, '
                            'and uses it for Paystack calls. Secret keys are write-only and never shown back in full.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hydrateForm(PaystackConnectionSettings connection) {
    if (_hydratedFromServer) return;
    _hydratedFromServer = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _accountLabelCtrl.text = connection.accountLabel ?? '';
      _publicKeyCtrl.text = '';
      _secretKeyCtrl.text = '';
      setState(() => _mode = connection.mode);
    });
  }

  PaystackModeState? _activeModeState(PaystackConnectionSettings? connection) {
    if (connection == null) return null;
    return _mode == 'live' ? connection.live : connection.test;
  }

  Future<void> _saveConnection() async {
    final publicKey = _publicKeyCtrl.text.trim();
    final secretKey = _secretKeyCtrl.text.trim();
    final activeModeState = _activeModeState(
      ref.read(paystackConnectionProvider).valueOrNull,
    );
    if (publicKey.isNotEmpty && !publicKey.startsWith('pk_')) {
      _showError('Public key must start with "pk_test_" or "pk_live_".');
      return;
    }
    if (secretKey.isEmpty && !(activeModeState?.configured ?? false)) {
      _showError('Secret key is required to connect this mode for the first time.');
      return;
    }
    if (secretKey.isNotEmpty && !secretKey.startsWith('sk_')) {
      _showError('Secret key must start with "sk_test_" or "sk_live_".');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(paystackSettingsApiProvider).savePaystackConnection(
            publicKey: publicKey.isEmpty ? null : publicKey,
            secretKey: secretKey.isEmpty ? null : secretKey,
            mode: _mode,
            accountLabel: _accountLabelCtrl.text,
          );
      _publicKeyCtrl.clear();
      _secretKeyCtrl.clear();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showSuccess('Paystack credentials saved and verified successfully.');
    } catch (error) {
      if (!mounted) return;
      _showError(_humanizeSettingsError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnectConnection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Paystack?'),
        content: const Text(
          'This will remove your saved credentials. '
          'Any pending payment links will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _disconnecting = true);
    try {
      await ref.read(paystackSettingsApiProvider).disconnectPaystackConnection();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showSuccess('Paystack disconnected.');
    } catch (error) {
      if (!mounted) return;
      _showError(_humanizeSettingsError(error));
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  String _humanizeSettingsError(Object error) {
    final raw = error.toString();
    // Extract detail from DioException response
    if (raw.contains('503') || raw.contains('SERVICE_UNAVAILABLE')) {
      return 'Server configuration error. Please contact support.';
    }
    if (raw.contains('502') || raw.contains('BAD_GATEWAY')) {
      return 'Could not verify key with Paystack. Check the key is correct and try again.';
    }
    if (raw.contains('400') || raw.contains('BAD_REQUEST')) {
      return 'Invalid credentials. Make sure you copied the key correctly from your Paystack dashboard.';
    }
    if (raw.contains('401') || raw.contains('403')) {
      return 'You do not have permission to update payment settings. Only the account owner can do this.';
    }
    if (raw.contains('connection') || raw.contains('SocketException')) {
      return 'No internet connection. Check your network and try again.';
    }
    // Try to extract a readable detail from API JSON
    final detailMatch = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (detailMatch != null) return detailMatch.group(1)!;
    return 'Something went wrong. Please try again.';
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final background =
        isConnected ? AppColors.successSoft : AppColors.warningSoft;
    final foreground = isConnected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isConnected ? 'Connected' : 'Not Connected',
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isConnected,
    required this.mode,
    required this.accountLabel,
    required this.test,
    required this.live,
  });

  final bool isConnected;
  final String mode;
  final String? accountLabel;
  final PaystackModeState? test;
  final PaystackModeState? live;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PremiumSectionHeading(
                  title: 'Connection Status',
                  caption: isConnected
                      ? 'Your Paystack account is active and ready to accept payments.'
                      : 'Save your Paystack credentials below to start accepting payments.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isConnected ? AppColors.successSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isConnected
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color: isConnected ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Connected · ${mode == 'live' ? 'Live mode' : 'Test mode'}'
                        : 'Not connected — credentials not saved yet',
                    style: TextStyle(
                      color: isConnected ? AppColors.success : AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (accountLabel != null) ...[
            const SizedBox(height: 10),
            _StatusRow(label: 'Account', value: accountLabel!),
          ],
          const SizedBox(height: 10),
          _ModeStatusRow(label: 'Test mode', state: test),
          _ModeStatusRow(label: 'Live mode', state: live),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeStatusRow extends StatelessWidget {
  const _ModeStatusRow({required this.label, required this.state});

  final String label;
  final PaystackModeState? state;

  @override
  Widget build(BuildContext context) {
    final configured = state?.configured ?? false;
    final verified = state?.verifiedAt != null;
    final masked = state?.secretKeyMasked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            configured && verified
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: configured && verified ? AppColors.success : AppColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              configured
                  ? '$label · ${verified ? 'Verified' : 'Saved'}${masked != null ? ' · $masked' : ''}'
                  : '$label · Not configured',
              style: TextStyle(
                fontSize: 12.5,
                color: configured ? AppColors.ink : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionFormCard extends StatelessWidget {
  const _ConnectionFormCard({
    required this.accountLabelCtrl,
    required this.publicKeyCtrl,
    required this.secretKeyCtrl,
    required this.mode,
    required this.saving,
    required this.disconnecting,
    required this.isConnected,
    required this.activeModeState,
    required this.onModeChanged,
    required this.onSave,
    required this.onDisconnect,
  });

  final TextEditingController accountLabelCtrl;
  final TextEditingController publicKeyCtrl;
  final TextEditingController secretKeyCtrl;
  final String mode;
  final bool saving;
  final bool disconnecting;
  final bool isConnected;
  final PaystackModeState? activeModeState;
  final ValueChanged<String> onModeChanged;
  final VoidCallback? onSave;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final alreadyConfigured = activeModeState?.configured ?? false;
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeading(
            title: 'Your Paystack Credentials',
            caption: mode == 'live'
                ? 'Live mode — real payments will be processed.'
                : 'Test mode — use test keys to try without real money.',
          ),
          const SizedBox(height: 14),
          // Mode toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _ModeTab(
                  label: 'Test Mode',
                  selected: mode == 'test',
                  onTap: () => onModeChanged('test'),
                ),
                _ModeTab(
                  label: 'Live Mode',
                  selected: mode == 'live',
                  onTap: () => onModeChanged('live'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: accountLabelCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Account label (optional)',
              hintText: 'e.g. Main Business Account',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: publicKeyCtrl,
            decoration: InputDecoration(
              labelText: 'Public key (optional)',
              hintText: mode == 'live' ? 'pk_live_...' : 'pk_test_...',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              helperText: activeModeState?.publicKeyMasked != null
                  ? 'Saved: ${activeModeState!.publicKeyMasked}'
                  : 'Found in Paystack Dashboard → Settings → API Keys',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: secretKeyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: alreadyConfigured
                  ? 'Secret key (leave empty to keep current)'
                  : 'Secret key *',
              hintText: mode == 'live' ? 'sk_live_...' : 'sk_test_...',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              helperText: activeModeState?.secretKeyMasked != null
                  ? 'Saved key: ${activeModeState!.secretKeyMasked}'
                  : 'Required. This is encrypted and stored securely — never shown back in full.',
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(saving ? 'Verifying with Paystack...' : 'Save & Verify'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (isConnected) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDisconnect,
                icon: disconnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off_rounded),
                label: Text(
                  disconnecting ? 'Disconnecting...' : 'Disconnect Paystack',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.info_outline_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
