import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return PremiumSheetFrame(
      title: 'Business Settings',
      subtitle:
          'Update the business profile and default store used across reports and summaries.',
      bottomInset: bottomInset,
      badge: const PremiumBadge(
        label: 'Dashboard',
        icon: Icons.tune_rounded,
        foreground: AppColors.navy,
        background: AppColors.infoSoft,
      ),
      trailing: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.close_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            icon: Icons.storefront_rounded,
            iconColor: AppColors.navy,
            title: 'Business Profile',
            subtitle: 'This updates your merchant identity.',
            child: Column(
              children: [
                TextField(
                  controller: _businessNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _businessTypeCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Business type (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingBusiness ? null : _saveBusiness,
                    icon: _savingBusiness
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.storefront_rounded),
                    label: const Text('Save Business'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.people_alt_rounded,
            iconColor: AppColors.forest,
            title: 'Staff Management',
            subtitle: 'Invite and manage your team members.',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.pop();
                  context.push(AppRoute.staff.path);
                },
                icon: const Icon(Icons.people_rounded),
                label: const Text('Manage Staff'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PaymentSettingsCard(
            onNavigate: () {
              context.pop();
              context.push(AppRoute.paystack.path);
            },
          ),
          const SizedBox(height: 14),
          _SectionCard(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.warning,
            title: 'Default Store',
            subtitle:
                'This affects location-specific context and dashboard timezone.',
            child: Column(
              children: [
                TextField(
                  controller: _storeNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Store name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _storeLocationCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Store location (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  decoration: const InputDecoration(labelText: 'Timezone'),
                  items: _timezoneOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _timezone = value);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingStore ? null : _saveStore,
                    icon: _savingStore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.place_rounded),
                    label: const Text('Save Store'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PaymentSettingsCard extends ConsumerWidget {
  const _PaymentSettingsCard({required this.onNavigate});

  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(paystackConnectionProvider);
    final isConnected = connectionAsync.valueOrNull?.isConnected ?? false;
    final mode = connectionAsync.valueOrNull?.mode;

    return _SectionCard(
      icon: Icons.account_balance_wallet_rounded,
      iconColor: AppColors.navy,
      title: 'Payment Settings',
      subtitle: 'Connect Paystack and manage collection mode.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (connectionAsync.hasValue)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isConnected ? AppColors.successSoft : AppColors.warningSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isConnected
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: isConnected ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? 'Connected · ${mode == 'live' ? 'Live mode' : 'Test mode'}'
                        : 'Not connected',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isConnected ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.link_rounded),
              label: Text(isConnected ? 'Manage Paystack' : 'Connect Paystack'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
