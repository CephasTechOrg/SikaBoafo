import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../app/router.dart';
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import 'connect_paystack_screen.dart' show paystackConnectionProvider;

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _BusinessProfileScreenState
    extends ConsumerState<BusinessProfileScreen> {
  static const _defaultTimezones = <String>[
    'Africa/Accra',
    'Africa/Lagos',
    'Africa/Nairobi',
    'UTC',
  ];

  final _businessNameCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _storeNameCtrl    = TextEditingController();
  final _storeLocationCtrl = TextEditingController();

  bool   _hydrated       = false;
  List<String> _timezoneOptions = _defaultTimezones;
  String _timezone       = 'Africa/Accra';
  bool   _savingBusiness = false;
  bool   _savingStore    = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _storeNameCtrl.dispose();
    _storeLocationCtrl.dispose();
    super.dispose();
  }

  void _hydrate(MerchantContext mc) {
    if (_hydrated) return;
    _hydrated = true;
    _businessNameCtrl.text  = mc.businessName;
    _businessTypeCtrl.text  = mc.businessType ?? '';
    _storeNameCtrl.text     = mc.storeName;
    _storeLocationCtrl.text = mc.storeLocation ?? '';
    _timezoneOptions = [
      ..._defaultTimezones,
      if (!_defaultTimezones.contains(mc.timezone)) mc.timezone,
    ];
    _timezone = mc.timezone;
  }

  static InputDecoration _field(String label, {String? hint}) {
    final borderRadius = BorderRadius.circular(14);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: DashboardMockup.ink3, fontSize: 14.5),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(
        color: DashboardMockup.ink3,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: DashboardMockup.green700,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: DashboardMockup.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: DashboardMockup.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide:
            const BorderSide(color: DashboardMockup.green700, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcAsync   = ref.watch(merchantContextProvider);
    final mc        = mcAsync.valueOrNull;
    if (mc != null) _hydrate(mc);

    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final subtitle  = mc?.businessName ?? 'Account & store settings';

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              DashboardMockup.gutter, topPad + 14,
              DashboardMockup.gutter, 0,
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
                        'Business Profile',
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

          // ── Content ─────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              DashboardMockup.gutter, 24,
              DashboardMockup.gutter, bottomPad + 32,
            ),
            child: mcAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: DashboardMockup.green700,
                    ),
                  ),
                ),
              ),
              error: (e, _) => _ErrorCard(
                message: humanizeDashboardError(e),
                onRetry: () => ref.invalidate(merchantContextProvider),
              ),
              data: (_) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Business ─────────────────────────────────────────
                  const _SecLabel('Business'),
                  const SizedBox(height: 12),
                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _businessNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DashboardMockup.ink,
                          ),
                          decoration: _field('Business name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _businessTypeCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DashboardMockup.ink,
                          ),
                          decoration: _field(
                            'Business type',
                            hint: 'e.g. Retail, Services',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SaveButton(
                          label: 'Save business',
                          icon: LucideIcons.check,
                          loading: _savingBusiness,
                          onPressed: _savingBusiness ? null : _saveBusiness,
                        ),
                      ],
                    ),
                  ),

                  // ── Payments ─────────────────────────────────────────
                  const SizedBox(height: 24),
                  const _SecLabel('Payments'),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final connectionAsync =
                          ref.watch(paystackConnectionProvider);
                      final connected =
                          connectionAsync.valueOrNull?.isConnected ?? false;
                      final mode = connectionAsync.valueOrNull?.mode;
                      final caption = !connectionAsync.hasValue
                          ? 'Loading status…'
                          : connected
                              ? 'Connected · ${mode == 'live' ? 'Live' : 'Test'}'
                              : 'Not connected — tap to set up';
                      return _LinkTile(
                        icon: LucideIcons.creditCard,
                        iconBg: DashboardMockup.warnTint,
                        iconColor: DashboardMockup.warn,
                        label: 'Paystack',
                        sub: caption,
                        onTap: () => context.push(AppRoute.paystack.path),
                      );
                    },
                  ),

                  // ── Default store ─────────────────────────────────────
                  const SizedBox(height: 24),
                  const _SecLabel('Default store'),
                  const SizedBox(height: 12),
                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _storeNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DashboardMockup.ink,
                          ),
                          decoration: _field('Store name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _storeLocationCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: DashboardMockup.ink,
                          ),
                          decoration: _field(
                            'Location',
                            hint: 'Address or area (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_timezone),
                          initialValue: _timezone,
                          decoration: _field('Timezone'),
                          dropdownColor: DashboardMockup.card,
                          borderRadius: BorderRadius.circular(16),
                          items: _timezoneOptions
                              .map(
                                (tz) => DropdownMenuItem(
                                  value: tz,
                                  child: Text(
                                    tz,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: DashboardMockup.ink,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _timezone = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        _SaveButton(
                          label: 'Save store',
                          icon: LucideIcons.mapPin,
                          loading: _savingStore,
                          onPressed: _savingStore ? null : _saveStore,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBusiness() async {
    final name = _businessNameCtrl.text.trim();
    if (name.length < 2) {
      _showMessage('Business name must be at least 2 characters.');
      return;
    }
    setState(() => _savingBusiness = true);
    try {
      await ref.read(dashboardApiProvider).updateMerchantProfile(
            businessName: name,
            businessType: _businessTypeCtrl.text,
          );
      _invalidateDashboardState();
      if (!mounted) return;
      _showMessage('Business profile updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(humanizeDashboardError(error));
    } finally {
      if (mounted) setState(() => _savingBusiness = false);
    }
  }

  Future<void> _saveStore() async {
    final name = _storeNameCtrl.text.trim();
    if (name.length < 2) {
      _showMessage('Store name must be at least 2 characters.');
      return;
    }
    setState(() => _savingStore = true);
    try {
      await ref.read(dashboardApiProvider).updateDefaultStore(
            name: name,
            location: _storeLocationCtrl.text,
            timezone: _timezone,
          );
      _invalidateDashboardState();
      if (!mounted) return;
      _showMessage('Default store updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(humanizeDashboardError(error));
    } finally {
      if (mounted) setState(() => _savingStore = false);
    }
  }

  void _invalidateDashboardState() {
    ref.invalidate(merchantContextProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardRecentActivityProvider);
    ref.invalidate(dashboardInsightsProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ── Form card container ───────────────────────────────────────────────────────

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

// ── Link tile (Paystack) ──────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                        maxLines: 1,
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

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor:
              enabled ? DashboardMockup.green600 : DashboardMockup.lineSoft,
          foregroundColor:
              enabled ? Colors.white : DashboardMockup.ink3,
          disabledBackgroundColor: DashboardMockup.lineSoft,
          disabledForegroundColor: DashboardMockup.ink3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DashboardMockup.green700,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DashboardMockup.card,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        border: Border.all(color: const Color(0xFFF2C9C0)),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertCircle,
                color: DashboardMockup.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Could not load business profile',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DashboardMockup.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: DashboardMockup.ink2,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: DashboardMockup.greenTint,
                foregroundColor: DashboardMockup.green700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
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
          ),
        ],
      ),
    );
  }
}
