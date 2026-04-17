import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_client.dart';
import '../../data/local/app_database.dart';
import '../../data/local/sync_queue_repository.dart';
import '../../data/remote/sync_api.dart';
import '../../data/sync/sync_queue_runner.dart';
import '../../data/sync/sync_refresh_service.dart';
import '../../features/debts/data/debts_api.dart';
import '../../features/inventory/data/inventory_api.dart';
import 'core_providers.dart';

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.backendReachable,
    required this.isSyncing,
    required this.stats,
    required this.failedEntries,
    this.lastError,
    this.lastSyncedAt,
  });

  final bool backendReachable;
  final bool isSyncing;
  final SyncQueueStats stats;
  final List<SyncQueueEntry> failedEntries;
  final String? lastError;
  final DateTime? lastSyncedAt;

  bool get hasFailures => stats.failedCount > 0;
  bool get hasConflicts => stats.conflictCount > 0;
  bool get hasPendingWork => stats.pendingCount > 0 || stats.sendingCount > 0;
}

final syncApiProvider = Provider<SyncApi>((ref) {
  return SyncApi(ref.watch(apiClientProvider));
});

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider));
});

final debtsApiProvider = Provider<DebtsApi>((ref) {
  return DebtsApi(ref.watch(apiClientProvider));
});

final syncRefreshServiceProvider = Provider<SyncRefreshService>((ref) {
  return SyncRefreshService(
    appDb: ref.watch(appDatabaseProvider),
    inventoryApi: ref.watch(inventoryApiProvider),
    debtsApi: ref.watch(debtsApiProvider),
  );
});

final syncQueueRunnerProvider = Provider<SyncQueueRunner>((ref) {
  return SyncQueueRunner(
    appDb: ref.watch(appDatabaseProvider),
    syncApi: ref.watch(syncApiProvider),
    refreshService: ref.watch(syncRefreshServiceProvider),
  );
});

final syncStatusControllerProvider =
    AsyncNotifierProvider<SyncStatusController, SyncStatusSnapshot>(
  SyncStatusController.new,
);

class SyncStatusController extends AsyncNotifier<SyncStatusSnapshot> {
  static const _pollingInterval = Duration(seconds: 20);

  AppDatabase get _appDb => ref.read(appDatabaseProvider);
  ApiClient get _apiClient => ref.read(apiClientProvider);
  SyncQueueRunner get _runner => ref.read(syncQueueRunnerProvider);

  Timer? _pollTimer;
  bool _busy = false;
  String? _lastError;
  DateTime? _lastSyncedAt;

  @override
  Future<SyncStatusSnapshot> build() async {
    _startPolling();
    ref.onDispose(() => _pollTimer?.cancel());
    return _refreshInternal(attemptSync: true);
  }

  Future<void> refreshStatus({bool attemptSync = false}) async {
    state = AsyncValue.data(
      await _refreshInternal(
        attemptSync: attemptSync,
        keepSyncingStateWhileRunning: true,
      ),
    );
  }

  Future<void> syncNow() async {
    await refreshStatus(attemptSync: true);
  }

  Future<void> retryFailed({int? queueId}) async {
    await _appDb.syncQueue.requeueFailed(id: queueId);
    await refreshStatus(attemptSync: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollingInterval, (_) {
      unawaited(refreshStatus(attemptSync: true));
    });
  }

  Future<SyncStatusSnapshot> _refreshInternal({
    required bool attemptSync,
    bool keepSyncingStateWhileRunning = false,
  }) async {
    if (_busy) {
      return state.valueOrNull ?? await _readSnapshot();
    }

    _busy = true;
    try {
      final reachable = await _pingBackend();
      if (attemptSync && reachable) {
        if (keepSyncingStateWhileRunning) {
          final beforeSync = await _readSnapshot(
            backendReachable: true,
            isSyncing: true,
          );
          state = AsyncValue.data(beforeSync);
        }

        final result = await _runner.run();
        if (result.failed > 0) {
          _lastError = 'Some operations need retry.';
        } else if (result.conflicts > 0) {
          _lastError = 'Server state changed. Local snapshot was refreshed.';
        } else {
          _lastError = null;
          if (result.applied > 0) {
            _lastSyncedAt = DateTime.now();
          }
        }
      } else if (attemptSync && !reachable) {
        _lastError = 'Backend unreachable.';
      }

      return _readSnapshot(backendReachable: reachable);
    } catch (error) {
      _lastError = _humanizeError(error);
      return _readSnapshot(backendReachable: false);
    } finally {
      _busy = false;
    }
  }

  Future<SyncStatusSnapshot> _readSnapshot({
    bool? backendReachable,
    bool isSyncing = false,
  }) async {
    final stats = await _appDb.syncQueue.stats();
    final failedEntries = await _appDb.syncQueue.failedRows();
    return SyncStatusSnapshot(
      backendReachable: backendReachable ?? false,
      isSyncing: isSyncing || stats.sendingCount > 0,
      stats: stats,
      failedEntries: failedEntries,
      lastError: _lastError,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<bool> _pingBackend() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/health');
      final data = response.data;
      return data is Map<String, dynamic> && data['status'] == 'ok';
    } on DioException {
      return false;
    } on FormatException {
      return false;
    }
  }

  String _humanizeError(Object error) {
    if (error is DioException) {
      return error.message ?? 'Sync request failed.';
    }
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
