import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/streak_hero_header.dart';
import 'connect_paystack_screen.dart' show paystackConnectionProvider;
import '../../dashboard/data/dashboard_api.dart';
import '../../dashboard/providers/dashboard_providers.dart';

class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() =>
      _BusinessProfileScreenState();
}

class _SheetCap extends StatelessWidget {
  const _SheetCap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: AppRadii.heroRadius),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  static const _defaultTimezones = <String>[
    'Africa/Accra',
    'Africa/Lagos',
    'Africa/Nairobi',
    'UTC',
  ];

  final TextEditingController _businessNameCtrl = TextEditingController();
  final TextEditingController _businessTypeCtrl = TextEditingController();
  final TextEditingController _storeNameCtrl = TextEditingController();
  final TextEditingController _storeLocationCtrl = TextEditingController();

  bool _hydrated = false;
  List<String> _timezoneOptions = _defaultTimezones;
  String _timezone = 'Africa/Accra';

  bool _savingBusiness = false;
  bool _savingStore = false;

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

  void _hydrate(MerchantContext mc) {
    if (_hydrated) return;
    _hydrated = true;
    _businessNameCtrl.text = mc.businessName;
    _businessTypeCtrl.text = mc.businessType ?? '';
    _storeNameCtrl.text = mc.storeName;
    _storeLocationCtrl.text = mc.storeLocation ?? '';
    _timezoneOptions = [
      ..._defaultTimezones,
      if (!_defaultTimezones.contains(mc.timezone)) mc.timezone,
    ];
    _timezone = mc.timezone;
  }

  @override
  Widget build(BuildContext context) {
    final mcAsync = ref.watch(merchantContextProvider);
    final mc = mcAsync.valueOrNull;
    if (mc != null) _hydrate(mc);

    const kLeadingGutter = 56.0;
    final subtitle = mc?.businessName ?? 'Store settings and payments';

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
            actions: [
              IconButton(
                tooltip: 'Staff',
                icon: const Icon(Icons.group_outlined,
                    color: Colors.white, size: 22),
                onPressed: () => context.push(AppRoute.staff.path),
              ),
              IconButton(
                tooltip: 'Paystack',
                icon: const Icon(Icons.payment_outlined,
                    color: Colors.white, size: 22),
                onPressed: () => context.push(AppRoute.paystack.path),
              ),
            ],
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: StreakHeroHeader(
                leadingContentInset: kLeadingGutter,
                title: 'Business Profile',
                subtitle: subtitle,
                badge: const PremiumBadge(
                  label: 'Business & store',
                  icon: Icons.business_outlined,
                  foreground: Colors.white,
                  background: Color(0x24FFFFFF),
                ),
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Business Profile',
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
          const SliverToBoxAdapter(child: _SheetCap()),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: mcAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.forest,
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: AppCard(
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Could not load business profile',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.toString(),
                        style:
                            const TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                      const SizedBox(height: 12),
                      AppButton.secondary(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        onPressed: () => ref.invalidate(merchantContextProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
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
                          onPressed: _savingBusiness ? null : _saveBusiness,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel(context, 'Payments'),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final connectionAsync =
                          ref.watch(paystackConnectionProvider);
                      final connected =
                          connectionAsync.valueOrNull?.isConnected ?? false;
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
                        onTap: () => context.push(AppRoute.paystack.path),
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
                                        fontWeight: FontWeight.w600),
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
      if (mounted) setState(() => _savingBusiness = false);
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
                        fontSize: 14.5,
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

