import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/sales_repository.dart';
import '../../providers/sales_providers.dart';
import '../../../inventory/data/inventory_api.dart';
import '../widgets/item_card.dart';

/// Bottom sheet that lets the user adjust quantities and payment method
/// on an already-recorded sale.
class EditSaleSheet extends ConsumerStatefulWidget {
  const EditSaleSheet({
    super.key,
    required this.sale,
    required this.editable,
  });

  final LocalSaleRecord sale;
  final LocalSaleEditable editable;

  @override
  ConsumerState<EditSaleSheet> createState() => _EditSaleSheetState();
}

class _EditSaleSheetState extends ConsumerState<EditSaleSheet> {
  late String _paymentMethod;
  late Map<String, int> _qtyByItem;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _paymentMethod = widget.editable.paymentMethodLabel;
    _qtyByItem = {
      for (final line in widget.editable.lines) line.itemId: line.quantity,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewBottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + viewBottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Sale',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Adjust quantities and payment method.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final entry in [
                    ('cash', 'Cash', Icons.payments_rounded),
                    ('mobile_money', 'MoMo', Icons.phone_android_rounded),
                    ('bank_transfer', 'Bank', Icons.account_balance_rounded),
                  ]) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSaving
                            ? null
                            : () => setState(
                                () => _paymentMethod = entry.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _paymentMethod == entry.$1
                                ? AppColors.forest.withValues(alpha: 0.08)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _paymentMethod == entry.$1
                                  ? AppColors.forest
                                  : AppColors.border,
                              width: _paymentMethod == entry.$1 ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.$3,
                                size: 16,
                                color: _paymentMethod == entry.$1
                                    ? AppColors.forest
                                    : AppColors.muted,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _paymentMethod == entry.$1
                                      ? AppColors.forest
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (entry.$1 != 'bank_transfer')
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Line quantities',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              ...widget.editable.lines.map((line) {
                final selectedQty =
                    _qtyByItem[line.itemId] ?? line.quantity;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              '₵${line.unitPrice} · max ${line.maxQuantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleQtyBtn(
                              icon: Icons.remove_rounded,
                              enabled:
                                  !_isSaving && selectedQty > 1,
                              onTap: () => setState(() =>
                                  _qtyByItem[line.itemId] =
                                      selectedQty - 1),
                            ),
                            SizedBox(
                              width: 36,
                              child: Center(
                                child: Text(
                                  '$selectedQty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                            CircleQtyBtn(
                              icon: Icons.add_rounded,
                              enabled: !_isSaving &&
                                  selectedQty < line.maxQuantity,
                              onTap: () => setState(() =>
                                  _qtyByItem[line.itemId] =
                                      selectedQty + 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        side: const BorderSide(color: AppColors.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save Changes',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final lines = widget.editable.lines
          .map(
            (line) => SaleQuantityUpdateDraft(
              itemId: line.itemId,
              quantity: _qtyByItem[line.itemId] ?? line.quantity,
            ),
          )
          .toList(growable: false);
      await ref.read(salesControllerProvider.notifier).updateSale(
            saleId: widget.sale.saleId,
            paymentMethodLabel: _paymentMethod,
            lines: lines,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeInventoryError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
