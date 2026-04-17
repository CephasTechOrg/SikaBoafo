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
  });

  final String localOperationId;
  final String status;
  final String? entityId;
  final String? detail;

  factory SyncApplyResult.fromJson(Map<String, dynamic> json) {
    return SyncApplyResult(
      localOperationId: (json['local_operation_id'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      entityId: json['entity_id'] as String?,
      detail: json['detail'] as String?,
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
        'operations': operations.map((op) => op.toJson()).toList(growable: false),
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
}
