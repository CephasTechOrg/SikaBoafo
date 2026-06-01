import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../settings/presentation/connect_paystack_screen.dart'
    show paystackConnectionProvider;
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

class BusinessSettingsSheet extends ConsumerStatefulWidget {
  const BusinessSettingsSheet({
    required this.initialContext,
    super.key,
  });

  final MerchantContext initialContext;

  @override
  ConsumerState<BusinessSettingsSheet> createState() =>
      _BusinessSettingsSheetState();
}

class _BusinessSettingsSheetState extends ConsumerState<BusinessSettingsSheet> {
  static const _defaultTimezones = <String>[
    'Africa/Accra',
    'Africa/Lagos',
    'Africa/Nairobi',
    'UTC',
  ];

  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _businessTypeCtrl;
  late final TextEditingController _storeNameCtrl;
  late final TextEditingController _storeLocationCtrl;
  late final List<String> _timezoneOptions;
  late String _timezone;

  bool _savingBusiness = false;
  bool _savingStore = false;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl =
        TextEditingController(text: widget.initialContext.businessName);
    _businessTypeCtrl =
        TextEditingController(text: widget.initialContext.businessType ?? '');
    _storeNameCtrl =
        TextEditingController(text: widget.initialContext.storeName);
    _storeLocationCtrl =
        TextEditingController(text: widget.initialContext.storeLocation ?? '');
    _timezoneOptions = [
      ..._defaultTimezones,
      if (!_defaultTimezones.contains(widget.initialContext.timezone))
        widget.initialContext.timezone,
    ];
    _timezone = widget.initialContext.timezone;
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _storeNameCtrl.dispose();
    _storeLocationCtrl.dispose();
    super.dispose();
  }

  static InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const radius = 28.0;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset + 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Material(
            color: AppColors.canvas,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
              ),
              child: Column(
                children: [
                  // ── Swirl hero + title ─────────────────────────────
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(radius),
                    ),
                    child: SizedBox(
                      height: 150,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Positioned.fill(child: HeroBackdrop()),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 10,
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 20, 8, 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.12),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Business profile',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.3,
                                                height: 1.15,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Identity, store defaults, and payments — kept in one place.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.78),
                                                fontWeight: FontWeight.w600,
                                                height: 1.35,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  MockupHeaderAction(
                                    icon: Icons.close_rounded,
                                    tooltip: 'Close',
                                    onTap: () => context.pop(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Form body ────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel(context, 'Business'),
                          const SizedBox(height: 10),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _businessNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Business name',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _businessTypeCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Business type',
                                    hint: 'e.g. retail, services',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AppButton.primary(
                                  label: 'Save business',
                                  icon: Icons.check_rounded,
                                  fullWidth: true,
                                  loading: _savingBusiness,
                                  onPressed:
                                      _savingBusiness ? null : _saveBusiness,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel(context, 'Shortcuts'),
                          const SizedBox(height: 10),
                          _ActionLinkTile(
                            icon: Icons.group_rounded,
                            iconBg: AppColors.successSoft,
                            iconColor: AppColors.forest,
                            title: 'Staff & team',
                            caption: 'Invite and manage access',
                            onTap: () {
                              context.pop();
                              context.push(AppRoute.staff.path);
                            },
                          ),
                          const SizedBox(height: 8),
                          Consumer(
                            builder: (context, ref, _) {
                              final connectionAsync = ref
                                  .watch(paystackConnectionProvider);
                              final connected =
                                  connectionAsync.valueOrNull?.isConnected ??
                                      false;
                              final mode = connectionAsync.valueOrNull?.mode;
                              return _ActionLinkTile(
                                icon: Icons.payments_outlined,
                                iconBg: AppColors.infoSoft,
                                iconColor: AppColors.navy,
                                title: 'Paystack',
                                caption: !connectionAsync.hasValue
                                    ? 'Loading status…'
                                    : connected
                                        ? 'Connected · ${mode == 'live' ? 'Live' : 'Test'}'
                                        : 'Not connected',
                                onTap: () {
                                  context.pop();
                                  context.push(AppRoute.paystack.path);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel(context, 'Default store'),
                          const SizedBox(height: 10),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _storeNameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Store name',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _storeLocationCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Location',
                                    hint: 'Address or area (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_timezone),
                                  initialValue: _timezone,
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Timezone',
                                  ),
                                  dropdownColor: AppColors.surface,
                                  items: _timezoneOptions
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _timezone = value);
                                  },
                                ),
                                const SizedBox(height: 16),
                                AppButton.primary(
                                  label: 'Save store',
                                  icon: Icons.place_rounded,
                                  fullWidth: true,
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
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
    );
  }

  Future<void> _saveBusiness() async {
    final businessName = _businessNameCtrl.text.trim();
    if (businessName.length < 2) {
      _showMessage('Business name must be at least 2 characters.');
      return;
    }

    setState(() => _savingBusiness = true);
    try {
      await ref.read(dashboardApiProvider).updateMerchantProfile(
            businessName: businessName,
            businessType: _businessTypeCtrl.text,
          );
      _invalidateDashboardState();
      if (!mounted) return;
      _showMessage('Business profile updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(humanizeDashboardError(error));
    } finally {
      if (mounted) {
        setState(() => _savingBusiness = false);
      }
    }
  }

  Future<void> _saveStore() async {
    final storeName = _storeNameCtrl.text.trim();
    if (storeName.length < 2) {
      _showMessage('Store name must be at least 2 characters.');
      return;
    }

    setState(() => _savingStore = true);
    try {
      await ref.read(dashboardApiProvider).updateDefaultStore(
            name: storeName,
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
      if (mounted) {
        setState(() => _savingStore = false);
      }
    }
  }

  void _invalidateDashboardState() {
    ref.invalidate(merchantContextProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardRecentActivityProvider);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: child,
    );
  }
}

class _ActionLinkTile extends StatelessWidget {
  const _ActionLinkTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
