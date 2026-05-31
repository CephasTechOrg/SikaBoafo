import '../../core/services/api_client.dart';

class SyncOperationPayload {
  const SyncOperationPayload({
    required this.localOperationId,
    required this.entityType,
    required this.actionType,
    required this.payload,
  });

  final String localOperationId;
  final String entityType;
  final String actionType;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'local_operation_id': localOperationId,
        'entity_type': entityType,
        'action_type': actionType,
        'payload': payload,
      };
}

class SyncApplyResult {
  const SyncApplyResult({
    required this.localOperationId,
    required this.status,
    this.entityId,
    this.detail,
    this.serverVersion,
  });

  final String localOperationId;
  final String status;
  final String? entityId;
  final String? detail;
  final int? serverVersion;

  factory SyncApplyResult.fromJson(Map<String, dynamic> json) {
    return SyncApplyResult(
      localOperationId: (json['local_operation_id'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      entityId: json['entity_id'] as String?,
      detail: json['detail'] as String?,
      serverVersion: json['server_version'] as int?,
    );
  }
}

class SyncApi {
  SyncApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SyncApplyResult>> apply({
    required String deviceId,
    required List<SyncOperationPayload> operations,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/sync/apply',
      data: {
        'device_id': deviceId,
        'operations':
            operations.map((op) => op.toJson()).toList(growable: false),
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected sync apply payload.');
    }
    final rows = data['results'];
    if (rows is! List) {
      throw const FormatException('Sync apply results missing.');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(SyncApplyResult.fromJson)
        .toList(growable: false);
  }

  Future<SyncPullResult> pull({
    DateTime? since,
    String? include,
    int limit = 500,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (since != null) {
      query['since'] = since.toUtc().toIso8601String();
    }
    if (include != null && include.trim().isNotEmpty) {
      query['include'] = include;
    }
    final response = await _apiClient.dio.get<dynamic>(
      '/sync/pull',
      queryParameters: query,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected sync pull payload.');
    }
    return SyncPullResult.fromJson(data);
  }
}

class SyncPullResult {
  const SyncPullResult({
    required this.cursor,
    required this.fullRefresh,
    required this.inventory,
    required this.customers,
    required this.receivables,
  });

  final DateTime cursor;
  final bool fullRefresh;
  final List<Map<String, dynamic>> inventory;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> receivables;

  factory SyncPullResult.fromJson(Map<String, dynamic> json) {
    final cursorRaw = (json['cursor'] ?? '') as String;
    final parsedCursor = DateTime.tryParse(cursorRaw)?.toUtc();
    if (parsedCursor == null) {
      throw FormatException('Invalid sync pull cursor: $cursorRaw');
    }
    List<Map<String, dynamic>> rows(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    return SyncPullResult(
      cursor: parsedCursor,
      fullRefresh: json['full_refresh'] == true,
      inventory: rows(json['inventory']),
      customers: rows(json['customers']),
      receivables: rows(json['receivables']),
    );
  }
}
