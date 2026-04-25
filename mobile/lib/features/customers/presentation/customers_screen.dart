import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';

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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: Column(
            children: [
              _CustomersHeader(
                customerCount: customers.length,
                outstandingMinor: outstandingMinor,
                clearedCount: clearedCount,
                onBack: () => context.pop(),
                onRefresh: () =>
                    ref.read(debtsControllerProvider.notifier).refresh(),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: AppRadii.heroRadius,
                  ),
                  child: Container(
                    color: AppColors.canvas,
                    child: debtsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _CustomersError(
                        message: e.toString(),
                        onRetry: () => ref
                            .read(debtsControllerProvider.notifier)
                            .refresh(),
                      ),
                      data: (viewData) {
                        final items = viewData.customers;
                        return RefreshIndicator(
                          onRefresh: () => ref
                              .read(debtsControllerProvider.notifier)
                              .refresh(),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                            itemCount: items.isEmpty ? 1 : items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (items.isEmpty) {
                                return const _EmptyCustomers();
                              }
                              return _CustomerCard(customer: items[index]);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomersHeader extends StatelessWidget {
  const _CustomersHeader({
    required this.customerCount,
    required this.outstandingMinor,
    required this.clearedCount,
    required this.onBack,
    required this.onRefresh,
  });

  final int customerCount;
  final int outstandingMinor;
  final int clearedCount;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View customer balances and debt relationships',
                      style: TextStyle(
                        color: Color(0xFFC7D0E5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMinor(outstandingMinor),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Constantia',
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Outstanding customer balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 138,
                child: Column(
                  children: [
                    _HeaderMiniMetric(
                      label: 'Customers',
                      value: '$customerCount total',
                      tone: const Color(0xFF9AE7BF),
                    ),
                    const SizedBox(height: 8),
                    _HeaderMiniMetric(
                      label: 'Cleared',
                      value: '$clearedCount settled',
                      tone: AppColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMiniMetric extends StatelessWidget {
  const _HeaderMiniMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: tone,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
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
  const _EmptyCustomers();

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
            'Create customers from the Debts screen so you can track balances and repayment history here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
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
