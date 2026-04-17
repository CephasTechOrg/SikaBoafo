import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/data/local/app_database.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:biztrack_gh/data/remote/sync_api.dart';
import 'package:biztrack_gh/data/sync/sync_queue_runner.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_api.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/inventory/providers/inventory_providers.dart';
import 'package:biztrack_gh/shared/providers/sync_providers.dart';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

ApiClient _dummyApiClient() {
  return ApiClient(
    tokenStorage: _FakeSecureTokenStorage(),
    dio: Dio(),
  );
}

class _DummySyncApi extends SyncApi {
  _DummySyncApi() : super(_dummyApiClient());

  @override
  Future<List<SyncApplyResult>> apply({
    required String deviceId,
    required List<SyncOperationPayload> operations,
  }) async {
    return const [];
  }
}

class _DummyAppDatabase extends AppDatabase {
  @override
  SyncQueueRepository get syncQueue => SyncQueueRepository(this);
}

class _DummyInventoryApi extends InventoryApi {
  _DummyInventoryApi() : super(_dummyApiClient());
}

class _FakeInventoryRepository extends InventoryRepository {
  _FakeInventoryRepository({
    required this.callLog,
    required this.localItems,
  }) : super(
          appDb: _DummyAppDatabase(),
          inventoryApi: _DummyInventoryApi(),
          syncQueueRunner: SyncQueueRunner(
            appDb: _DummyAppDatabase(),
            syncApi: _DummySyncApi(),
          ),
        );

  final List<String> callLog;
  final List<LocalInventoryItem> localItems;

  @override
  Future<SyncRunSummary> syncPendingQueue({int limit = 100}) async {
    callLog.add('syncPendingQueue');
    return const SyncRunSummary(applied: 1, failed: 0);
  }

  @override
  Future<void> refreshFromServer() async {
    callLog.add('refreshFromServer');
  }

  @override
  Future<List<LocalInventoryItem>> listLocalItems() async {
    callLog.add('listLocalItems');
    return localItems;
  }
}

class _FakeSyncStatusController extends SyncStatusController {
  @override
  Future<SyncStatusSnapshot> build() async {
    return const SyncStatusSnapshot(
      backendReachable: true,
      isSyncing: false,
      stats: SyncQueueStats(
        pendingCount: 0,
        sendingCount: 0,
        failedCount: 0,
        conflictCount: 0,
        appliedCount: 0,
      ),
      failedEntries: <SyncQueueEntry>[],
    );
  }

  @override
  Future<void> refreshStatus({bool attemptSync = false}) async {}
}

void main() {
  test('inventory refresh syncs pending local ops before server refresh',
      () async {
    final calls = <String>[];
    final repo = _FakeInventoryRepository(
      callLog: calls,
      localItems: const [
        LocalInventoryItem(
          id: 'item-1',
          name: 'Rice',
          defaultPrice: '10.00',
          quantityOnHand: 8,
          lowStockThreshold: 2,
          isActive: true,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        syncStatusControllerProvider
            .overrideWith(_FakeSyncStatusController.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(inventoryControllerProvider.future);
    calls.clear();

    await container.read(inventoryControllerProvider.notifier).refresh();

    expect(calls,
        <String>['syncPendingQueue', 'refreshFromServer', 'listLocalItems']);
  });
}
