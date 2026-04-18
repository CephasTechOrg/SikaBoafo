import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailErrorView(
          message: _humanizeError(error),
          onRetry: () => ref.invalidate(receivableDetailProvider(receivableId)),
        ),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Debt record not found.'));
          }
          return _DetailBody(detail: detail, receivableId: receivableId);
        },
      ),
    );
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
    final outstanding = 'GHS ${row.outstandingAmount}';
    final original = 'GHS ${row.originalAmount}';
    final paymentTotal = _formatMoney(
      ((double.tryParse(row.originalAmount) ?? 0) -
              (double.tryParse(row.outstandingAmount) ?? 0))
          .toStringAsFixed(2),
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(debtsControllerProvider.notifier).refresh();
          ref.invalidate(receivableDetailProvider(receivableId));
          await ref.read(receivableDetailProvider(receivableId).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    detail.record.customerName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (detail.record.status == 'open')
                  FilledButton.icon(
                    onPressed: () => _openRepaymentScreen(context, ref),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Receive'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A6B5B), Color(0xFF12473E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                            color: Color(0xFFD7F3EA),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _Pill(
                        label: row.status == 'settled' ? 'Settled' : 'Open',
                        color: row.status == 'settled'
                            ? AppColors.success
                            : AppColors.gold,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroMetric(label: 'Original', value: original),
                      _HeroMetric(label: 'Paid', value: 'GHS $paymentTotal'),
                      _HeroMetric(
                        label: 'Due Date',
                        value: row.dueDateIso ?? 'Not set',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Name', value: row.customerName),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Phone',
                      value: detail.customerPhoneNumber ?? 'Not provided',
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Sync',
                      value: row.syncStatus,
                      valueColor: _syncColor(row.syncStatus),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Created',
                      value: _formatDateTime(
                        DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Repayment History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${detail.paymentCount} payment${detail.paymentCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (detail.payments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No repayments recorded yet.'),
                ),
              )
            else
              ...detail.payments.map(_buildPaymentCard),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(LocalReceivablePaymentRecord payment) {
    final syncColor = _syncColor(payment.syncStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.12),
          child: const Icon(Icons.payments_outlined, color: AppColors.success),
        ),
        title: Text(
          'GHS ${payment.amount}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${_labelizePaymentMethod(payment.paymentMethodLabel)} | ${_formatDateTime(DateTime.fromMillisecondsSinceEpoch(payment.createdAtMillis))}',
        ),
        trailing: _Pill(label: payment.syncStatus, color: syncColor),
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

  Color _syncColor(String status) {
    return switch (status) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      'sending' => AppColors.sky,
      _ => AppColors.warning,
    };
  }
}

class _RepaymentSheet extends ConsumerStatefulWidget {
  const _RepaymentSheet({required this.receivableId});

  final String receivableId;

  @override
  ConsumerState<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends ConsumerState<_RepaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receive Payment', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: 'e.g. 25.00',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _method = value);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: widget.receivableId,
            amount: _amountCtrl.text,
            paymentMethodLabel: _method,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7F3EA),
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
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
