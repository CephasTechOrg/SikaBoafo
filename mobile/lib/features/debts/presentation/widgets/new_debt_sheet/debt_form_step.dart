import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../data/models/local_debt_customer.dart';
import '../../utils/debts_ui_utils.dart';

/// Step 2 of the new-debt flow: amount, optional due date, optional note.
/// The selected customer is shown at the top with a "change" affordance.
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
                  primary: AppColors.forestDark,
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
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'How much is owed, and when is it due?',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
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
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : 'Record debt'),
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
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phoneNumber ?? 'No phone on file',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
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
              foregroundColor: AppColors.forestDark,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
      style: const TextStyle(
        fontSize: 18,
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
          child: Text(
            '₵',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppColors.surface,
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Due date (optional)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
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
                      color: hasDate ? AppColors.ink : AppColors.mutedSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (hasDate)
              IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.muted),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
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
      style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: 'Note (optional)',
        hintText: 'e.g. delivered 3 bags of rice on credit',
        filled: true,
        fillColor: AppColors.surface,
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
