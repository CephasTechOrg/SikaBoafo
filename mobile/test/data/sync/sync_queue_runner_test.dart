import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/data/local/app_database.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:biztrack_gh/data/remote/sync_api.dart';
import 'package:biztrack_gh/data/sync/sync_queue_runner.dart';

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

class _FakeSyncApi extends SyncApi {
  _FakeSyncApi(this._applyHandler) : super(_dummyApiClient());

  final Future<List<SyncApplyResult>> Function(
    String deviceId,
    List<SyncOperationPayload> operations,
  ) _applyHandler;

  @override
  Future<List<SyncApplyResult>> apply({
    required String deviceId,
    required List<SyncOperationPayload> operations,
  }) {
    return _applyHandler(deviceId, operations);
  }
}

class _FakeAppDatabase extends AppDatabase {
  _FakeAppDatabase(List<Map<String, Object?>> initialRows) {
    queue = _FakeSyncQueueRepository(this, initialRows);
  }

  late final _FakeSyncQueueRepository queue;

  @override
  SyncQueueRepository get syncQueue => queue;
}

class _FakeSyncQueueRepository extends SyncQueueRepository {
  _FakeSyncQueueRepository(super.appDb, List<Map<String, Object?>> initialRows)
      : _rows = initialRows
            .map((row) => Map<String, Object?>.from(row))
            .toList(growable: false);

  final List<Map<String, Object?>> _rows;

  Map<String, Object?> rowById(int id) {
    return _rows.firstWhere((row) => row['id'] == id);
  }

  @override
  Future<List<Map<String, Object?>>> pendingRows({int limit = 100}) async {
    final rows = _rows
        .where(
          (row) =>
              row['status'] == SyncQueueRepository.pending ||
              row['status'] == SyncQueueRepository.failed,
        )
        .take(limit)
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
    return rows;
  }

  @override
  Future<void> markSending(int id) async {
    rowById(id)['status'] = SyncQueueRepository.sending;
  }

  @override
  Future<void> markApplied(int id) async {
    final row = rowById(id);
    row['status'] = SyncQueueRepository.applied;
    row['last_error'] = null;
  }

  @override
  Future<void> markFailed(int id, String message) async {
    final row = rowById(id);
    row['status'] = SyncQueueRepository.failed;
    row['last_error'] = message;
    row['attempts'] = ((row['attempts'] as int?) ?? 0) + 1;
  }

  @override
  Future<void> markConflict(int id, String message) async {
    final row = rowById(id);
    row['status'] = SyncQueueRepository.conflict;
    row['last_error'] = message;
    row['attempts'] = ((row['attempts'] as int?) ?? 0) + 1;
  }
}

Map<String, Object?> _queueRow({
  required int id,
  required String deviceId,
  required String opId,
  required String entityType,
  required String operation,
  String status = SyncQueueRepository.pending,
  String payloadJson = '{}',
}) {
  return {
    'id': id,
    'source_device_id': deviceId,
    'local_operation_id': opId,
    'entity_type': entityType,
    'operation': operation,
    'payload_json': payloadJson,
    'status': status,
    'attempts': 0,
    'created_at': id,
  };
}

void main() {
  test('marks applied for applied and duplicate statuses', () async {
    final appDb = _FakeAppDatabase([
      _queueRow(
        id: 1,
        deviceId: 'dev-1',
        opId: 'op-1',
        entityType: 'sale',
        operation: 'create',
      ),
      _queueRow(
        id: 2,
        deviceId: 'dev-1',
        opId: 'op-2',
        entityType: 'expense',
        operation: 'create',
      ),
    ]);

    final runner = SyncQueueRunner(
      appDb: appDb,
      syncApi: _FakeSyncApi((_, __) async {
        return const [
          SyncApplyResult(localOperationId: 'op-1', status: 'applied'),
          SyncApplyResult(localOperationId: 'op-2', status: 'duplicate'),
        ];
      }),
    );

    final summary = await runner.run();

    expect(summary.applied, 2);
    expect(summary.failed, 0);
    expect(summary.conflicts, 0);
    expect(summary.statusByOperationId['op-1'], 'applied');
    expect(summary.statusByOperationId['op-2'], 'duplicate');
    expect(appDb.queue.rowById(1)['status'], SyncQueueRepository.applied);
    expect(appDb.queue.rowById(2)['status'], SyncQueueRepository.applied);
  });

  test('marks failed and conflict from backend result statuses', () async {
    final appDb = _FakeAppDatabase([
      _queueRow(
        id: 1,
        deviceId: 'dev-1',
        opId: 'op-1',
        entityType: 'inventory',
        operation: 'adjust',
      ),
      _queueRow(
        id: 2,
        deviceId: 'dev-1',
        opId: 'op-2',
        entityType: 'sale',
        operation: 'create',
      ),
    ]);

    final runner = SyncQueueRunner(
      appDb: appDb,
      syncApi: _FakeSyncApi((_, __) async {
        return const [
          SyncApplyResult(
            localOperationId: 'op-1',
            status: 'conflict',
            detail: 'Server has newer state.',
          ),
          SyncApplyResult(
            localOperationId: 'op-2',
            status: 'failed',
            detail: 'Validation rejected payload.',
          ),
        ];
      }),
    );

    final summary = await runner.run();

    expect(summary.applied, 0);
    expect(summary.failed, 1);
    expect(summary.conflicts, 1);
    expect(summary.statusByOperationId['op-1'], 'conflict');
    expect(summary.statusByOperationId['op-2'], 'failed');
    expect(appDb.queue.rowById(1)['status'], SyncQueueRepository.conflict);
    expect(appDb.queue.rowById(2)['status'], SyncQueueRepository.failed);
  });

  test('missing source_device_id marks row failed without calling API',
      () async {
    var apiCalled = false;
    final appDb = _FakeAppDatabase([
      _queueRow(
        id: 1,
        deviceId: '',
        opId: 'op-1',
        entityType: 'sale',
        operation: 'create',
      ),
    ]);

    final runner = SyncQueueRunner(
      appDb: appDb,
      syncApi: _FakeSyncApi((_, __) async {
        apiCalled = true;
        return const [];
      }),
    );

    final summary = await runner.run();

    expect(apiCalled, isFalse);
    expect(summary.applied, 0);
    expect(summary.failed, 1);
    expect(summary.conflicts, 0);
    expect(summary.statusByOperationId['op-1'], 'failed');
    expect(appDb.queue.rowById(1)['status'], SyncQueueRepository.failed);
  });

  test('transport exception marks all grouped rows failed', () async {
    final appDb = _FakeAppDatabase([
      _queueRow(
        id: 1,
        deviceId: 'dev-1',
        opId: 'op-1',
        entityType: 'expense',
        operation: 'create',
      ),
      _queueRow(
        id: 2,
        deviceId: 'dev-1',
        opId: 'op-2',
        entityType: 'expense',
        operation: 'create',
      ),
    ]);

    final runner = SyncQueueRunner(
      appDb: appDb,
      syncApi: _FakeSyncApi((_, __) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/sync/apply'),
          type: DioExceptionType.connectionError,
          message: 'Network offline.',
        );
      }),
    );

    final summary = await runner.run();

    expect(summary.applied, 0);
    expect(summary.failed, 2);
    expect(summary.conflicts, 0);
    expect(summary.statusByOperationId['op-1'], 'failed');
    expect(summary.statusByOperationId['op-2'], 'failed');
    expect(appDb.queue.rowById(1)['status'], SyncQueueRepository.failed);
    expect(appDb.queue.rowById(2)['status'], SyncQueueRepository.failed);
  });
}
