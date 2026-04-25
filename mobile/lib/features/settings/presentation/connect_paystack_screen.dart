import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

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

  @override
  void dispose() {
    _accountLabelCtrl.dispose();
    _publicKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hydrate form every time fresh data arrives (initial load + after save/disconnect).
    ref.listen<AsyncValue<PaystackConnectionSettings>>(
      paystackConnectionProvider,
      (_, next) => next.whenData(_hydrateForm),
    );

    final connectionAsync = ref.watch(paystackConnectionProvider);
    final connection = connectionAsync.valueOrNull;
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
                child: connectionAsync.when(
                  loading: () => _buildLoadingSkeleton(),
                  error: (error, _) => _buildErrorPanel(error),
                  data: (_) => RefreshIndicator(
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
                          onModeChanged: (value) =>
                              setState(() => _mode = value),
                          onSave: _saving ? null : _saveConnection,
                          onDisconnect:
                              (isConnected && !_disconnecting && !_saving)
                                  ? _disconnectConnection
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        const _WebhookCard(),
                        const SizedBox(height: 14),
                        const _InfoCard(
                          title: 'How this works',
                          body:
                              'Your secret key is verified with Paystack, then encrypted and stored securely on the server — '
                              'never shown back in full. Payments go directly into your own Paystack account.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        _SkeletonPanel(height: 140),
        const SizedBox(height: 14),
        _SkeletonPanel(height: 320),
        const SizedBox(height: 14),
        _SkeletonPanel(height: 80),
      ],
    );
  }

  Widget _buildErrorPanel(Object error) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        _LoadErrorPanel(
          onRetry: () => ref.invalidate(paystackConnectionProvider),
        ),
      ],
    );
  }

  void _hydrateForm(PaystackConnectionSettings connection) {
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
    if (secretKey.isNotEmpty) {
      if (secretKey.startsWith('pk_')) {
        _showError('Enter the Paystack secret key, not the public key.');
        return;
      }
      final expectedPrefix = _mode == 'live' ? 'sk_live_' : 'sk_test_';
      if (!secretKey.startsWith(expectedPrefix)) {
        _showError(
          _mode == 'live'
              ? 'Live mode requires an "sk_live_" secret key.'
              : 'Test mode requires an "sk_test_" secret key.',
        );
        return;
      }
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
      _showSuccess('Paystack credentials saved successfully.');
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
      builder: (ctx) => const _DisconnectConfirmDialog(),
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
    if (error is DioException) {
      final data = error.response?.data;
      // Always prefer the backend's exact detail message for all error codes.
      if (data is Map<String, dynamic> && data['detail'] is String) {
        final detail = (data['detail'] as String).trim();
        if (detail.isNotEmpty) return detail;
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 503) {
        return 'Server configuration error. Please contact support.';
      }
      if (statusCode == 502) {
        return 'Could not reach Paystack to verify the key. Check your internet and try again.';
      }
      if (statusCode == 400) {
        return 'Invalid key. Check you copied the correct secret key for this mode.';
      }
      if (statusCode == 401 || statusCode == 403) {
        return 'Permission denied. Only the merchant owner can update payment settings.';
      }
      if (statusCode == 404) {
        return 'Merchant profile not found. Try logging out and back in.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet connection. Check your network and try again.';
      }
      return error.message ?? 'Something went wrong. Please try again.';
    }
    final raw = error.toString();
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

class _ConnectionFormCard extends StatefulWidget {
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
  State<_ConnectionFormCard> createState() => _ConnectionFormCardState();
}

class _ConnectionFormCardState extends State<_ConnectionFormCard> {
  bool _obscureSecret = true;

  @override
  Widget build(BuildContext context) {
    final alreadyConfigured = widget.activeModeState?.configured ?? false;
    final busy = widget.saving || widget.disconnecting;

    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeading(
            title: 'Your Paystack Credentials',
            caption: widget.mode == 'live'
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
                  selected: widget.mode == 'test',
                  onTap: busy ? null : () => widget.onModeChanged('test'),
                ),
                _ModeTab(
                  label: 'Live Mode',
                  selected: widget.mode == 'live',
                  onTap: busy ? null : () => widget.onModeChanged('live'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: widget.accountLabelCtrl,
            enabled: !busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Account label (optional)',
              hintText: 'e.g. Main Business Account',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.publicKeyCtrl,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Public key (optional)',
              hintText: widget.mode == 'live' ? 'pk_live_...' : 'pk_test_...',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              helperText: widget.activeModeState?.publicKeyMasked != null
                  ? 'Saved: ${widget.activeModeState!.publicKeyMasked}'
                  : 'Found in Paystack Dashboard → Settings → API Keys',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.secretKeyCtrl,
            enabled: !busy,
            obscureText: _obscureSecret,
            decoration: InputDecoration(
              labelText: alreadyConfigured
                  ? 'Secret key (leave empty to keep current)'
                  : 'Secret key *',
              hintText: widget.mode == 'live' ? 'sk_live_...' : 'sk_test_...',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSecret
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: busy
                    ? null
                    : () => setState(() => _obscureSecret = !_obscureSecret),
                tooltip: _obscureSecret ? 'Show key' : 'Hide key',
              ),
              helperText: widget.activeModeState?.secretKeyMasked != null
                  ? 'Saved key: ${widget.activeModeState!.secretKeyMasked}'
                  : 'Required. This is encrypted and stored securely — never shown back in full.',
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onSave,
              icon: widget.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(widget.saving ? 'Verifying...' : 'Save & Verify'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (widget.isConnected) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onDisconnect,
                icon: widget.disconnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_off_rounded),
                label: Text(
                  widget.disconnecting
                      ? 'Disconnecting...'
                      : 'Disconnect Paystack',
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
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
                color: selected
                    ? Colors.white
                    : onTap == null
                        ? AppColors.mutedSoft
                        : AppColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPanel extends StatelessWidget {
  const _SkeletonPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _LoadErrorPanel extends StatelessWidget {
  const _LoadErrorPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: AppColors.danger,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: AppColors.danger),
          const SizedBox(height: 12),
          Text(
            'Could not load your Paystack settings.',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _WebhookCard extends StatelessWidget {
  const _WebhookCard();

  static const _webhookUrl =
      'https://biztrackgh-api.onrender.com/api/v1/webhooks/paystack';

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.webhook_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Webhook Setup Required',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One-time setup in your Paystack dashboard',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Paste this URL into your Paystack dashboard under '
            'Settings → API Keys & Webhooks → Webhook URL. '
            'This tells Paystack where to send payment confirmations.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _webhookUrl,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: _webhookUrl),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Webhook URL copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _DisconnectConfirmDialog extends StatefulWidget {
  const _DisconnectConfirmDialog();

  @override
  State<_DisconnectConfirmDialog> createState() =>
      _DisconnectConfirmDialogState();
}

class _DisconnectConfirmDialogState extends State<_DisconnectConfirmDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final matches = _ctrl.text == 'DISCONNECT';
      if (matches != _confirmed) setState(() => _confirmed = matches);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.link_off_rounded,
              color: AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Disconnect Paystack',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'This will remove your encrypted Paystack credentials from the server. '
              'Payments will stop working immediately until you reconnect.',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Type DISCONNECT to confirm:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'DISCONNECT',
              errorText: _ctrl.text.isNotEmpty && !_confirmed
                  ? 'Type exactly: DISCONNECT'
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirmed
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            disabledBackgroundColor: AppColors.dangerSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Disconnect'),
        ),
      ],
    );
  }
}
