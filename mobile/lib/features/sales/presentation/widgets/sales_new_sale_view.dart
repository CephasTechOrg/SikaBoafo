import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/premium_ui.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/local_variant.dart';
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

  int _totalQtyForItem(SalesCartState cart, String itemId) {
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
    final pendingVariantId = cart.pendingVariantByItemId[item.id];
    final key = cartKey(item.id, pendingVariantId);
    final displayQty = item.hasVariants
        ? (pendingVariantId != null
            ? (cart.qtyByItemId[key] ?? 0)
            : _totalQtyForItem(cart, item.id))
        : (cart.qtyByItemId[item.id] ?? 0);

    void handlePlus() {
      if (item.hasVariants) {
        if (pendingVariantId == null) return;
        final variant =
            item.variants.where((v) => v.id == pendingVariantId).firstOrNull;
        if (variant != null) notifier.addVariantItem(item, variant);
      } else {
        notifier.incrementQty(item);
      }
    }

    return ItemCard(
      item: item,
      qty: displayQty,
      priceOverride: cart.priceOverrideByItemId[key],
      isSelected: isSelected,
      onMinus: () => notifier.decrementQty(key),
      onPlus: handlePlus,
      onPriceTap: () => onPriceTap(item),
      selectedVariantId: pendingVariantId,
      onVariantSelected: item.hasVariants
          ? (LocalVariant v) => notifier.selectPendingVariant(item.id, v.id)
          : null,
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

