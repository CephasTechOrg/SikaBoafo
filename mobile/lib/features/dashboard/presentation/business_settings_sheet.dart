import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';

class BusinessSettingsSheet extends ConsumerStatefulWidget {
  const BusinessSettingsSheet({
    required this.initialContext,
    super.key,
  });

  final MerchantContext initialContext;

  @override
  ConsumerState<BusinessSettingsSheet> createState() => _BusinessSettingsSheetState();
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
    _businessNameCtrl = TextEditingController(text: widget.initialContext.businessName);
    _businessTypeCtrl = TextEditingController(text: widget.initialContext.businessType ?? '');
    _storeNameCtrl = TextEditingController(text: widget.initialContext.storeName);
    _storeLocationCtrl = TextEditingController(text: widget.initialContext.storeLocation ?? '');
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
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Business Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Update the business profile and default store used across reports and summaries.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _SectionCard(
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
                  title: 'Staff Management',
                  subtitle: 'Invite and manage your team members.',
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        context.push(AppRoute.staff.path);
                      },
                      icon: const Icon(Icons.people_rounded),
                      label: const Text('Manage Staff'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Default Store',
                  subtitle: 'This affects location-specific context and dashboard timezone.',
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
          ),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
