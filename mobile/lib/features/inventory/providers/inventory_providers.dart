import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    appDb: ref.watch(appDatabaseProvider),
    inventoryApi: ref.watch(inventoryApiProvider),
    syncQueueRunner: ref.watch(syncQueueRunnerProvider),
  );
});

final inventoryControllerProvider = AsyncNotifierProvider.autoDispose<
    InventoryController, List<LocalInventoryItem>>(
  InventoryController.new,
);

class InventoryController
    extends AutoDisposeAsyncNotifier<List<LocalInventoryItem>> {
  InventoryRepository get _repo => ref.read(inventoryRepositoryProvider);

  @override
  Future<List<LocalInventoryItem>> build() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Ignore initial sync failures; queue stays for retry.
    }
    var local = await _repo.listLocalItems();
    if (local.isEmpty) {
      try {
        await _repo.refreshFromServer();
        local = await _repo.listLocalItems();
      } catch (_) {
        // Keep local-first behavior: fallback to whatever is available locally.
      }
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    return local;
  }

  Future<void> refresh() async {
    try {
      await _repo.syncPendingQueue();
    } catch (_) {
      // Keep local-first UX even if immediate sync attempt fails.
    }
    try {
      await _repo.refreshFromServer();
    } catch (_) {
      // Ignore network errors during refresh to keep local data visible.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> createItem({
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    int initialQuantity = 0,
    String? imageAsset,
  }) async {
    await _repo.createItemLocal(
      name: name,
      defaultPrice: defaultPrice,
      sku: sku,
      category: category,
      lowStockThreshold: lowStockThreshold,
      initialQuantity: initialQuantity,
      imageAsset: imageAsset,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> updateItem({
    required String itemId,
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    required bool isActive,
    String? imageAsset,
    bool imageAssetChanged = false,
  }) async {
    await _repo.updateItemLocal(
      itemId: itemId,
      name: name,
      defaultPrice: defaultPrice,
      sku: sku,
      category: category,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
      imageAsset: imageAsset,
      imageAssetChanged: imageAssetChanged,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> archiveItem({required String itemId}) async {
    await _repo.archiveItemLocal(itemId: itemId);
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> restoreItem({required String itemId}) async {
    await _repo.restoreItemLocal(itemId: itemId);
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> stockIn({
    required String itemId,
    required int quantity,
    String? reason,
  }) async {
    await _repo.stockInLocal(
      itemId: itemId,
      quantity: quantity,
      reason: reason,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }

  Future<void> adjustStock({
    required String itemId,
    required int quantityDelta,
    String? reason,
  }) async {
    await _repo.adjustStockLocal(
      itemId: itemId,
      quantityDelta: quantityDelta,
      reason: reason,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    state = AsyncValue.data(await _repo.listLocalItems());
  }
}
