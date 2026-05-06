import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/expenses_repository.dart';
import '../../providers/expenses_providers.dart';
import '../expenses_category_meta.dart';
import 'expense_category_chips.dart';

int _toMinor(String value) {
  final parts = value.trim().split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final raw = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(raw.substring(0, 2)) ?? 0);
}

/// Bottom sheet to edit an existing expense (category, amount, note / other name).
class ExpenseEditSheet extends ConsumerStatefulWidget {
  const ExpenseEditSheet({super.key, required this.record});

  final LocalExpenseRecord record;

  @override
  ConsumerState<ExpenseEditSheet> createState() => _ExpenseEditSheetState();
}

class _ExpenseEditSheetState extends ConsumerState<ExpenseEditSheet> {
  late String _category;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _otherNameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _category = r.category;
    _amountCtrl = TextEditingController(text: r.amount);
    final parts = expenseNoteFieldsForEdit(r.category, r.note);
    _otherNameCtrl = TextEditingController(text: parts.otherName);
    _noteCtrl = TextEditingController(text: parts.additionalNote);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _otherNameCtrl.dispose();
    super.dispose();
  }

  bool get _amountOk {
    final t = _amountCtrl.text.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t) && _toMinor(t) > 0;
  }

  bool get _canSave {
    if (!_amountOk) return false;
    if (_category == 'other' && _otherNameCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final storedNote = buildStoredExpenseNote(
      category: _category,
      otherName: _otherNameCtrl.text,
      additionalNote: _noteCtrl.text,
    );
    try {
      await ref.read(expensesControllerProvider.notifier).updateExpense(
            expenseId: widget.record.expenseId,
            category: _category,
            amount: _amountCtrl.text.trim(),
            note: storedNote,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Changes sync when you are online.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              ExpenseCategoryChips(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              if (_category == 'other') ...[
                const SizedBox(height: 14),
                _SheetField(
                  controller: _otherNameCtrl,
                  label: 'Other — what is this?',
                  hint: 'e.g. Office supplies',
                  icon: Icons.label_outline_rounded,
                ),
              ],
              const SizedBox(height: 16),
              _SheetField(
                controller: _amountCtrl,
                label: 'Amount (GHS)',
                hint: '0.00',
                icon: Icons.payments_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: _noteCtrl,
                label: 'Note (optional)',
                hint: 'Details',
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: (_saving || !_canSave) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

Future<bool?> showExpenseEditSheet(
  BuildContext context, {
  required LocalExpenseRecord record,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ExpenseEditSheet(record: record),
  );
}
