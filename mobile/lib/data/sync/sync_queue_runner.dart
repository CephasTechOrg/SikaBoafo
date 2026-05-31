import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';

import '../local/app_database.dart';
import '../local/sync_queue_repository.dart';
import '../remote/sync_api.dart';
import 'sync_refresh_service.dart';

class SyncQueueRunSummary {
  const SyncQueueRunSummary({
    required this.applied,
    required this.failed,
    required this.conflicts,
    required this.statusByOperationId,
  });

  final int applied;
  final int failed;
  final int conflicts;
  final Map<String, String> statusByOperationId;
}

class SyncQueueRunner {
  // NOT const: _activeRun must be a mutable instance field (see below).
  SyncQueueRunner({
    required AppDatabase appDb,
    required SyncApi syncApi,
    SyncRefreshService? refreshService,
  })  : _appDb = appDb,
        _syncApi = syncApi,
        _refreshService = refreshService;

  final AppDatabase _appDb;
  final SyncApi _syncApi;
  final SyncRefreshService? _refreshService;

  // Instance field, NOT static.
  //
  // Why not static: a static field is shared across every instance of this
  // class, including ones created in tests. When a test ends with an active run
  // future still referenced, the next test's call to run() returns the stale
  // (already-completed) future and appears to hang or skip work silently.
  //
  // An instance field is safe because syncQueueRunnerProvider is a non-autoDispose
  // singleton Provider — the app always uses a single SyncQueueRunner instance,
  // so the dedup behaviour is identical in production but test-isolated.
  Future<SyncQueueRunSummary>? _activeRun;

  Future<SyncQueueRunSummary> run({int limit = 100}) async {
    final existingRun = _activeRun;
    if (existingRun != null) {
      return existingRun;
    }

    final future = _runInternal(limit: limit);
    _activeRun = future;
    try {
      return await future;
    } finally {
      if (identical(_activeRun, future)) {
        _activeRun = null;
      }
    }
  }

