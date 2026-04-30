import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/providers/inventory_providers.dart';

class SalesCartState {
  final Map<String, int> qtyByItemId;
  final Map<String, String> priceOverrideByItemId;
  final String searchQuery;
  final String paymentMethod;
  
  const SalesCartState({
    this.qtyByItemId = const {},
    this.priceOverrideByItemId = const {},
    this.searchQuery = '',
    this.paymentMethod = 'cash',
  });

  SalesCartState copyWith({
    Map<String, int>? qtyByItemId,
    Map<String, String>? priceOverrideByItemId,
    String? searchQuery,
    String? paymentMethod,
  }) {
    return SalesCartState(
      qtyByItemId: qtyByItemId ?? this.qtyByItemId,
      priceOverrideByItemId: priceOverrideByItemId ?? this.priceOverrideByItemId,
      searchQuery: searchQuery ?? this.searchQuery,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class SalesCartNotifier extends Notifier<SalesCartState> {
  @override
  SalesCartState build() => const SalesCartState();

  void incrementQty(LocalInventoryItem item) {
    final current = state.qtyByItemId[item.id] ?? 0;
    if (current >= item.quantityOnHand) return;
    
    final newMap = Map<String, int>.from(state.qtyByItemId);
    newMap[item.id] = current + 1;
    state = state.copyWith(qtyByItemId: newMap);
  }

  void decrementQty(String itemId) {
    final current = state.qtyByItemId[itemId] ?? 0;
    final newMap = Map<String, int>.from(state.qtyByItemId);
    if (current <= 1) {
      newMap.remove(itemId);
    } else {
      newMap[itemId] = current - 1;
    }
    state = state.copyWith(qtyByItemId: newMap);
  }

  void overridePrice(String itemId, String priceStr) {
    final newMap = Map<String, String>.from(state.priceOverrideByItemId);
    newMap[itemId] = priceStr;
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
      paymentMethod: 'cash',
    );
  }

  void removeItem(String itemId) {
    final newQty = Map<String, int>.from(state.qtyByItemId);
    final newOverrides = Map<String, String>.from(state.priceOverrideByItemId);
    newQty.remove(itemId);
    newOverrides.remove(itemId);
    state = state.copyWith(
      qtyByItemId: newQty,
      priceOverrideByItemId: newOverrides,
    );
  }

  void removeOverride(String itemId) {
    final newMap = Map<String, String>.from(state.priceOverrideByItemId);
    newMap.remove(itemId);
    state = state.copyWith(priceOverrideByItemId: newMap);
  }
}

final salesCartProvider = NotifierProvider<SalesCartNotifier, SalesCartState>(
  SalesCartNotifier.new,
);

final salesCartTotalProvider = Provider.autoDispose<String>((ref) {
  final cart = ref.watch(salesCartProvider);
  final inventory = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
  
  int totalMinor = 0;
  for (final item in inventory) {
    final qty = cart.qtyByItemId[item.id] ?? 0;
    if (qty <= 0) continue;
    final overrideStr = cart.priceOverrideByItemId[item.id];
    int unitPriceMinor;
    if (overrideStr != null) {
      final clean = overrideStr.replaceAll(',', '');
      final d = double.tryParse(clean) ?? 0.0;
      unitPriceMinor = (d * 100).round();
    } else {
      final clean = item.defaultPrice.replaceAll(',', '');
      final d = double.tryParse(clean) ?? 0.0;
      unitPriceMinor = (d * 100).round();
    }
    totalMinor += unitPriceMinor * qty;
  }
  
  final value = totalMinor / 100;
  // Format to 2 decimal places without grouping for exact logic match
  return value.toStringAsFixed(2);
});

final salesCartItemCountProvider = Provider.autoDispose<int>((ref) {
  final cart = ref.watch(salesCartProvider);
  return cart.qtyByItemId.values.fold(0, (a, b) => a + b);
});
