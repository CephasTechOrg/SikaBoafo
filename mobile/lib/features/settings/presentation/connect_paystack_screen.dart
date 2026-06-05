import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/env/app_config.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
import '../data/settings_api.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final paystackSettingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(
    ref.watch(apiClientProvider),
    cache: KvCacheRepository(ref.watch(appDatabaseProvider)),
  ),
);

final paystackConnectionProvider = FutureProvider<PaystackConnectionSettings>(
  (ref) => ref.watch(paystackSettingsApiProvider).fetchPaystackConnection(),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class ConnectPaystackScreen extends ConsumerStatefulWidget {
  const ConnectPaystackScreen({super.key});

  @override
  ConsumerState<ConnectPaystackScreen> createState() =>
      _ConnectPaystackScreenState();
}

class _ConnectPaystackScreenState
    extends ConsumerState<ConnectPaystackScreen> {
  final _accountLabelCtrl = TextEditingController();
  final _publicKeyCtrl    = TextEditingController();
  final _secretKeyCtrl    = TextEditingController();
  String _mode            = 'test';
  bool   _saving          = false;
  bool   _disconnecting   = false;
  bool   _obscureSecret   = true;

  @override
  void dispose() {
    _accountLabelCtrl.dispose();
    _publicKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    super.dispose();
  }

  static InputDecoration _field(String label, {String? hint, String? helper,
      Widget? suffix, Widget? prefix}) {
    final radius = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      suffixIcon: suffix,
      prefixIcon: prefix,
      hintStyle: const TextStyle(color: DashboardMockup.ink3, fontSize: 14.5),
      helperStyle: const TextStyle(color: DashboardMockup.ink3, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(
        color: DashboardMockup.ink3, fontSize: 14, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(
        color: DashboardMockup.green700, fontSize: 12.5, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: DashboardMockup.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: DashboardMockup.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide:
              const BorderSide(color: DashboardMockup.green700, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PaystackConnectionSettings>>(
      paystackConnectionProvider,
      (_, next) => next.whenData(_hydrateForm),
    );

    final connectionAsync = ref.watch(paystackConnectionProvider);
    final connection      = connectionAsync.valueOrNull;
    final isConnected     = connection?.isConnected ?? false;
    final activeModeState = _activeModeState(connection);
    final busy            = _saving || _disconnecting;

    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final subtitle  = isConnected
        ? 'Connected · ${connection?.mode == 'live' ? 'Live' : 'Test'} mode'
        : 'Not connected';

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: RefreshIndicator(
        color: DashboardMockup.green700,
        onRefresh: () async {
          ref.invalidate(paystackConnectionProvider);
          await ref.read(paystackConnectionProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  DashboardMockup.gutter, topPad + 14,
                  DashboardMockup.gutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: DashboardMockup.lineSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.arrowLeft,
                          size: 18, color: DashboardMockup.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paystack',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26, fontWeight: FontWeight.w800,
                              color: DashboardMockup.ink,
                              letterSpacing: -0.5, height: 1.1)),
                        Text(subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5, fontWeight: FontWeight.w500,
                              color: DashboardMockup.ink2, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  DashboardMockup.gutter, 24,
                  DashboardMockup.gutter, bottomPad + 32),
              child: connectionAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: SizedBox(width: 28, height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: DashboardMockup.green700)),
                  ),
                ),
                error: (e, _) => _ErrorCard(
                  onRetry: () => ref.invalidate(paystackConnectionProvider)),
                data: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Connection status ──────────────────────────────
                    if (isConnected) ...[
                      _StatusCard(connection: connection!),
                      const SizedBox(height: 24),
                    ],

                    // ── Credentials ────────────────────────────────────
                    const _SecLabel('Credentials'),
                    const SizedBox(height: 12),
                    _FormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Mode toggle
                          Row(children: [
                            _ModeChip(
                              label: 'Test Mode',
                              selected: _mode == 'test',
                              onTap: busy ? null
                                  : () => setState(() => _mode = 'test'),
                            ),
                            const SizedBox(width: 8),
                            _ModeChip(
                              label: 'Live Mode',
                              selected: _mode == 'live',
                              onTap: busy ? null
                                  : () => setState(() => _mode = 'live'),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _accountLabelCtrl,
                            enabled: !busy,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: DashboardMockup.ink),
                            decoration: _field('Account label',
                                hint: 'e.g. Main Business Account'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _publicKeyCtrl,
                            enabled: !busy,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: DashboardMockup.ink),
                            decoration: _field(
                              'Public key',
                              hint: _mode == 'live'
                                  ? 'pk_live_…' : 'pk_test_…',
                              helper: activeModeState?.publicKeyMasked != null
                                  ? 'Saved: ${activeModeState!.publicKeyMasked}'
                                  : 'Paystack Dashboard → Settings → API Keys',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _secretKeyCtrl,
                            enabled: !busy,
                            obscureText: _obscureSecret,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: DashboardMockup.ink),
                            decoration: _field(
                              activeModeState?.configured == true
                                  ? 'Secret key (leave blank to keep)'
                                  : 'Secret key *',
                              hint: _mode == 'live'
                                  ? 'sk_live_…' : 'sk_test_…',
                              helper: activeModeState?.secretKeyMasked != null
                                  ? 'Saved: ${activeModeState!.secretKeyMasked}'
                                  : 'Encrypted and stored securely.',
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureSecret
                                      ? LucideIcons.eye
                                      : LucideIcons.eyeOff,
                                  size: 18,
                                  color: DashboardMockup.ink3,
                                ),
                                onPressed: busy ? null
                                    : () => setState(
                                        () => _obscureSecret = !_obscureSecret),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Save button
                          _ActionButton(
                            label: _saving ? 'Verifying…' : 'Save & Verify',
                            icon: _saving ? null : LucideIcons.check,
                            loading: _saving,
                            color: DashboardMockup.green600,
                            onPressed: (_saving || _disconnecting)
                                ? null : _saveConnection,
                          ),
                          if (isConnected) ...[
                            const SizedBox(height: 10),
                            _ActionButton(
                              label: _disconnecting
                                  ? 'Disconnecting…' : 'Disconnect',
                              icon: _disconnecting ? null : LucideIcons.x,
                              loading: _disconnecting,
                              color: DashboardMockup.dangerTint,
                              textColor: DashboardMockup.danger,
                              onPressed: (_saving || _disconnecting)
                                  ? null : _disconnectConnection,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Webhook ────────────────────────────────────────
                    const SizedBox(height: 24),
                    const _SecLabel('Webhook'),
                    const SizedBox(height: 12),
                    _WebhookTile(
                      url: AppConfig.apiV1('/webhooks/paystack').toString(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste this in Paystack Dashboard → Settings → Webhooks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5, fontWeight: FontWeight.w500,
                        color: DashboardMockup.ink3),
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

  void _hydrateForm(PaystackConnectionSettings connection) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _accountLabelCtrl.text = connection.accountLabel ?? '';
      _publicKeyCtrl.text    = '';
      _secretKeyCtrl.text    = '';
      setState(() => _mode = connection.mode);
    });
  }

  PaystackModeState? _activeModeState(PaystackConnectionSettings? c) {
    if (c == null) return null;
    return _mode == 'live' ? c.live : c.test;
  }

  Future<void> _saveConnection() async {
    final pub = _publicKeyCtrl.text.trim();
    final sec = _secretKeyCtrl.text.trim();
    final modeState =
        _activeModeState(ref.read(paystackConnectionProvider).valueOrNull);

    if (pub.isNotEmpty && !pub.startsWith('pk_')) {
      _showError('Public key must start with "pk_test_" or "pk_live_".');
      return;
    }
    if (sec.isEmpty && !(modeState?.configured ?? false)) {
      _showError('Secret key is required to connect for the first time.');
      return;
    }
    if (sec.isNotEmpty) {
      if (sec.startsWith('pk_')) {
        _showError('Enter the secret key, not the public key.');
        return;
      }
      final prefix = _mode == 'live' ? 'sk_live_' : 'sk_test_';
      if (!sec.startsWith(prefix)) {
        _showError(_mode == 'live'
            ? 'Live mode requires an "sk_live_" key.'
            : 'Test mode requires an "sk_test_" key.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(paystackSettingsApiProvider).savePaystackConnection(
            publicKey: pub.isEmpty ? null : pub,
            secretKey: sec.isEmpty ? null : sec,
            mode: _mode,
            accountLabel: _accountLabelCtrl.text,
          );
      _publicKeyCtrl.clear();
      _secretKeyCtrl.clear();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showSuccess('Paystack credentials saved.');
    } catch (error) {
      if (!mounted) return;
      _showError(_humanizeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnectConnection() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DisconnectDialog(),
    );
    if (ok != true || !mounted) return;

    setState(() => _disconnecting = true);
    try {
      await ref
          .read(paystackSettingsApiProvider)
          .disconnectPaystackConnection();
      ref.invalidate(paystackConnectionProvider);
      if (!mounted) return;
      _showSuccess('Paystack disconnected.');
    } catch (error) {
      if (!mounted) return;
      _showError(_humanizeError(error));
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }

  String _humanizeError(Object error) {
    if (error is DioException) {
      final data   = error.response?.data;
      final status = error.response?.statusCode;
      if (data is Map<String, dynamic> && data['detail'] is String) {
        final d = (data['detail'] as String).trim();
        if (d.isNotEmpty) return d;
      }
      if (status == 503) return 'Server error. Please contact support.';
      if (status == 502) return 'Cannot reach Paystack. Check your internet.';
      if (status == 400) return 'Invalid key. Check you copied the correct one.';
      if (status == 401 || status == 403) {
        return 'Permission denied. Only the owner can update payment settings.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet. Check your network and try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: DashboardMockup.green700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: DashboardMockup.danger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ── Status card (when connected) ──────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.connection});
  final PaystackConnectionSettings connection;

  @override
  Widget build(BuildContext context) {
    final test = connection.test;
    final live = connection.live;
    final label = connection.accountLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: DashboardMockup.greenTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.checkCircle,
                      size: 20, color: DashboardMockup.green700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connected',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: DashboardMockup.ink)),
                      if (label != null && label.isNotEmpty)
                        Text(label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: DashboardMockup.ink2)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: DashboardMockup.greenTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    connection.mode == 'live' ? 'Live' : 'Test',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: DashboardMockup.green700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: DashboardMockup.lineSoft),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ModePill(label: 'Test', state: test)),
              const SizedBox(width: 8),
              Expanded(child: _ModePill(label: 'Live', state: live)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.label, required this.state});
  final String label;
  final PaystackModeState? state;

  @override
  Widget build(BuildContext context) {
    final ok = (state?.configured ?? false) && state?.verifiedAt != null;
    final configured = state?.configured ?? false;
    final bg = ok
        ? DashboardMockup.greenTint
        : configured
            ? DashboardMockup.warnTint
            : DashboardMockup.lineSoft;
    final fg = ok
        ? DashboardMockup.green700
        : configured
            ? DashboardMockup.warn
            : DashboardMockup.ink3;
    final icon = ok
        ? LucideIcons.check
        : configured
            ? LucideIcons.clock
            : LucideIcons.minus;
    final status = ok
        ? 'Verified'
        : configured
            ? 'Saved'
            : 'Not set up';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
                Text(status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: fg.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Webhook tile ──────────────────────────────────────────────────────────────

class _WebhookTile extends StatefulWidget {
  const _WebhookTile({required this.url});
  final String url;

  @override
  State<_WebhookTile> createState() => _WebhookTileState();
}

class _WebhookTileState extends State<_WebhookTile> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.url
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'^www\.'), '');

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Material(
        color: DashboardMockup.card,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _copy,
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
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: DashboardMockup.warnTint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(LucideIcons.link,
                      size: 20, color: DashboardMockup.warn),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Webhook URL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5, fontWeight: FontWeight.w700,
                            color: DashboardMockup.ink, height: 1.2)),
                      const SizedBox(height: 2),
                      Text(display,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, fontWeight: FontWeight.w500,
                            color: DashboardMockup.ink3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _copied
                        ? DashboardMockup.greenTint
                        : DashboardMockup.warnTint,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copied ? LucideIcons.check : LucideIcons.copy,
                        size: 14,
                        color: _copied
                            ? DashboardMockup.green700
                            : DashboardMockup.warn,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _copied ? 'Copied' : 'Copy',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _copied
                              ? DashboardMockup.green700
                              : DashboardMockup.warn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mode chip ─────────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? DashboardMockup.green900
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : DashboardMockup.line,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : onTap == null
                      ? DashboardMockup.ink3
                      : DashboardMockup.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.loading,
    required this.color,
    required this.onPressed,
    this.icon,
    this.textColor = Colors.white,
  });
  final String label;
  final IconData? icon;
  final bool loading;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: loading ? DashboardMockup.lineSoft : color,
          foregroundColor: loading ? DashboardMockup.ink3 : textColor,
          disabledBackgroundColor: DashboardMockup.lineSoft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: loading
                        ? DashboardMockup.ink3
                        : textColor))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17),
                    const SizedBox(width: 6),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: child,
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
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 1.2, color: DashboardMockup.ink3),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: const Color(0xFFF2C9C0)),
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.wifiOff,
                size: 32, color: DashboardMockup.ink3),
            const SizedBox(height: 12),
            Text('Could not load Paystack settings.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: DashboardMockup.ink),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5, color: DashboardMockup.ink2),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: DashboardMockup.greenTint,
                foregroundColor: DashboardMockup.green700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.refreshCw, size: 15),
                  SizedBox(width: 6),
                  Text('Try again'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Disconnect dialog ─────────────────────────────────────────────────────────

class _DisconnectDialog extends StatefulWidget {
  const _DisconnectDialog();

  @override
  State<_DisconnectDialog> createState() => _DisconnectDialogState();
}

class _DisconnectDialogState extends State<_DisconnectDialog> {
  final _ctrl = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text == 'DISCONNECT';
      if (ok != _confirmed) setState(() => _confirmed = ok);
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: DashboardMockup.dangerTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.x,
                color: DashboardMockup.danger, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Disconnect Paystack',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
              color: DashboardMockup.dangerTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DashboardMockup.danger.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'This removes your Paystack credentials. Payments will stop until you reconnect.',
              style: TextStyle(
                color: DashboardMockup.danger, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Type DISCONNECT to confirm:',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: DashboardMockup.ink)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('disconnect_confirm_input'),
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'DISCONNECT',
              errorText: _ctrl.text.isNotEmpty && !_confirmed
                  ? 'Type exactly: DISCONNECT'
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
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
          onPressed:
              _confirmed ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: DashboardMockup.danger,
            disabledBackgroundColor: DashboardMockup.dangerTint,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Disconnect'),
        ),
      ],
    );
  }
}