  Future<SyncQueueRunSummary> _runInternal({required int limit}) async {
    final queueRows = await _appDb.syncQueue.pendingRows(limit: limit);
    if (queueRows.isEmpty) {
      return const SyncQueueRunSummary(
        applied: 0,
        failed: 0,
        conflicts: 0,
        statusByOperationId: {},
      );
    }

    int applied = 0;
    int failed = 0;
    int conflicts = 0;
    final statusByOperationId = <String, String>{};
    final refreshTargets = <String>{};
    final rowsByDevice = <String, List<Map<String, Object?>>>{};
    for (final row in queueRows) {
      final deviceId = (row['source_device_id'] ?? '') as String;
      rowsByDevice.putIfAbsent(deviceId, () => []).add(row);
    }

    for (final entry in rowsByDevice.entries) {
      final deviceId = entry.key;
      final rows = entry.value;
      if (deviceId.isEmpty) {
        for (final row in rows) {
          final queueId = row['id'] as int;
          final opId = (row['local_operation_id'] ?? '') as String;
          await _appDb.syncQueue
              .markFailed(queueId, 'Missing source_device_id.');
          if (opId.isNotEmpty) statusByOperationId[opId] = 'failed';
          failed += 1;
        }
        continue;
      }

      // Move rows that have exhausted retries to the dead-letter bucket before
      // attempting any network call.
      final liveRows = <Map<String, Object?>>[];
      for (final row in rows) {
        final attempts = (row['attempts'] as int? ?? 0);
        if (attempts >= SyncQueueRepository.maxAttempts) {
          final queueId = row['id'] as int;
          final opId = (row['local_operation_id'] ?? '') as String;
          await _appDb.syncQueue.markDead(
            queueId,
            'Exceeded ${SyncQueueRepository.maxAttempts} retry attempts.',
          );
          if (opId.isNotEmpty) statusByOperationId[opId] = 'dead';
          failed += 1;
        } else {
          liveRows.add(row);
        }
      }

      if (liveRows.isEmpty) continue;

      for (final row in liveRows) {
        await _appDb.syncQueue.markSending(row['id'] as int);
      }

      try {
        final queueIdByOpId = <String, int>{};
        final entityTypeByQueueId = <int, String>{};
        final operations = liveRows.map((row) {
          final opId = (row['local_operation_id'] ?? '') as String;
          final queueId = row['id'] as int;
          queueIdByOpId[opId] = queueId;
          entityTypeByQueueId[queueId] = (row['entity_type'] ?? '') as String;
          final payload = jsonDecode((row['payload_json'] ?? '{}') as String);
          return SyncOperationPayload(
            localOperationId: opId,
            entityType: (row['entity_type'] ?? '') as String,
            actionType: (row['operation'] ?? '') as String,
            payload: payload is Map<String, dynamic> ? payload : const {},
          );
        }).toList(growable: false);

        final results =
            await _syncApi.apply(deviceId: deviceId, operations: operations);
        final resolvedQueueIds = <int>{};
        for (final result in results) {
          final queueId = queueIdByOpId[result.localOperationId];
          if (queueId == null) continue;
          resolvedQueueIds.add(queueId);

          if (result.status == 'applied' || result.status == 'duplicate') {
            await _appDb.syncQueue.markApplied(queueId);
            final entityType = entityTypeByQueueId[queueId] ?? '';
            if (entityType == 'item' &&
                result.serverVersion != null &&
                result.entityId != null) {
              final db = await _appDb.database;
              await db.update(
                'items_local',
                {'server_version': result.serverVersion},
                where: 'id = ?',
                whereArgs: [result.entityId],
              );
            }
            statusByOperationId[result.localOperationId] = result.status;
            applied += 1;
            continue;
          }
          if (result.status == 'conflict') {
            await _appDb.syncQueue.markConflict(
              queueId,
              result.detail ?? 'Conflict with server state.',
            );
            statusByOperationId[result.localOperationId] = 'conflict';
            refreshTargets.add(entityTypeByQueueId[queueId] ?? '');
            conflicts += 1;
            continue;
          }
          await _appDb.syncQueue.markFailed(
            queueId,
            result.detail ?? 'Sync rejected by backend.',
          );
          statusByOperationId[result.localOperationId] = 'failed';
          failed += 1;
        }

        for (final entry in queueIdByOpId.entries) {
          if (resolvedQueueIds.contains(entry.value)) continue;
          await _appDb.syncQueue.markFailed(
            entry.value,
            'Backend did not return an explicit result for this operation.',
          );
          statusByOperationId[entry.key] = 'failed';
          failed += 1;
        }
      } on DioException catch (e) {
        // 429 (rate limited) and 503 (unavailable) are transient backpressure:
        // requeue without burning a retry attempt instead of failing the rows.
        final statusCode = e.response?.statusCode;
        final isTransient = statusCode == 429 || statusCode == 503;
        for (final row in liveRows) {
          final queueId = row['id'] as int;
          final opId = (row['local_operation_id'] ?? '') as String;
          if (isTransient) {
            await _appDb.syncQueue.markRetryable(
              queueId,
              e.message ?? 'Server busy. Will retry shortly.',
            );
            continue;
          }
          await _appDb.syncQueue.markFailed(
            queueId,
            e.message ?? 'Sync request failed.',
          );
          if (opId.isNotEmpty) statusByOperationId[opId] = 'failed';
          failed += 1;
        }
      } on FormatException catch (e) {
        for (final row in liveRows) {
          final queueId = row['id'] as int;
          final opId = (row['local_operation_id'] ?? '') as String;
          await _appDb.syncQueue.markFailed(queueId, e.message);
          if (opId.isNotEmpty) statusByOperationId[opId] = 'failed';
          failed += 1;
        }
      }
    }

    await _refreshConflictedTargets(refreshTargets);

    return SyncQueueRunSummary(
      applied: applied,
      failed: failed,
      conflicts: conflicts,
      statusByOperationId: statusByOperationId,
    );
  }

  Future<void> _refreshConflictedTargets(Set<String> refreshTargets) async {
    if (_refreshService == null || refreshTargets.isEmpty) {
      return;
    }
    final needsInventory = refreshTargets.any((value) =>
        value == 'inventory' || value == 'sale' || value == 'item');
    final needsDebts = refreshTargets.any(
        (value) => value == 'receivable' || value == 'receivable_payment');
    if (!needsInventory && !needsDebts) return;
    try {
      if (needsInventory && needsDebts) {
        await _refreshService.refreshInventoryAndDebtSnapshots();
      } else if (needsInventory) {
        await _refreshService.refreshInventorySnapshot();
      } else {
        await _refreshService.refreshDebtSnapshot();
      }
    } catch (_) {
      // Keep the conflict row visible even if refresh itself fails.
    }
  }
}
