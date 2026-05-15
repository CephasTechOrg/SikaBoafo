import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/local_debt_customer.dart';
import '../../utils/debts_ui_tokens.dart';
import '../../utils/debts_ui_utils.dart';
import '../debts_gradient_button.dart';

/// Step 2 of the new-debt flow: amount, optional due date, optional note.
/// The selected customer is shown at the top with a "change" affordance.
/// Styled with the shared debts mockup design language.
class DebtFormStep extends StatefulWidget {
  const DebtFormStep({
    super.key,
    required this.customer,
    required this.onChangeCustomer,
    required this.onSubmit,
  });

  final LocalDebtCustomer customer;
  final VoidCallback onChangeCustomer;

  /// Caller awaits the repository write and dismisses the host sheet.
  final Future<void> Function({
    required String amount,
    String? dueDateIso,
    String? note,
  }) onSubmit;

  @override
  State<DebtFormStep> createState() => _DebtFormStepState();
}

class _DebtFormStepState extends State<DebtFormStep> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 5, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: DebtsUi.greenMid,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    final amount = _amountCtrl.text.trim();
    if (amount.isEmpty) {
      setState(() => _error = 'Enter the debt amount.');
      return;
    }
    final minor = DebtsUiUtils.amountToMinor(amount);
    if (minor <= 0) {
      setState(() => _error = 'Amount must be greater than 0.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final dueIso = _dueDate == null
          ? null
          : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day)
              .toIso8601String()
              .substring(0, 10);
      await widget.onSubmit(
        amount: amount,
        dueDateIso: dueIso,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Debt details',
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
        const Text(
          'How much is owed, and when is it due?',
          style: TextStyle(
            fontSize: 12.5,
            color: DebtsUi.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _SelectedCustomer(
          customer: widget.customer,
          onChange: _saving ? () {} : widget.onChangeCustomer,
        ),
        const SizedBox(height: 14),
        _AmountField(controller: _amountCtrl),
        const SizedBox(height: 12),
        _DueDateField(
          dueDate: _dueDate,
          onPick: _pickDate,
          onClear: () => setState(() => _dueDate = null),
        ),
        const SizedBox(height: 12),
        _NoteField(controller: _noteCtrl),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DebtsUi.dangerSoft,
              borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              border: Border.all(color: DebtsUi.dangerBorder, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: DebtsUi.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: DebtsUi.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        DebtsGradientButton(
          label: 'Record debt',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}

class _SelectedCustomer extends StatelessWidget {
  const _SelectedCustomer({required this.customer, required this.onChange});

  final LocalDebtCustomer customer;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DebtsUi.greenPale,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.greenLight, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DebtsUi.avatarGreenBg,
              borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              border: Border.all(color: DebtsUi.avatarGreenBorder, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: DebtsUi.avatarGreenFg,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: DebtsUi.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phoneNumber ?? 'No phone on file',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DebtsUi.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Change'),
            style: TextButton.styleFrom(
              foregroundColor: DebtsUi.greenMid,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      cursorColor: DebtsUi.greenMid,
      style: const TextStyle(
        fontSize: 20,
        color: DebtsUi.textPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: 'Amount',
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.greenMid,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
          child: Text(
            '₵',
            style: TextStyle(
              fontSize: 20,
              color: DebtsUi.greenMid,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: DebtsUi.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.greenMid, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({
    required this.dueDate,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? dueDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasDate = dueDate != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.border, width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: DebtsUi.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Due date (optional)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDate
                          ? DebtsUiUtils.formatDueLabel(
                              dueDate!.toIso8601String().substring(0, 10),
                            )
                          : 'Tap to pick a date',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            hasDate ? DebtsUi.textPrimary : DebtsUi.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDate)
                IconButton(
                  tooltip: 'Clear date',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: DebtsUi.textSecondary,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 2,
      cursorColor: DebtsUi.greenMid,
      style: const TextStyle(fontSize: 14, color: DebtsUi.textPrimary),
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.greenMid,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        hintText: 'e.g. delivered 3 bags of rice on credit',
        hintStyle: const TextStyle(
          fontSize: 13,
          color: DebtsUi.textMuted,
        ),
        filled: true,
        fillColor: DebtsUi.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.greenMid, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
