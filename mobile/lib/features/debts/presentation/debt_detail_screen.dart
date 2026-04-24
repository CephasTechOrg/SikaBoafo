import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/sync_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/debts_repository.dart';
import '../providers/debts_providers.dart';
import 'receive_repayment_screen.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({
    required this.receivableId,
    super.key,
  });

  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(receivableDetailProvider(receivableId));
    final detail = detailAsync.valueOrNull;
    final statusColor =
        detail == null ? Colors.white : _statusColor(detail.record.status);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Column(
          children: [
            PremiumPageHeader(
              title: detail?.record.customerName ?? 'Debt Detail',
              subtitle: detail == null
                  ? 'Review balance, repayment history, and debt status.'
                  : 'Track this customer ledger without leaving the debt workflow.',
              leading: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              badge: PremiumBadge(
                label: detail == null
                    ? 'Debt record'
                    : _statusLabel(detail.record.status),
                icon: Icons.receipt_long_rounded,
                foreground: Colors.white,
                background: statusColor.withValues(alpha: 0.18),
              ),
            ),
            Expanded(
              child: PremiumSurface(
                child: detailAsync.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: const [
                      PremiumPanel(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ],
                  ),
                  error: (error, _) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _DetailErrorView(
                        message: _humanizeError(error),
                        onRetry: () => ref.invalidate(
                          receivableDetailProvider(receivableId),
                        ),
                      ),
                    ],
                  ),
                  data: (detail) {
                    if (detail == null) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: const [
                          PremiumEmptyState(
                            title: 'Debt record not found',
                            message:
                                'This receivable is no longer available in the active debt list.',
                            icon: Icons.search_off_rounded,
                          ),
                        ],
                      );
                    }
                    return _DetailBody(
                      detail: detail,
                      receivableId: receivableId,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.detail,
    required this.receivableId,
  });

  final LocalReceivableDetail detail;
  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = detail.record;
    final outstanding = '\u20B5${row.outstandingAmount}';
    final original = '\u20B5${row.originalAmount}';
    final paymentTotal = _formatMoney(
      ((double.tryParse(row.originalAmount) ?? 0) -
              (double.tryParse(row.outstandingAmount) ?? 0))
          .toStringAsFixed(2),
    );
    final canCollect = row.status == 'open' || row.status == 'partially_paid';

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(debtsControllerProvider.notifier).refresh();
        ref.invalidate(receivableDetailProvider(receivableId));
        await ref.read(receivableDetailProvider(receivableId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _BalanceHero(
            outstanding: outstanding,
            original: original,
            paid: '\u20B5$paymentTotal',
            dueDate: row.dueDateIso ?? 'Not set',
            invoiceNumber: row.invoiceNumber,
            status: row.status,
          ),
          if (canCollect) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 180,
                  child: FilledButton.icon(
                    onPressed: () => _openRepaymentScreen(context, ref),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Receive Payment'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancel(context, ref),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.danger,
                    ),
                    label: const Text(
                      'Cancel Debt',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSectionHeading(
                  title: 'Customer',
                  caption:
                      'Identity, contact, and sync information for this debt owner.',
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Name', value: row.customerName),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Phone',
                  value: detail.customerPhoneNumber ?? 'Not provided',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Created',
                  value: _formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis),
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Sync',
                  value: row.syncStatus,
                  valueColor: _syncColor(row.syncStatus),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSectionHeading(
                  title: 'Repayment History',
                  caption:
                      '${detail.paymentCount} payment${detail.paymentCount == 1 ? '' : 's'} recorded for this debt.',
                ),
                const SizedBox(height: 14),
                if (detail.payments.isEmpty)
                  const _InlineEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No repayments recorded yet',
                    message:
                        'Recorded collections will appear here in chronological order.',
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < detail.payments.length; i++) ...[
                        _PaymentCard(payment: detail.payments[i]),
                        if (i != detail.payments.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRepaymentScreen(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReceiveRepaymentScreen(receivableId: receivableId),
      ),
    );
    if (saved != true || !context.mounted) return;
    ref.invalidate(receivableDetailProvider(receivableId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Repayment saved.')),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Debt?'),
        content: const Text(
          'This will mark the debt as cancelled and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Debt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(debtsApiProvider).cancelReceivable(receivableId);
      if (!context.mounted) return;
      ref.invalidate(receivableDetailProvider(receivableId));
      await ref.read(debtsControllerProvider.notifier).refresh();
      if (!context.mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt cancelled.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final msg = _humanizeError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.outstanding,
    required this.original,
    required this.paid,
    required this.dueDate,
    required this.invoiceNumber,
    required this.status,
  });

  final String outstanding;
  final String original;
  final String paid;
  final String dueDate;
  final String? invoiceNumber;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF173A75), Color(0xFF0E2245)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Outstanding Balance',
                  style: TextStyle(
                    color: Color(0xFFD9E6FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(
                label: _statusLabel(status),
                foreground: _statusColor(status),
                background: Colors.white.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            outstanding,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 24) / 3
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _MetricTile(label: 'Original', value: original),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MetricTile(label: 'Paid', value: paid),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _MetricTile(label: 'Due date', value: dueDate),
                  ),
                  if (invoiceNumber != null && invoiceNumber!.isNotEmpty)
                    SizedBox(
                      width: itemWidth,
                      child:
                          _MetricTile(label: 'Invoice', value: invoiceNumber!),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9E6FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final LocalReceivablePaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final syncColor = _syncColor(payment.syncStatus);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B5${payment.amount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelizePaymentMethod(payment.paymentMethodLabel),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(
                      payment.createdAtMillis,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _StatusPill(
            label: payment.syncStatus,
            foreground: syncColor,
            background: syncColor.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
            ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.info, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: const Color(0xFFF2C9C0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _humanizeError(Object error) {
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Invalid input.';
  }
  final message = error.toString();
  return message.startsWith('Exception: ')
      ? message.substring('Exception: '.length)
      : message;
}

String _labelizePaymentMethod(String value) {
  return switch (value) {
    'mobile_money' => 'Mobile Money',
    'bank_transfer' => 'Bank Transfer',
    _ => 'Cash',
  };
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$month-$day $hour:$minute';
}

String _formatMoney(String value) {
  final parsed = double.tryParse(value) ?? 0;
  return parsed.toStringAsFixed(2);
}

String _statusLabel(String status) {
  return switch (status) {
    'settled' => 'Settled',
    'cancelled' => 'Cancelled',
    'partially_paid' => 'Partial',
    _ => 'Open',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'settled' => AppColors.success,
    'cancelled' => AppColors.muted,
    'partially_paid' => AppColors.warning,
    _ => AppColors.gold,
  };
}

Color _syncColor(String status) {
  return switch (status) {
    'applied' || 'duplicate' => AppColors.success,
    'failed' => AppColors.danger,
    'conflict' => AppColors.warning,
    'sending' => AppColors.sky,
    _ => AppColors.warning,
  };
}
