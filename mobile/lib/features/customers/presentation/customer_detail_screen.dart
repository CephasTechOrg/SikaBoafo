import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';

final _customerDetailProvider = FutureProvider.family<_CustomerDetailViewData, String>(
  (ref, customerId) async {
    final repo = ref.read(debtsRepositoryProvider);
    final customer = await repo.getCustomerById(customerId);
    final receivables = await repo.listReceivablesForCustomer(customerId);
    return _CustomerDetailViewData(customer: customer, receivables: receivables);
  },
);

class _CustomerDetailViewData {
  const _CustomerDetailViewData({
    required this.customer,
    required this.receivables,
  });
  final LocalDebtCustomer? customer;
  final List<LocalReceivableRecord> receivables;
}

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_customerDetailProvider(customerId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        title: detailAsync.maybeWhen(
          data: (d) => Text(
            d.customer?.name ?? 'Customer',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          orElse: () => const Text('Customer'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_customerDetailProvider(customerId)),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(_customerDetailProvider(customerId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final customer = data.customer;
          if (customer == null) {
            return const Center(child: Text('Customer not found.'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_customerDetailProvider(customerId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _CustomerInfoCard(customer: customer),
                const SizedBox(height: 20),
                _ReceivablesSection(receivables: data.receivables),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.customer});

  final LocalDebtCustomer customer;

  @override
  Widget build(BuildContext context) {
    final outstanding = _parseAmount(customer.totalOutstanding);
    final hasOutstanding = outstanding > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.mint,
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasOutstanding
                              ? AppColors.dangerSoft
                              : AppColors.successSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hasOutstanding
                              ? 'Owes GHS ${customer.totalOutstanding}'
                              : 'All cleared',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasOutstanding
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (customer.phoneNumber != null ||
                customer.whatsappNumber != null ||
                customer.email != null ||
                customer.notes != null) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 14),
            ],
            if (customer.phoneNumber != null)
              _InfoRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: customer.phoneNumber!,
              ),
            if (customer.whatsappNumber != null)
              _InfoRow(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                value: customer.whatsappNumber!,
              ),
            if (customer.email != null)
              _InfoRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: customer.email!,
              ),
            if (customer.notes != null && customer.notes!.isNotEmpty)
              _InfoRow(
                icon: Icons.notes_rounded,
                label: 'Notes',
                value: customer.notes!,
              ),
          ],
        ),
      ),
    );
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivablesSection extends StatelessWidget {
  const _ReceivablesSection({required this.receivables});

  final List<LocalReceivableRecord> receivables;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Text(
                'Debts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${receivables.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (receivables.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No debts recorded for this customer.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            ),
          )
        else
          ...receivables.map((r) => _ReceivableCard(record: r)),
      ],
    );
  }
}

class _ReceivableCard extends StatelessWidget {
  const _ReceivableCard({required this.record});

  final LocalReceivableRecord record;

  @override
  Widget build(BuildContext context) {
    final isSettled = record.status == 'settled';
    final isOverdue = _isOverdue(record.dueDateIso);

    Color statusColor;
    Color statusBg;
    String statusLabel;
    if (isSettled) {
      statusColor = AppColors.success;
      statusBg = AppColors.successSoft;
      statusLabel = 'Settled';
    } else if (isOverdue) {
      statusColor = AppColors.danger;
      statusBg = AppColors.dangerSoft;
      statusLabel = 'Overdue';
    } else {
      statusColor = AppColors.warning;
      statusBg = AppColors.warningSoft;
      statusLabel = 'Open';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHS ${record.originalAmount}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (!isSettled) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Outstanding: GHS ${record.outstandingAmount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (record.dueDateIso != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Due: ${record.dueDateIso}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isOverdue ? AppColors.danger : AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(String? dueDateIso) {
    if (dueDateIso == null || dueDateIso.isEmpty) return false;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return dueDateIso.compareTo(todayStr) < 0;
  }
}
