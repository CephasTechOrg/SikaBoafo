import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/utils/user_friendly_error.dart';
import '../../../data/models/local_debt_customer.dart';
import '../../../providers/debts_providers.dart';
import '../../utils/debts_ui_tokens.dart';
import 'customer_inline_create.dart';
import 'customer_picker_step.dart';
import 'debt_form_step.dart';

enum _Step { pickCustomer, createCustomer, fillForm }

/// Three-step bottom sheet for creating a new debt:
///   1. Pick or add a customer.
///   2. (Optional) Inline create — collects name + phone, then auto-advances.
///   3. Enter amount + due date + optional note.
///
/// Each step lives in its own file. This file only owns the step-machine.
class NewDebtSheet extends ConsumerStatefulWidget {
  const NewDebtSheet({
    super.key,
    required this.customers,
    this.preselectedCustomer,
  });

  final List<LocalDebtCustomer> customers;

  /// When provided (e.g. launched from a customer detail), the sheet skips
  /// straight to the form step.
  final LocalDebtCustomer? preselectedCustomer;

  @override
  ConsumerState<NewDebtSheet> createState() => _NewDebtSheetState();
}

class _NewDebtSheetState extends ConsumerState<NewDebtSheet> {
  late _Step _step;
  LocalDebtCustomer? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCustomer != null) {
      _selected = widget.preselectedCustomer;
      _step = _Step.fillForm;
    } else {
      _step = _Step.pickCustomer;
    }
  }

  Future<void> _handleCreateCustomer({
    required String name,
    String? phoneNumber,
  }) async {
    final controller = ref.read(debtsControllerProvider.notifier);
    final customerId = await controller.createCustomer(
      name: name,
      phoneNumber: phoneNumber,
      useLoadingState: false,
    );
    final repo = ref.read(debtsRepositoryProvider);
    final created = await repo.getCustomerById(customerId);
    if (!mounted) return;
    setState(() {
      _selected = created;
      _step = _Step.fillForm;
    });
  }

  Future<void> _handleSubmitDebt({
    required String amount,
    String? dueDateIso,
    String? note,
  }) async {
    final selected = _selected;
    if (selected == null) return;
    final controller = ref.read(debtsControllerProvider.notifier);
    try {
      await controller.createReceivable(
        customerId: selected.customerId,
        originalAmount: amount,
        dueDateIso: dueDateIso,
        note: note,
        useLoadingState: false,
      );
    } catch (error) {
      // Surface a friendly error inside the form step. The form step catches
      // its own thrown errors and shows them; re-throw a user-friendly one.
      throw userFriendlyError(error);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debt recorded. It will sync to the server shortly.'),
      ),
    );
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
                  _buildStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.pickCustomer:
        return CustomerPickerStep(
          customers: widget.customers,
          onPick: (customer) => setState(() {
            _selected = customer;
            _step = _Step.fillForm;
          }),
          onCreateNew: () => setState(() => _step = _Step.createCustomer),
        );
      case _Step.createCustomer:
        return CustomerInlineCreate(
          onCancel: () => setState(() => _step = _Step.pickCustomer),
          onSubmit: _handleCreateCustomer,
        );
      case _Step.fillForm:
        final selected = _selected;
        if (selected == null) {
          // Defensive fallback — should never happen.
          return const SizedBox.shrink();
        }
        return DebtFormStep(
          customer: selected,
          onChangeCustomer: () => setState(() {
            _selected = null;
            _step = _Step.pickCustomer;
          }),
          onSubmit: _handleSubmitDebt,
        );
    }
  }
}

/// Convenience launcher used by [DebtsScreen] (and elsewhere) so the
/// `showModalBottomSheet` boilerplate doesn't pollute the screen file.
Future<bool?> showNewDebtSheet(
  BuildContext context, {
  required List<LocalDebtCustomer> customers,
  LocalDebtCustomer? preselectedCustomer,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => NewDebtSheet(
      customers: customers,
      preselectedCustomer: preselectedCustomer,
    ),
  );
}
