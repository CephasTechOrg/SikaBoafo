import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../providers/sales_cart_provider.dart';
import 'empty_card.dart';
import 'item_card.dart';
import 'products_header.dart';
import 'sales_search_bar.dart';
import 'section_label.dart';

class SalesNewSaleView extends ConsumerWidget {
  const SalesNewSaleView({
    super.key,
    required this.searchCtrl,
    required this.allItems,
    required this.filteredItems,
    required this.selectedItems,
    required this.quickAddItems,
    required this.regularUnselectedItems,
    required this.onPriceTap,
  });

  final TextEditingController searchCtrl;
  final List<LocalInventoryItem> allItems;
  final List<LocalInventoryItem> filteredItems;
  final List<LocalInventoryItem> selectedItems;
  final List<LocalInventoryItem> quickAddItems;
  final List<LocalInventoryItem> regularUnselectedItems;
  final Function(LocalInventoryItem) onPriceTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(salesCartProvider);
    final cartNotifier = ref.read(salesCartProvider.notifier);

    return PremiumReveal(
      child: Column(
        children: [
          SalesSearchBar(
            controller: searchCtrl,
            hasQuery: cart.searchQuery.isNotEmpty,
            onChanged: (v) {
              searchCtrl.value = searchCtrl.value.copyWith(text: v.trim());
              ref.read(salesCartProvider.notifier).setSearchQuery(v.trim());
            },
            onClear: () {
              searchCtrl.clear();
              ref.read(salesCartProvider.notifier).setSearchQuery('');
            },
          ),
          const SizedBox(height: 16),
          ProductsHeader(
            selectedCount: selectedItems.length,
            totalCount: allItems.length,
          ),
          const SizedBox(height: 12),
          if (allItems.isEmpty)
            const EmptyCard(
              icon: Icons.inventory_2_outlined,
              message: 'No inventory items. Add stock in Inventory first.',
            )
          else ...[
            if (selectedItems.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'In Cart',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${selectedItems.length} items',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PremiumPanel(
                    child: ItemGrid(
                      children: selectedItems
                          .map(
                            (item) => ItemCard(
                              item: item,
                              qty: cart.qtyByItemId[item.id] ?? 0,
                              priceOverride: cart.priceOverrideByItemId[item.id],
                              isSelected: true,
                              onMinus: () => cartNotifier.decrementQty(item.id),
                              onPlus: () => cartNotifier.incrementQty(item),
                              onPriceTap: () => onPriceTap(item),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (quickAddItems.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Add',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PremiumPanel(
                    child: ItemGrid(
                      children: quickAddItems
                          .map(
                            (item) => ItemCard(
                              item: item,
                              qty: 0,
                              priceOverride: null,
                              isSelected: false,
                              onMinus: () {},
                              onPlus: () => cartNotifier.incrementQty(item),
                              onPriceTap: () => onPriceTap(item),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (regularUnselectedItems.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedItems.isNotEmpty
                        ? 'Add More Products'
                        : 'Available Products',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PremiumPanel(
                    child: ItemGrid(
                      children: regularUnselectedItems
                          .map(
                            (item) => ItemCard(
                              item: item,
                              qty: 0,
                              priceOverride: null,
                              isSelected: false,
                              onMinus: () {},
                              onPlus: () => cartNotifier.incrementQty(item),
                              onPriceTap: () => onPriceTap(item),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ],
            if (filteredItems.isEmpty && cart.searchQuery.isNotEmpty)
              EmptyCard(
                icon: Icons.search_off_rounded,
                message: 'No items match "${cart.searchQuery}".',
              ),
          ],
        ],
      ),
    );
  }
}
