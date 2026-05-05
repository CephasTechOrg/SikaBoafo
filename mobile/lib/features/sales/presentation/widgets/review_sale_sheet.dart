import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../../shared/widgets/product_image_catalog.dart';
import '../../providers/sales_cart_provider.dart';

/// Order review sheet — shows cart contents, note field, total, and proceeds
/// to checkout when the user is satisfied.
class ReviewSaleSheet extends ConsumerWidget {
  const ReviewSaleSheet({
    super.key,
    required this.items,
    required this.onProceedToCheckout,
    required this.noteController,
    required this.calculateTotal,
    required this.formatMajor,
    required this.formatMinor,
    required this.moneyToMinor,
  });

  final List<LocalInventoryItem> items;
  final VoidCallback onProceedToCheckout;
  final TextEditingController noteController;
  final String Function(List<LocalInventoryItem>) calculateTotal;
  final String Function(String value, {String symbol}) formatMajor;
  final String Function(int minor, {String symbol}) formatMinor;
  final int Function(String value) moneyToMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemById = {for (final item in items) item.id: item};
    final cartState = ref.watch(salesCartProvider);
    final entries = cartState.qtyByItemId.entries
        .where((e) => e.value > 0 && itemById.containsKey(itemIdFromKey(e.key)))
        .toList();
    final currentCount = entries.fold(0, (s, e) => s + e.value);
    final currentTotal = calculateTotal(items);
    final hasItems = currentCount > 0;
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
              // Drag handle
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
              // Header row
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
                      Icons.receipt_long_rounded,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Review',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '$currentCount ${currentCount == 1 ? 'item' : 'items'} · ${formatMajor(currentTotal, symbol: '₵')}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Item rows (scrollable if many items)
              if (hasItems)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.38,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: entries.map((entry) {
                        final item = itemById[itemIdFromKey(entry.key)]!;
                        final qty = entry.value;
                        final price =
                            cartState.priceOverrideByItemId[entry.key] ??
                                item.defaultPrice;
                        final lineTotal = moneyToMinor(price) * qty;
                        final variantLabel =
                            cartState.variantLabelByKey[entry.key];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ItemImage(
                                imageUrl: item.imageUrl,
                                size: 40,
                                fallbackIcon: Icons.inventory_2_outlined,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (variantLabel != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        variantLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.forest,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      '$qty × ₵$price',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatMinor(lineTotal, symbol: '₵'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      ref
                                          .read(salesCartProvider.notifier)
                                          .removeItem(entry.key);
                                    },
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          color: AppColors.muted, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Cart is empty',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Total row
              if (hasItems) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatMajor(currentTotal, symbol: '₵'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                        fontFamily: 'Constantia',
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Note field
              const Text(
                'Note (optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: noteController,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Add a note for this sale…',
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterStyle: TextStyle(fontSize: 9),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.forest),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Keep editing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: hasItems
                          ? () {
                              Navigator.of(context).pop();
                              onProceedToCheckout();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Proceed to checkout'),
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
