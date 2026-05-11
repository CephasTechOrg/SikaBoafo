import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../providers/debts_providers.dart';
import 'utils/debts_ui_tokens.dart';

class ReceiveRepaymentScreen extends ConsumerStatefulWidget {
  const ReceiveRepaymentScreen({required this.receivableId, super.key});

  final String receivableId;

  @override
  ConsumerState<ReceiveRepaymentScreen> createState() =>
      _ReceiveRepaymentScreenState();
}

class _ReceiveRepaymentScreenState
    extends ConsumerState<ReceiveRepaymentScreen> {
  final _formKey = GlobalKey<FormState>();
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
    final detailAsync =
        ref.watch(receivableDetailProvider(widget.receivableId));

    return MockupScreenScaffold(
      title: 'Receive Payment',
      subtitle: 'Record a repayment against this customer debt',
      onBack: () => context.pop(),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            detailAsync.when(
              loading: () => const _PaymentSummaryLoading(),
              error: (_, __) => const _PaymentSummaryError(),
              data: (detail) {
                if (detail == null) return const _PaymentSummaryError();
                final row = detail.record;
                return _RepaymentSummaryCard(
                  customerName: row.customerName,
                  outstandingAmount: _fmtMoney(row.outstandingAmount),
                  dueDate: _fmtDueDate(row.dueDateIso),
                  status: _statusLabel(row.status),
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DebtTokens.sheetSurface,
                borderRadius: BorderRadius.circular(DebtTokens.panelRadius),
                border: Border.all(color: DebtTokens.fieldBorder),
                boxShadow: DebtTokens.panel,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter the amount received and the method used.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateAmount,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: _screenInputDecoration(
                      label: 'Amount received',
                      hint: '0.00',
                      icon: Icons.receipt_long_rounded,
                      prefixText: '₵ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MethodChoice(
                        label: 'Cash',
                        icon: Icons.payments_rounded,
                        selected: _method == 'cash',
                        onTap: () => setState(() => _method = 'cash'),
                      ),
                      const SizedBox(width: 9),
                      _MethodChoice(
                        label: 'MoMo',
                        icon: Icons.smartphone_rounded,
                        selected: _method == 'mobile_money',
                        onTap: () => setState(() => _method = 'mobile_money'),
                      ),
                      const SizedBox(width: 9),
                      _MethodChoice(
                        label: 'Bank',
                        icon: Icons.account_balance_rounded,
                        selected: _method == 'bank_transfer',
                        onTap: () => setState(() => _method = 'bank_transfer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomBar: Container(
        decoration: const BoxDecoration(
          color: DebtTokens.sheetSurface,
          boxShadow: [
            BoxShadow(
              color: Color(0x11111827),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DebtTokens.buttonRadius),
              ),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _saving ? 'Saving Payment...' : 'Record Payment',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAmount(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter the amount received.';
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      return 'Enter a valid amount greater than 0.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: widget.receivableId,
            amount: _amountCtrl.text.trim(),
            paymentMethodLabel: _method,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RepaymentSummaryCard extends StatelessWidget {
  const _RepaymentSummaryCard({
    required this.customerName,
    required this.outstandingAmount,
    required this.dueDate,
    required this.status,
  });

  final String customerName;
  final String outstandingAmount;
  final String dueDate;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DebtTokens.paper,
        borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
        border: Border.all(color: DebtTokens.paperEdge),
        boxShadow: DebtTokens.receipt,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'OUTSTANDING BALANCE',
            style: TextStyle(
              color: DebtTokens.paperMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₵$outstandingAmount',
            style: const TextStyle(
              color: DebtTokens.hero800,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              height: 1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: DebtTokens.paperMuted, size: 17),
              const SizedBox(width: 7),
              Text(
                'Due $dueDate',
                style: const TextStyle(
                  color: DebtTokens.paperMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryLoading extends StatelessWidget {
  const _PaymentSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DebtTokens.sheetSurface,
        borderRadius: BorderRadius.circular(DebtTokens.panelRadius),
        border: Border.all(color: DebtTokens.fieldBorder),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2.4),
    );
  }
}

class _PaymentSummaryError extends StatelessWidget {
  const _PaymentSummaryError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DebtTokens.dangerSoft,
        borderRadius: BorderRadius.circular(DebtTokens.panelRadius),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: DebtTokens.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load debt details.',
              style: TextStyle(
                color: DebtTokens.dangerText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChoice extends StatelessWidget {
  const _MethodChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.forest.withValues(alpha: 0.08)
                : DebtTokens.fieldSurface,
            borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
            border: Border.all(
              color: selected ? AppColors.forest : DebtTokens.fieldBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? AppColors.forest : AppColors.muted,
                  size: 21),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.forest : AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _screenInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      color: AppColors.ink,
      fontSize: 18,
      fontWeight: FontWeight.w900,
    ),
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    filled: true,
    fillColor: DebtTokens.fieldSurface,
    errorMaxLines: 2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.fieldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.fieldBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DebtTokens.fieldRadius),
      borderSide: const BorderSide(color: DebtTokens.danger, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

String _fmtMoney(String value) {
  final parsed = double.tryParse(value) ?? 0;
  return parsed.toStringAsFixed(2);
}

String _fmtDueDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Not set';
  try {
    return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _statusLabel(String status) => switch (status) {
      'settled' => 'Settled',
      'cancelled' => 'Cancelled',
      'partially_paid' => 'Partial',
      _ => 'Open',
    };
