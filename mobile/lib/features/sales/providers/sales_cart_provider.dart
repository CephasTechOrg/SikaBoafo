import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/data/local_variant.dart';
import '../../inventory/providers/inventory_providers.dart';

// ─── Cart-key helpers ────────────────────────────────────────────────────────
// Items without variants:   key == itemId
// Items with a variant:     key == "$itemId::$variantId"

String cartKey(String itemId, String? variantId) =>
    variantId != null ? '$itemId::$variantId' : itemId;

String itemIdFromKey(String key) => key.split('::').first;

String? variantIdFromKey(String key) {
  final parts = key.split('::');
  return parts.length > 1 ? parts[1] : null;
}

// ─── State ───────────────────────────────────────────────────────────────────

class SalesCartState {
  const SalesCartState({
    this.qtyByItemId = const {},
    this.priceOverrideByItemId = const {},
    this.variantLabelByKey = const {},
    this.pendingVariantByItemId = const {},
    this.searchQuery = '',
    this.paymentMethod = 'cash',
  });

  /// Keyed by cartKey (itemId or itemId::variantId).
  final Map<String, int> qtyByItemId;

  /// Price override keyed by cartKey.
  final Map<String, String> priceOverrideByItemId;

  /// Variant label for display in cart/review, keyed by cartKey.
  final Map<String, String> variantLabelByKey;

  /// Which variant chip is "pending" (selected in the card before tapping +).
  /// Keyed by itemId only.
  final Map<String, String?> pendingVariantByItemId;

  final String searchQuery;
  final String paymentMethod;

  SalesCartState copyWith({
    Map<String, int>? qtyByItemId,
    Map<String, String>? priceOverrideByItemId,
    Map<String, String>? variantLabelByKey,
    Map<String, String?>? pendingVariantByItemId,
    String? searchQuery,
    String? paymentMethod,
  }) {
    return SalesCartState(
      qtyByItemId: qtyByItemId ?? this.qtyByItemId,
      priceOverrideByItemId:
          priceOverrideByItemId ?? this.priceOverrideByItemId,
      variantLabelByKey: variantLabelByKey ?? this.variantLabelByKey,
      pendingVariantByItemId:
          pendingVariantByItemId ?? this.pendingVariantByItemId,
      searchQuery: searchQuery ?? this.searchQuery,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class SalesCartNotifier extends Notifier<SalesCartState> {
  @override
  SalesCartState build() => const SalesCartState();

  /// Select a variant chip (before the item is added to the cart).
  void selectPendingVariant(String itemId, String? variantId) {
    final newMap = Map<String, String?>.from(state.pendingVariantByItemId);
    newMap[itemId] = variantId;
    state = state.copyWith(pendingVariantByItemId: newMap);
  }

  /// Add/increment an item that has a specific variant selected.
  void addVariantItem(LocalInventoryItem item, LocalVariant variant) {
    final key = cartKey(item.id, variant.id);

    // Stock check: total qty across ALL variant lines for this item.
    final totalQty = _totalQtyForItem(item.id);
    if (totalQty >= item.quantityOnHand) return;

    final newQty = Map<String, int>.from(state.qtyByItemId);
    final newLabels = Map<String, String>.from(state.variantLabelByKey);
    newQty[key] = (newQty[key] ?? 0) + 1;
    newLabels[key] = variant.label;

    if (variant.priceOverride != null) {
      final newOverrides =
          Map<String, String>.from(state.priceOverrideByItemId);
      newOverrides[key] = variant.priceOverride!;
      state = state.copyWith(
        qtyByItemId: newQty,
        variantLabelByKey: newLabels,
        priceOverrideByItemId: newOverrides,
      );
    } else {
      state = state.copyWith(
        qtyByItemId: newQty,
        variantLabelByKey: newLabels,
      );
    }
  }

  /// Increment qty for a non-variant item. Do not call for items with variants.
  void incrementQty(LocalInventoryItem item) {
    final current = state.qtyByItemId[item.id] ?? 0;
    if (current >= item.quantityOnHand) return;
    final newMap = Map<String, int>.from(state.qtyByItemId);
    newMap[item.id] = current + 1;
    state = state.copyWith(qtyByItemId: newMap);
  }

  void decrementQty(String key) {
    final current = state.qtyByItemId[key] ?? 0;
    final newMap = Map<String, int>.from(state.qtyByItemId);
    if (current <= 1) {
      newMap.remove(key);
    } else {
      newMap[key] = current - 1;
    }
    state = state.copyWith(qtyByItemId: newMap);
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

  void clearCart() {
    state = state.copyWith(
      qtyByItemId: const {},
      priceOverrideByItemId: const {},
      variantLabelByKey: const {},
      pendingVariantByItemId: const {},
      paymentMethod: 'cash',
    );
  }

  void removeItem(String key) {
    final newQty = Map<String, int>.from(state.qtyByItemId);
    final newOverrides = Map<String, String>.from(state.priceOverrideByItemId);
    final newLabels = Map<String, String>.from(state.variantLabelByKey);
    newQty.remove(key);
    newOverrides.remove(key);
    newLabels.remove(key);
    state = state.copyWith(
      qtyByItemId: newQty,
      priceOverrideByItemId: newOverrides,
      variantLabelByKey: newLabels,
    );
  }

  void removeOverride(String key) {
    final newMap = Map<String, String>.from(state.priceOverrideByItemId);
    newMap.remove(key);
    state = state.copyWith(priceOverrideByItemId: newMap);
  }

  /// Total qty across all variant lines for [itemId].
  int _totalQtyForItem(String itemId) {
    return state.qtyByItemId.entries
        .where((e) => itemIdFromKey(e.key) == itemId)
        .fold(0, (sum, e) => sum + e.value);
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

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
    final overrideStr = cart.priceOverrideByItemId[entry.key];
    int unitPriceMinor;
    if (overrideStr != null) {
      final d = double.tryParse(overrideStr.replaceAll(',', '')) ?? 0.0;
      unitPriceMinor = (d * 100).round();
    } else {
      final d = double.tryParse(item.defaultPrice.replaceAll(',', '')) ?? 0.0;
      unitPriceMinor = (d * 100).round();
    }
    totalMinor += unitPriceMinor * qty;
  }

  return (totalMinor / 100).toStringAsFixed(2);
});

final salesCartItemCountProvider = Provider.autoDispose<int>((ref) {
  final cart = ref.watch(salesCartProvider);
  return cart.qtyByItemId.values.fold(0, (a, b) => a + b);
});
