import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../shared/utils/user_friendly_error.dart';
import '../../../data/models/local_receivable_record.dart';
import '../../../providers/debts_providers.dart';
import '../../utils/debts_ui_utils.dart';
import 'receive_payment_amount_field.dart';
import 'receive_payment_confirm_button.dart';
import 'receive_payment_method_selector.dart';

/// Records a manual repayment (cash / MoMo / bank transfer). Validates
/// `amount <= outstanding` locally and submits via the offline-first
/// `recordRepayment` controller method.
class ReceivePaymentSheet extends ConsumerStatefulWidget {
  const ReceivePaymentSheet({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  ConsumerState<ReceivePaymentSheet> createState() =>
      _ReceivePaymentSheetState();
}

class _ReceivePaymentSheetState extends ConsumerState<ReceivePaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  bool _submitting = false;
  String? _error;

  late final int _outstandingMinor =
      DebtsUiUtils.amountToMinor(widget.record.outstandingAmount);

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _amountValid {
    final minor = DebtsUiUtils.amountToMinor(_amountCtrl.text);
    return minor > 0 && minor <= _outstandingMinor;
  }

  Future<void> _submit() async {
    final raw = _amountCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter the amount received.');
      return;
    }
    final minor = DebtsUiUtils.amountToMinor(raw);
    if (minor <= 0) {
      setState(() => _error = 'Amount must be greater than 0.');
      return;
    }
    if (minor > _outstandingMinor) {
      setState(() => _error = 'Amount cannot exceed the outstanding balance.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(debtsControllerProvider.notifier).recordRepayment(
            receivableId: widget.record.receivableId,
            amount: raw,
            paymentMethodLabel: _method,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded ${DebtsUiUtils.formatMinor(minor)} (${DebtsUiUtils.paymentMethodLabel(_method)}).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.elevated,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receive payment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Outstanding: ${DebtsUiUtils.formatMinor(_outstandingMinor)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ReceivePaymentAmountField(
                    controller: _amountCtrl,
                    outstandingMinor: _outstandingMinor,
                    onQuickFill: (value) {
                      _amountCtrl.text = value;
                      _amountCtrl.selection = TextSelection.collapsed(
                        offset: _amountCtrl.text.length,
                      );
                      setState(() => _error = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  ReceivePaymentMethodSelector(
                    selected: _method,
                    onChanged: (value) => setState(() => _method = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!_amountValid && _amountCtrl.text.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Enter the amount received above to continue.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                  ReceivePaymentConfirmButton(
                    enabled: _amountValid,
                    submitting: _submitting,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience launcher.
Future<bool?> showReceivePaymentSheet(
  BuildContext context, {
  required LocalReceivableRecord record,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => ReceivePaymentSheet(record: record),
  );
}
