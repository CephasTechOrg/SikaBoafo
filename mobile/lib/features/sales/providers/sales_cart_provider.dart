import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';

// Legacy carts may still use itemId::variantId keys; itemIdFromKey normalizes reads.

String itemIdFromKey(String key) => key.split('::').first;

class SalesCartState {
  const SalesCartState({
    this.qtyByItemId = const {},
    this.priceOverrideByItemId = const {},
    this.searchQuery = '',
    this.paymentMethod = 'cash',
    this.selectedCategory,
  });

  /// Keyed by item id (flat inventory). Legacy variant keys are collapsed on write.
  final Map<String, int> qtyByItemId;
  final Map<String, String> priceOverrideByItemId;
  final String searchQuery;
  final String paymentMethod;

  /// Active category filter. Null means "All".
  final String? selectedCategory;

  static const _kUnset = Object();

  SalesCartState copyWith({
    Map<String, int>? qtyByItemId,
    Map<String, String>? priceOverrideByItemId,
    String? searchQuery,
    String? paymentMethod,
    Object? selectedCategory = _kUnset,
  }) {
    return SalesCartState(
      qtyByItemId: qtyByItemId ?? this.qtyByItemId,
      priceOverrideByItemId:
          priceOverrideByItemId ?? this.priceOverrideByItemId,
      searchQuery: searchQuery ?? this.searchQuery,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedCategory: identical(selectedCategory, _kUnset)
          ? this.selectedCategory
          : selectedCategory as String?,
    );
  }
}

class SalesCartNotifier extends Notifier<SalesCartState> {
  @override
  SalesCartState build() => const SalesCartState();

  void incrementQty(LocalInventoryItem item) {
    final totalQty = _totalQtyForItem(item.id);
    if (totalQty >= item.quantityOnHand) return;

    final collapsed = _collapseLegacyKeys(item.id);
    final current = collapsed.qty[item.id] ?? 0;
    final newQty = Map<String, int>.from(collapsed.qty);
    newQty[item.id] = current + 1;
    state = state.copyWith(
      qtyByItemId: newQty,
      priceOverrideByItemId: collapsed.overrides,
    );
  }

  void decrementItem(String itemId) {
    if (state.qtyByItemId.containsKey(itemId)) {
      decrementQty(itemId);
      return;
    }
    final legacyKey = state.qtyByItemId.keys
        .where((k) => itemIdFromKey(k) == itemId)
        .firstOrNull;
    if (legacyKey != null) {
      decrementQty(legacyKey);
    }
  }

  void decrementQty(String key) {
    final current = state.qtyByItemId[key] ?? 0;
    if (current == 0) return;
    final newMap = Map<String, int>.from(state.qtyByItemId);
    final newOverrides = Map<String, String>.from(state.priceOverrideByItemId);
    if (current <= 1) {
      newMap.remove(key);
      newOverrides.remove(key);
    } else {
      newMap[key] = current - 1;
    }
    state = state.copyWith(
      qtyByItemId: newMap,
      priceOverrideByItemId: newOverrides,
    );
  }

  void overridePrice(String key, String priceStr) {
    final newMap = Map<String, String>.from(state.priceOverrideByItemId);
    newMap[key] = priceStr;
    state = state.copyWith(priceOverrideByItemId: newMap);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  void clearCart() {
    state = state.copyWith(
      qtyByItemId: const {},
      priceOverrideByItemId: const {},
      paymentMethod: 'cash',
      selectedCategory: null,
    );
  }

  void removeItem(String key) {
    final newQty = Map<String, int>.from(state.qtyByItemId);
    final newOverrides = Map<String, String>.from(state.priceOverrideByItemId);
    newQty.remove(key);
    newOverrides.remove(key);
    state = state.copyWith(
      qtyByItemId: newQty,
      priceOverrideByItemId: newOverrides,
    );
  }

  void removeOverride(String key) {
    final newMap = Map<String, String>.from(state.priceOverrideByItemId);
    newMap.remove(key);
    state = state.copyWith(priceOverrideByItemId: newMap);
  }

  int _totalQtyForItem(String itemId) {
    return state.qtyByItemId.entries
        .where((e) => itemIdFromKey(e.key) == itemId)
        .fold(0, (sum, e) => sum + e.value);
  }

  ({Map<String, int> qty, Map<String, String> overrides}) _collapseLegacyKeys(
    String itemId,
  ) {
    final newQty = Map<String, int>.from(state.qtyByItemId);
    final newOverrides = Map<String, String>.from(state.priceOverrideByItemId);
    final legacyKeys = newQty.keys
        .where((k) => itemIdFromKey(k) == itemId && k != itemId)
        .toList(growable: false);
    var total = newQty[itemId] ?? 0;
    String? mergedOverride = newOverrides[itemId];
    for (final key in legacyKeys) {
      total += newQty.remove(key) ?? 0;
      mergedOverride ??= newOverrides.remove(key);
    }
    if (total > 0) {
      newQty[itemId] = total;
    }
    if (mergedOverride != null) {
      newOverrides[itemId] = mergedOverride;
    }
    return (qty: newQty, overrides: newOverrides);
  }
}

final salesCartProvider = NotifierProvider<SalesCartNotifier, SalesCartState>(
  SalesCartNotifier.new,
);

final salesCartTotalProvider = Provider.autoDispose<String>((ref) {
  final cart = ref.watch(salesCartProvider);
  final inventory = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
  final itemById = {for (final i in inventory) i.id: i};

  int totalMinor = 0;
  for (final entry in cart.qtyByItemId.entries) {
    final qty = entry.value;
    if (qty <= 0) continue;
    final iId = itemIdFromKey(entry.key);
    final item = itemById[iId];
    if (item == null) continue;
    final overrideStr = cart.priceOverrideByItemId[entry.key] ??
        cart.priceOverrideByItemId[iId];
    final unitPriceMinor = _moneyToMinorSafe(overrideStr ?? item.defaultPrice);
    totalMinor += unitPriceMinor * qty;
  }

  return (totalMinor / 100).toStringAsFixed(2);
});

final salesCartItemCountProvider = Provider.autoDispose<int>((ref) {
  final cart = ref.watch(salesCartProvider);
  return cart.qtyByItemId.values.fold(0, (a, b) => a + b);
});

int _moneyToMinorSafe(String value) {
  final raw = value.trim().replaceAll(',', '');
  final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (match == null) return 0;
  final parts = raw.split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final decimals = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  return (major * 100) + (int.tryParse(decimals) ?? 0);
}
