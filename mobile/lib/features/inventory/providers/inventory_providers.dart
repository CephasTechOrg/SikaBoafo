import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/notifications_service.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/freshness_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../../settings/providers/notification_prefs_provider.dart';
import '../data/inventory_api.dart';
import '../data/inventory_repository.dart';
import '../data/local_variant.dart';

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
  static const _lowStockNotifyKey = 'low_stock_notified_date';

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
    await _maybeNotifyLowStock(local);
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
      ref.invalidate(freshnessTsProvider(KvCacheRepository.kInventoryTs));
    } catch (_) {
      // Ignore network errors during refresh to keep local data visible.
    }
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> createItem({
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    int initialQuantity = 0,
    String? imageUrl,
    List<LocalVariant> variants = const [],
  }) async {
    await _repo.createItemLocal(
      name: name,
      defaultPrice: defaultPrice,
      sku: sku,
      category: category,
      lowStockThreshold: lowStockThreshold,
      initialQuantity: initialQuantity,
      imageUrl: imageUrl,
      variants: variants,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> updateItem({
    required String itemId,
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    required bool isActive,
    String? imageUrl,
    bool imageUrlChanged = false,
    List<LocalVariant>? variants,
    bool variantsChanged = false,
  }) async {
    await _repo.updateItemLocal(
      itemId: itemId,
      name: name,
      defaultPrice: defaultPrice,
      sku: sku,
      category: category,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
      imageUrl: imageUrl,
      imageUrlChanged: imageUrlChanged,
      variants: variants,
      variantsChanged: variantsChanged,
    );
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> archiveItem({required String itemId}) async {
    await _repo.archiveItemLocal(itemId: itemId);
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> restoreItem({required String itemId}) async {
    await _repo.restoreItemLocal(itemId: itemId);
    await _repo.syncPendingQueue();
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
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
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
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
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> deleteItem({required String itemId}) async {
    await _repo.deleteItemLocal(itemId: itemId);
    await ref.read(syncStatusControllerProvider.notifier).refreshStatus();
    final items = await _repo.listLocalItems();
    await _maybeNotifyLowStock(items);
    state = AsyncValue.data(items);
  }

  Future<void> _maybeNotifyLowStock(List<LocalInventoryItem> items) async {
    final prefs = ref.read(notificationPrefsProvider).valueOrNull;
    if (prefs == null || prefs.lowStockEnabled != true) return;

    final low = items
        .where((i) =>
            i.isActive &&
            i.lowStockThreshold != null &&
            i.quantityOnHand <= i.lowStockThreshold!)
        .toList(growable: false);
    if (low.isEmpty) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final kv = ref.read(appDatabaseProvider).kv;
    final last = await kv.get(_lowStockNotifyKey);
    if (last == '"$today"') return;

    const android = AndroidNotificationDetails(
      'low_stock',
      'Low stock',
      channelDescription: 'Alerts when items are running low',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.forest,
    );

    await ref.read(notificationsServiceProvider).showNow(
          id: 3001,
          type: AppNotificationType.lowStock,
          title: 'Low stock',
          body: '${low.length} item${low.length == 1 ? '' : 's'} need restocking.',
          android: android,
          route: AppRoute.inventory.path,
        );
    await kv.put(_lowStockNotifyKey, '"$today"');
  }
}
