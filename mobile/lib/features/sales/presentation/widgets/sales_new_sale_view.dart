import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../providers/sales_cart_provider.dart';
import 'empty_card.dart';
import 'item_card.dart';
import 'sales_search_bar.dart';

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
          if (allItems.isEmpty)
            const EmptyCard(
              icon: Icons.inventory_2_outlined,
              title: 'No inventory yet',
              message:
                  'Add stock in Inventory first, then return here to start recording sales.',
            )
          else ...[
            if (selectedItems.isNotEmpty) ...[
              ItemGrid(
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
              const SizedBox(height: 16),
            ],
            if (quickAddItems.isNotEmpty) ...[
              ItemGrid(
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
              const SizedBox(height: 16),
            ],
            if (regularUnselectedItems.isNotEmpty) ...[
              ItemGrid(
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
            ],
            if (filteredItems.isEmpty && cart.searchQuery.isNotEmpty)
              const EmptyCard(
                icon: Icons.search_off_rounded,
                title: 'No products found',
                message:
                    'Try a different search or clear the search to see all inventory items.',
              ),
          ],
        ],
      ),
    );
  }
}

