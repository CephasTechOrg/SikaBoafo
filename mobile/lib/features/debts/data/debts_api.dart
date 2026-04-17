import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

class DebtCustomerDto {
  const DebtCustomerDto({
    required this.customerId,
    required this.name,
    this.phoneNumber,
  });

  final String customerId;
  final String name;
  final String? phoneNumber;

  factory DebtCustomerDto.fromJson(Map<String, dynamic> json) {
    return DebtCustomerDto(
      customerId: (json['customer_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      phoneNumber: json['phone_number'] as String?,
    );
  }
}

class ReceivableDto {
  const ReceivableDto({
    required this.receivableId,
    required this.customerId,
    required this.customerName,
    required this.originalAmount,
    required this.outstandingAmount,
    required this.status,
    required this.createdAtIso,
    this.dueDateIso,
  });

  final String receivableId;
  final String customerId;
  final String customerName;
  final String originalAmount;
  final String outstandingAmount;
  final String status;
  final String createdAtIso;
  final String? dueDateIso;

  factory ReceivableDto.fromJson(Map<String, dynamic> json) {
    return ReceivableDto(
      receivableId: (json['receivable_id'] ?? '') as String,
      customerId: (json['customer_id'] ?? '') as String,
      customerName: (json['customer_name'] ?? 'Unknown Customer') as String,
      originalAmount: '${json['original_amount'] ?? '0.00'}',
      outstandingAmount: '${json['outstanding_amount'] ?? '0.00'}',
      status: (json['status'] ?? 'open') as String,
      createdAtIso: (json['created_at'] ?? '') as String,
      dueDateIso: json['due_date'] as String?,
    );
  }
}

class DebtsApi {
  DebtsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DebtCustomerDto>> fetchCustomers({int limit = 200}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/receivables/customers',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Unexpected customer list payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(DebtCustomerDto.fromJson)
        .toList(growable: false);
  }

  Future<List<ReceivableDto>> fetchReceivables({int limit = 100}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/receivables',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Unexpected receivable list payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ReceivableDto.fromJson)
        .toList(growable: false);
  }
}

String humanizeDebtsApiError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Working offline.';
    }
    return error.message ?? 'Debt sync request failed.';
  }
  return 'Debt sync request failed.';
}
