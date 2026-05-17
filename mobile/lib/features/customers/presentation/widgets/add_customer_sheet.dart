import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/widgets/new_debt_sheet/customer_inline_create.dart';
import '../../../debts/providers/debts_providers.dart';

Future<bool?> showAddCustomerSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => const AddCustomerSheet(),
  );
}

class AddCustomerSheet extends ConsumerWidget {
  const AddCustomerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  CustomerInlineCreate(
                    onCancel: () => Navigator.of(context).pop(),
                    onSubmit: ({required String name, String? phoneNumber}) async {
                      await ref.read(debtsControllerProvider.notifier).createCustomer(
                            name: name,
                            phoneNumber: phoneNumber,
                            useLoadingState: false,
                          );
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer saved.')),
                      );
                    },
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
