import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/inventory/presentation/inventory_screen.dart';
import 'package:biztrack_gh/features/inventory/providers/inventory_providers.dart';
import 'package:biztrack_gh/features/sales/data/sales_repository.dart';
import 'package:biztrack_gh/features/sales/presentation/sales_screen.dart';
import 'package:biztrack_gh/features/sales/providers/sales_providers.dart';

Widget _buildInventoryScreen({
  required List<LocalInventoryItem> items,
  Future<void> Function(String itemId)? onArchive,
  Future<void> Function(String itemId)? onRestore,
}) {
  return ProviderScope(
    overrides: [
      inventoryControllerProvider.overrideWith(
        () => _FakeInventoryController(
          seedItems: items,
          onArchive: onArchive,
          onRestore: onRestore,
        ),
      ),
    ],
    child: const MaterialApp(home: InventoryScreen()),
  );
}

Widget _buildSalesScreen({
  required List<LocalInventoryItem> items,
  List<LocalSaleRecord> sales = const [],
}) {
  return ProviderScope(
    overrides: [
      inventoryControllerProvider.overrideWith(
        () => _FakeInventoryController(seedItems: items),
      ),
      salesControllerProvider.overrideWith(
        () => _FakeSalesController(seedSales: sales),
      ),
    ],
    child: const MaterialApp(home: SalesScreen()),
  );
}

void main() {
  group('Inventory archive UI', () {
    testWidgets('shows active items separately from archived items',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildInventoryScreen(
          items: const [
            LocalInventoryItem(
              id: 'active-1',
              name: 'Rice',
              defaultPrice: '12.00',
              quantityOnHand: 0,
              isActive: true,
            ),
            LocalInventoryItem(
              id: 'archived-1',
              name: 'Old Rice',
              defaultPrice: '12.00',
              quantityOnHand: 0,
              isActive: false,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Active Items'), findsOneWidget);
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);

      expect(find.text('Archived Items'), findsOneWidget);
      expect(find.text('Old Rice'), findsNothing);

      final archivedToggle = find.ancestor(
        of: find.text('Archived Items'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(archivedToggle);
      await tester.tap(archivedToggle);
      await tester.pumpAndSettle();

      expect(find.text('Old Rice'), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
    });

    testWidgets('shows archive validation message when stock remains',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildInventoryScreen(
          items: const [
            LocalInventoryItem(
              id: 'active-1',
              name: 'Soap',
              defaultPrice: '4.50',
              quantityOnHand: 3,
              isActive: true,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Archive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(archiveRequiresZeroStockMessage), findsOneWidget);
    });
  });

  testWidgets('SalesScreen excludes archived items from new sale selection',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSalesScreen(
        items: const [
          LocalInventoryItem(
            id: 'active-1',
            name: 'Bread',
            defaultPrice: '3.00',
            quantityOnHand: 8,
            isActive: true,
          ),
          LocalInventoryItem(
            id: 'archived-1',
            name: 'Old Bread',
            defaultPrice: '3.00',
            quantityOnHand: 8,
            isActive: false,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Old Bread'), findsNothing);
  });
}

class _FakeInventoryController extends InventoryController {
  _FakeInventoryController({
    required this.seedItems,
    this.onArchive,
    this.onRestore,
  });

  final List<LocalInventoryItem> seedItems;
  final Future<void> Function(String itemId)? onArchive;
  final Future<void> Function(String itemId)? onRestore;

  late List<LocalInventoryItem> _items;

  @override
  Future<List<LocalInventoryItem>> build() async {
    _items = List<LocalInventoryItem>.from(seedItems);
    return _items;
  }

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(_items);
  }

  @override
  Future<void> archiveItem({required String itemId}) async {
    final fn = onArchive;
    if (fn != null) {
      await fn(itemId);
    }
    _items = _items
        .map((item) => item.id == itemId ? _withActive(item, false) : item)
        .toList(growable: false);
    state = AsyncValue.data(_items);
  }

  @override
  Future<void> restoreItem({required String itemId}) async {
    final fn = onRestore;
    if (fn != null) {
      await fn(itemId);
    }
    _items = _items
        .map((item) => item.id == itemId ? _withActive(item, true) : item)
        .toList(growable: false);
    state = AsyncValue.data(_items);
  }

  LocalInventoryItem _withActive(LocalInventoryItem item, bool isActive) {
    return LocalInventoryItem(
      id: item.id,
      name: item.name,
      defaultPrice: item.defaultPrice,
      quantityOnHand: item.quantityOnHand,
      sku: item.sku,
      category: item.category,
      lowStockThreshold: item.lowStockThreshold,
      isActive: isActive,
      imageAsset: item.imageAsset,
    );
  }
}

class _FakeSalesController extends SalesController {
  _FakeSalesController({required this.seedSales});

  final List<LocalSaleRecord> seedSales;

  @override
  Future<List<LocalSaleRecord>> build() async => seedSales;

  @override
  Future<void> refresh({bool? includeVoided}) async {
    state = AsyncValue.data(seedSales);
  }
}
