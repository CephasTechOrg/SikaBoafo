import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/sales/providers/sales_cart_provider.dart';

void main() {
  test('decrement to zero clears price override for cart line', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(salesCartProvider.notifier);
    const itemId = 'item-1';
    const item = LocalInventoryItem(
      id: itemId,
      name: 'Mug (Small)',
      defaultPrice: '12.00',
      quantityOnHand: 50,
    );

    notifier.incrementQty(item);
    notifier.overridePrice(itemId, '10.50');
    expect(container.read(salesCartProvider).qtyByItemId[itemId], 1);
    expect(
        container.read(salesCartProvider).priceOverrideByItemId[itemId], '10.50');

    notifier.decrementItem(itemId);
    final state = container.read(salesCartProvider);
    expect(state.qtyByItemId.containsKey(itemId), isFalse);
    expect(state.priceOverrideByItemId.containsKey(itemId), isFalse);
  });

  test('increment collapses legacy variant cart keys onto item id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(salesCartProvider.notifier);
    const itemId = 'item-1';
    const item = LocalInventoryItem(
      id: itemId,
      name: 'Mug (Small)',
      defaultPrice: '12.00',
      quantityOnHand: 50,
    );

    notifier.state = notifier.state.copyWith(
      qtyByItemId: const {'item-1::legacy-variant': 2},
      priceOverrideByItemId: const {'item-1::legacy-variant': '11.00'},
    );

    notifier.incrementQty(item);
    final state = container.read(salesCartProvider);
    expect(state.qtyByItemId[itemId], 3);
    expect(state.qtyByItemId.containsKey('item-1::legacy-variant'), isFalse);
    expect(state.priceOverrideByItemId[itemId], '11.00');
  });
}
