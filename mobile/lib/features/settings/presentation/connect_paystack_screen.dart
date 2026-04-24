import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String _mode = 'test';
  bool _saving = false;
  bool _disconnecting = false;
  bool _hydratedFromServer = false;

  @override
  void dispose() {
    _accountLabelCtrl.dispose();
    _publicKeyCtrl.dispose();
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
                            onTap: () => Navigator.of(context).maybePop(),
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
                                  'Step 1: configure payment mode and public key',
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
                        publicKeyMasked: connection?.publicKeyMasked,
                      ),
                      const SizedBox(height: 14),
                      _ConnectionFormCard(
                        accountLabelCtrl: _accountLabelCtrl,
                        publicKeyCtrl: _publicKeyCtrl,
                        mode: _mode,
                        saving: _saving,
                        disconnecting: _disconnecting,
                        isConnected: isConnected,
                        onModeChanged: (value) => setState(() => _mode = value),
                        onSave: _saving ? null : _saveConnection,
                        onDisconnect:
                            (isConnected && !_disconnecting && !_saving)
                                ? _disconnectConnection
                                : null,
                      ),
                      const SizedBox(height: 14),
                      const _InfoCard(
                        title: 'What this step covers',
                        body:
                            'This page stores your Paystack mode and public key label. '
                            'Transaction initialization, secret-key handling, and webhook '
                            'verification are in the next M4 slices.',
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
      setState(() => _mode = connection.mode);
    });
  }

  Future<void> _saveConnection() async {
    final publicKey = _publicKeyCtrl.text.trim();
    if (publicKey.isEmpty) {
      _showMessage('Public key is required.');
      return;
    }
    if (!publicKey.startsWith('pk_')) {
      _showMessage('Public key should start with "pk_".');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(paystackSettingsApiProvider).savePaystackConnection(
            publicKey: publicKey,
            mode: _mode,
            accountLabel: _accountLabelCtrl.text,
          );
      _publicKeyCtrl.clear();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showMessage('Paystack settings saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _disconnectConnection() async {
    setState(() => _disconnecting = true);
    try {
      await ref
          .read(paystackSettingsApiProvider)
          .disconnectPaystackConnection();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showMessage('Paystack disconnected.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _disconnecting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    required this.publicKeyMasked,
  });

  final bool isConnected;
  final String mode;
  final String? accountLabel;
  final String? publicKeyMasked;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeading(
            title: 'Connection Status',
            caption: isConnected
                ? 'Paystack is configured for this business.'
                : 'Paystack is not connected yet.',
          ),
          const SizedBox(height: 12),
          _StatusRow(
              label: 'Status',
              value: isConnected ? 'Connected' : 'Not Connected'),
          _StatusRow(label: 'Mode', value: mode == 'live' ? 'Live' : 'Test'),
          _StatusRow(label: 'Label', value: accountLabel ?? 'Not set'),
          _StatusRow(label: 'Public key', value: publicKeyMasked ?? 'Not set'),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
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
    required this.mode,
    required this.saving,
    required this.disconnecting,
    required this.isConnected,
    required this.onModeChanged,
    required this.onSave,
    required this.onDisconnect,
  });

  final TextEditingController accountLabelCtrl;
  final TextEditingController publicKeyCtrl;
  final String mode;
  final bool saving;
  final bool disconnecting;
  final bool isConnected;
  final ValueChanged<String> onModeChanged;
  final VoidCallback? onSave;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeading(
            title: 'Paystack Settings',
            caption: 'Choose mode and save the public key for this merchant.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: accountLabelCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Account label (optional)',
              hintText: 'Main Paystack Account',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: mode,
            decoration: const InputDecoration(labelText: 'Mode'),
            items: const [
              DropdownMenuItem(value: 'test', child: Text('Test')),
              DropdownMenuItem(value: 'live', child: Text('Live')),
            ],
            onChanged: (value) {
              if (value == null) return;
              onModeChanged(value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: publicKeyCtrl,
            decoration: const InputDecoration(
              labelText: 'Public key',
              hintText: 'pk_test_...',
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_rounded),
              label: Text(saving ? 'Saving...' : 'Save Paystack Settings'),
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
                    disconnecting ? 'Disconnecting...' : 'Disconnect Paystack'),
              ),
            ),
          ],
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
