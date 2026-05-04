import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';
import 'widgets/customers_header.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsControllerProvider);
    final customers =
        debtsAsync.valueOrNull?.customers ?? const <LocalDebtCustomer>[];

    final outstandingMinor = customers.fold<int>(
      0,
      (sum, customer) => sum + _parseAmount(customer.totalOutstanding),
    );
    final clearedCount =
        customers.where((c) => _parseAmount(c.totalOutstanding) == 0).length;
    final withDebtCount =
        customers.where((c) => _parseAmount(c.totalOutstanding) > 0).length;

    const kLeadingGutter = 56.0;

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
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () {
                if (ModalRoute.of(context)?.canPop ?? false) {
                  context.pop();
                } else {
                  context.go(AppRoute.home.path);
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Add customer',
                icon: const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 22),
                onPressed: () =>
                    _showAddCustomerBottomSheet(context, ref),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
                onPressed: () =>
                    ref.read(debtsControllerProvider.notifier).refresh(),
              ),
            ],
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: CustomersHeader(
                leadingContentInset: kLeadingGutter,
                outstandingMinor: outstandingMinor,
                customerCount: customers.length,
                clearedCount: clearedCount,
                withDebtCount: withDebtCount,
              ),
              title: innerBoxIsScrolled
                  ? const Text(
                      'Customers',
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
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: debtsAsync.when(
            loading: () => RefreshIndicator(
              onRefresh: () =>
                  ref.read(debtsControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const StaleBanner(
                    screenKey: 'customers',
                    kvKey: KvCacheRepository.kDebtsTs,
                  ),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
                  const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            error: (e, _) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(debtsControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  const StaleBanner(
                    screenKey: 'customers',
                    kvKey: KvCacheRepository.kDebtsTs,
                  ),
                  const SizedBox(height: 24),
                  _CustomersError(
                    message: e.toString(),
                    onRetry: () =>
                        ref.read(debtsControllerProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
            data: (viewData) {
              final items = viewData.customers;
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(debtsControllerProvider.notifier).refresh(),
                child: PremiumSurface(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      const StaleBanner(
                        screenKey: 'customers',
                        kvKey: KvCacheRepository.kDebtsTs,
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        _EmptyCustomers(
                          onAddCustomer: () =>
                              _showAddCustomerBottomSheet(context, ref),
                        )
                      else
                        ...items.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CustomerCard(customer: c),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final LocalDebtCustomer customer;

  @override
  Widget build(BuildContext context) {
    final outstanding = _parseAmount(customer.totalOutstanding);
    final hasOutstanding = outstanding > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/customers/${customer.customerId}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.mutedSoft,
                        ),
                      ],
                    ),
                    if (customer.phoneNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer.phoneNumber!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: hasOutstanding
                                ? AppColors.dangerSoft
                                : AppColors.successSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            hasOutstanding
                                ? _formatMinor(outstanding)
                                : 'Cleared',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hasOutstanding
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tap to view customer ledger',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomersError extends StatelessWidget {
  const _CustomersError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.onAddCustomer});

  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 34,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No customers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a customer to track balances and repayment history. You can also record debts from the Debts screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text('Add customer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestDark,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showAddCustomerBottomSheet(BuildContext context, WidgetRef _) {
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Consumer(
          builder: (_, ref, __) {
            return _AddCustomerBottomSheet(
              onClose: () => Navigator.of(sheetContext).pop(),
              onSuccessMessage: (msg) {
                messenger.showSnackBar(SnackBar(content: Text(msg)));
              },
            );
          },
        ),
      );
    },
  );
}

class _AddCustomerBottomSheet extends ConsumerStatefulWidget {
  const _AddCustomerBottomSheet({
    required this.onClose,
    required this.onSuccessMessage,
  });

  final VoidCallback onClose;
  final void Function(String message) onSuccessMessage;

  @override
  ConsumerState<_AddCustomerBottomSheet> createState() =>
      _AddCustomerBottomSheetState();
}

class _AddCustomerBottomSheetState
    extends ConsumerState<_AddCustomerBottomSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _humanize(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid input.';
    }
    final s = error.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer name must be at least 2 characters.'),
        ),
      );
      return;
    }
    final phoneRaw = _phoneCtrl.text.trim();
    setState(() => _saving = true);
    try {
      await ref.read(debtsControllerProvider.notifier).createCustomer(
            name: name,
            phoneNumber: phoneRaw.isEmpty ? null : phoneRaw,
            useLoadingState: false,
          );
      if (!mounted) return;
      widget.onSuccessMessage('Customer saved.');
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanize(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'New customer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Name and optional phone — same as on the Debts screen.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          _CustomerFormField(
            controller: _nameCtrl,
            label: 'Customer name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          _CustomerFormField(
            controller: _phoneCtrl,
            label: 'Phone (optional)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save customer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forestDark,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerFormField extends StatelessWidget {
  const _CustomerFormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

int _parseAmount(String value) {
  final raw = value.trim();
  final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (match == null) return 0;
  final parts = raw.split('.');
  final major = int.parse(parts[0]);
  final dec = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + int.parse(dec);
}

String _formatMinor(int minor) {
  final major = minor ~/ 100;
  final cents = (minor % 100).toString().padLeft(2, '0');
  return '₵$major.$cents';
}
