import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/inventory/data/local_variant.dart';
import 'package:biztrack_gh/features/sales/providers/sales_cart_provider.dart';

void main() {
  test('decrement to zero clears override and variant label for cart line', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(salesCartProvider.notifier);
    const itemId = 'item-1';
    const variantId = 'variant-1';
    const key = 'item-1::variant-1';
    const item = LocalInventoryItem(
      id: itemId,
      name: 'Rice',
      defaultPrice: '12.00',
      quantityOnHand: 50,
      variants: [
        LocalVariant(
          id: variantId,
          itemId: itemId,
          label: '50kg',
          priceOverride: '10.50',
        ),
      ],
    );
    const variant = LocalVariant(
      id: variantId,
      itemId: itemId,
      label: '50kg',
      priceOverride: '10.50',
    );

    notifier.addVariantItem(item, variant);
    expect(container.read(salesCartProvider).qtyByItemId[key], 1);
    expect(
        container.read(salesCartProvider).priceOverrideByItemId[key], '10.50');
    expect(container.read(salesCartProvider).variantLabelByKey[key], '50kg');

    notifier.decrementQty(key);
    final state = container.read(salesCartProvider);
    expect(state.qtyByItemId.containsKey(key), isFalse);
    expect(state.priceOverrideByItemId.containsKey(key), isFalse);
    expect(state.variantLabelByKey.containsKey(key), isFalse);
  });
}
