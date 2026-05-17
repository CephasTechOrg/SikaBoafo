import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/utils/user_friendly_error.dart';
import '../../../data/models/local_receivable_record.dart';
import '../../../providers/debts_providers.dart';
import '../debt_payment_link_panel.dart';
import '../../utils/debts_ui_tokens.dart';
import '../../utils/debts_ui_utils.dart';
import 'receive_payment_amount_field.dart';
import 'receive_payment_confirm_button.dart';
import 'receive_payment_method_selector.dart';

/// Records a manual *cash* repayment, or exposes online collection (QR / link /
/// MoMo) in a second tab. Online payments still flow through Paystack-backed
/// links so we avoid double-booking on the manual path.
class ReceivePaymentSheet extends ConsumerStatefulWidget {
  const ReceivePaymentSheet({super.key, required this.record});

  final LocalReceivableRecord record;

  @override
  ConsumerState<ReceivePaymentSheet> createState() =>
      _ReceivePaymentSheetState();
}

enum _ReceiveMode { inPerson, payOnline }

class _ReceivePaymentSheetState extends ConsumerState<ReceivePaymentSheet> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  bool _submitting = false;
  String? _error;
  _ReceiveMode _mode = _ReceiveMode.inPerson;

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
              color: DebtsUi.surface,
              borderRadius: BorderRadius.circular(DebtsUi.radiusXl),
              border: Border.all(color: DebtsUi.border, width: 1.5),
              boxShadow: DebtsUi.shadowLg,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: DebtsUi.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receive payment',
                              style: TextStyle(
                                fontFamily: 'Constantia',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: DebtsUi.textPrimary,
                                letterSpacing: -0.3,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Outstanding: ${DebtsUiUtils.formatMinor(_outstandingMinor)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: DebtsUi.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ReceivePaymentModeToggle(
                    mode: _mode,
                    onChanged: (mode) {
                      FocusScope.of(context).unfocus();
                      setState(() => _mode = mode);
                    },
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: DebtsUiTokens.tabSwitchAnimation,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _mode == _ReceiveMode.inPerson
                        ? _InPersonReceiveBody(
                            key: const ValueKey('in_person'),
                            amountCtrl: _amountCtrl,
                            outstandingMinor: _outstandingMinor,
                            method: _method,
                            submitting: _submitting,
                            errorText: _error,
                            amountValid: _amountValid,
                            onMethodChanged: (v) => setState(() => _method = v),
                            onAmountQuickFill: (value) {
                              _amountCtrl.text = value;
                              _amountCtrl.selection = TextSelection.collapsed(
                                offset: _amountCtrl.text.length,
                              );
                              setState(() => _error = null);
                            },
                            onSubmit: _submit,
                          )
                        : Padding(
                            key: const ValueKey('pay_online'),
                            padding: const EdgeInsets.only(top: 4),
                            child: DebtPaymentLinkPanel(
                              record: widget.record,
                              compact: true,
                            ),
                          ),
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

class _ReceivePaymentModeToggle extends StatelessWidget {
  const _ReceivePaymentModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final _ReceiveMode mode;
  final ValueChanged<_ReceiveMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DebtsUi.greenPale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DebtsUi.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'In person',
              icon: Icons.payments_rounded,
              selected: mode == _ReceiveMode.inPerson,
              onTap: () => onChanged(_ReceiveMode.inPerson),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeChip(
              label: 'Pay online',
              icon: Icons.qr_code_rounded,
              selected: mode == _ReceiveMode.payOnline,
              onTap: () => onChanged(_ReceiveMode.payOnline),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: DebtsUiTokens.tabSwitchAnimation,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: selected ? DebtsUi.heroGradient : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x220D3D2B),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : DebtsUi.textSecondary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : DebtsUi.textSecondary,
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

class _InPersonReceiveBody extends StatelessWidget {
  const _InPersonReceiveBody({
    super.key,
    required this.amountCtrl,
    required this.outstandingMinor,
    required this.method,
    required this.submitting,
    required this.errorText,
    required this.amountValid,
    required this.onMethodChanged,
    required this.onAmountQuickFill,
    required this.onSubmit,
  });

  final TextEditingController amountCtrl;
  final int outstandingMinor;
  final String method;
  final bool submitting;
  final String? errorText;
  final bool amountValid;
  final ValueChanged<String> onMethodChanged;
  final ValueChanged<String> onAmountQuickFill;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceivePaymentAmountField(
          controller: amountCtrl,
          outstandingMinor: outstandingMinor,
          onQuickFill: onAmountQuickFill,
        ),
        const SizedBox(height: 16),
        ReceivePaymentMethodSelector(
          selected: method,
          onChanged: onMethodChanged,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12.5,
              color: DebtsUi.danger,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (!amountValid && amountCtrl.text.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Enter the amount received above to continue.',
              style: TextStyle(
                fontSize: 12,
                color: DebtsUi.textMuted,
              ),
            ),
          ),
        ],
        ReceivePaymentConfirmButton(
          enabled: amountValid,
          submitting: submitting,
          onTap: onSubmit,
        ),
      ],
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
