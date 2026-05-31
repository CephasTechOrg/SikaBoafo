import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../providers/sales_cart_provider.dart';
import 'empty_card.dart';
import 'item_card.dart';

class SalesNewSaleView extends ConsumerWidget {
  const SalesNewSaleView({
    super.key,
    required this.allItems,
    required this.filteredItems,
    required this.selectedItems,
    required this.quickAddItems,
    required this.regularUnselectedItems,
    required this.onPriceTap,
  });

  final List<LocalInventoryItem> allItems;
  final List<LocalInventoryItem> filteredItems;
  final List<LocalInventoryItem> selectedItems;
  final List<LocalInventoryItem> quickAddItems;
  final List<LocalInventoryItem> regularUnselectedItems;
  final Function(LocalInventoryItem) onPriceTap;

  int _displayQty(SalesCartState cart, String itemId) {
    return cart.qtyByItemId.entries
        .where((e) => itemIdFromKey(e.key) == itemId)
        .fold(0, (sum, e) => sum + e.value);
  }

  ItemCard _buildCard({
    required LocalInventoryItem item,
    required SalesCartState cart,
    required SalesCartNotifier notifier,
    required bool isSelected,
    required Function(LocalInventoryItem) onPriceTap,
  }) {
    return ItemCard(
      item: item,
      qty: _displayQty(cart, item.id),
      priceOverride: cart.priceOverrideByItemId[item.id],
      isSelected: isSelected,
      onMinus: () => notifier.decrementItem(item.id),
      onPlus: () => notifier.incrementQty(item),
      onTap: () => notifier.incrementQty(item),
      onPriceTap: () => onPriceTap(item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(salesCartProvider);
    final cartNotifier = ref.read(salesCartProvider.notifier);

    return PremiumReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    .map((item) => _buildCard(
                          item: item,
                          cart: cart,
                          notifier: cartNotifier,
                          isSelected: true,
                          onPriceTap: onPriceTap,
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
            ],
            if (quickAddItems.isNotEmpty) ...[
              ItemGrid(
                children: quickAddItems
                    .map((item) => _buildCard(
                          item: item,
                          cart: cart,
                          notifier: cartNotifier,
                          isSelected: false,
                          onPriceTap: onPriceTap,
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
            ],
            if (regularUnselectedItems.isNotEmpty) ...[
              ItemGrid(
                children: regularUnselectedItems
                    .map((item) => _buildCard(
                          item: item,
                          cart: cart,
                          notifier: cartNotifier,
                          isSelected: false,
                          onPriceTap: onPriceTap,
                        ))
                    .toList(growable: false),
              ),
            ],
            if (filteredItems.isEmpty &&
                (cart.searchQuery.isNotEmpty ||
                    cart.selectedCategory != null))
              EmptyCard(
                icon: Icons.search_off_rounded,
                title: 'No products found',
                message: cart.selectedCategory != null &&
                        cart.searchQuery.isEmpty
                    ? 'No items in this category. Tap "All" to clear the filter.'
                    : 'Try a different search or clear the filter to see all items.',
              ),
          ],
        ],
      ),
    );
  }
}
