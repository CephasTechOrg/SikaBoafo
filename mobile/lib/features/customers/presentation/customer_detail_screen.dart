import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/providers/debts_providers.dart';

final _customerDetailProvider =
    FutureProvider.family<_CustomerDetailViewData, String>(
  (ref, customerId) async {
    final repo = ref.read(debtsRepositoryProvider);
    final customer = await repo.getCustomerById(customerId);
    final receivables = await repo.listReceivablesForCustomer(customerId);
    return _CustomerDetailViewData(
        customer: customer, receivables: receivables);
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
    final detail = detailAsync.valueOrNull;
    final customer = detail?.customer;
    final receivables = detail?.receivables ?? const <LocalReceivableRecord>[];
    final outstandingMinor =
        customer == null ? 0 : _parseAmount(customer.totalOutstanding);
    final openCount = receivables
        .where((r) => r.status == 'open' || r.status == 'partially_paid')
        .length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: Column(
            children: [
              _CustomerDetailHeader(
                title: customer?.name ?? 'Customer',
                outstandingMinor: outstandingMinor,
                openCount: openCount,
                phoneNumber: customer?.phoneNumber,
                onBack: () => context.pop(),
                onRefresh: () =>
                    ref.invalidate(_customerDetailProvider(customerId)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: AppRadii.heroRadius,
                  ),
                  child: Container(
                    color: AppColors.canvas,
                    child: detailAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _DetailError(
                        message: e.toString(),
                        onRetry: () =>
                            ref.invalidate(_customerDetailProvider(customerId)),
                      ),
                      data: (data) {
                        final customer = data.customer;
                        if (customer == null) {
                          return const Center(
                            child: Text('Customer not found.'),
                          );
                        }
                        return RefreshIndicator(
                          onRefresh: () async => ref
                              .invalidate(_customerDetailProvider(customerId)),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                            children: [
                              _CustomerInfoCard(customer: customer),
                              const SizedBox(height: 18),
                              _ReceivablesSection(
                                  receivables: data.receivables),
                            ],
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

class _CustomerDetailHeader extends StatelessWidget {
  const _CustomerDetailHeader({
    required this.title,
    required this.outstandingMinor,
    required this.openCount,
    required this.phoneNumber,
    required this.onBack,
    required this.onRefresh,
  });

  final String title;
  final int outstandingMinor;
  final int openCount;
  final String? phoneNumber;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final cleared = outstandingMinor == 0;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phoneNumber ?? 'Customer balance and debt history',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                      cleared ? 'Cleared' : _formatMinor(outstandingMinor),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: cleared ? 28 : 31,
                        fontWeight: FontWeight.w800,
                        fontFamily: cleared ? null : 'Constantia',
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cleared
                          ? 'No outstanding balance'
                          : 'Current outstanding balance',
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
                      label: 'Open debts',
                      value: '$openCount active',
                      tone: const Color(0xFF9AE7BF),
                    ),
                    const SizedBox(height: 8),
                    _HeaderMiniMetric(
                      label: 'Status',
                      value: cleared ? 'Settled' : 'Needs follow-up',
                      tone: cleared ? AppColors.gold : const Color(0xFFF6A6A6),
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

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.customer});

  final LocalDebtCustomer customer;

  @override
  Widget build(BuildContext context) {
    final outstanding = _parseAmount(customer.totalOutstanding);
    final hasOutstanding = outstanding > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
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
                            ? 'Owes ${_formatMinor(outstanding)}'
                            : 'All cleared',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
    );
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
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
        Row(
          children: [
            const Text(
              'Debt History',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        const SizedBox(height: 10),
        if (receivables.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No debts recorded for this customer.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
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
    final isCancelled = record.status == 'cancelled';
    final isOverdue =
        !isSettled && !isCancelled && _isOverdue(record.dueDateIso);

    final (statusLabel, statusColor, statusBg) = switch (record.status) {
      'settled' => ('Settled', AppColors.success, AppColors.successSoft),
      'cancelled' => ('Cancelled', AppColors.muted, AppColors.surfaceAlt),
      'partially_paid' => ('Partial', AppColors.warning, AppColors.warningSoft),
      _ when isOverdue => ('Overdue', AppColors.danger, AppColors.dangerSoft),
      _ => ('Open', AppColors.warning, AppColors.warningSoft),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (!isSettled && !isCancelled) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Outstanding: GHS ${record.outstandingAmount}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (record.invoiceNumber != null &&
                    record.invoiceNumber!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    record.invoiceNumber!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (record.dueDateIso != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Due: ${record.dueDateIso}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? AppColors.danger : AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({
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

bool _isOverdue(String? dueDateIso) {
  if (dueDateIso == null || dueDateIso.isEmpty) return false;
  final today = DateTime.now();
  final dueDate = DateTime.tryParse(dueDateIso);
  if (dueDate == null) return false;
  return DateTime(today.year, today.month, today.day)
      .isAfter(DateTime(dueDate.year, dueDate.month, dueDate.day));
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
