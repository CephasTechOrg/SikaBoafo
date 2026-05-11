import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

/// Customer summary returned by `GET /receivables/customers`.
class DebtCustomerDto {
  const DebtCustomerDto({
    required this.customerId,
    required this.name,
    required this.totalOutstanding,
    required this.createdAtIso,
    this.phoneNumber,
    this.whatsappNumber,
    this.email,
    this.notes,
  });

  final String customerId;
  final String name;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? email;
  final String? notes;
  final String totalOutstanding;
  final String createdAtIso;

  factory DebtCustomerDto.fromJson(Map<String, dynamic> json) {
    return DebtCustomerDto(
      customerId: (json['customer_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      phoneNumber: json['phone_number'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      totalOutstanding: '${json['total_outstanding'] ?? '0.00'}',
      createdAtIso: (json['created_at'] ?? '') as String,
    );
  }
}

/// Receivable returned by `GET /receivables` and `GET /receivables/{id}`.
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
    this.invoiceNumber,
    this.saleId,
    this.createdByUserId,
    this.paymentLink,
    this.paymentProviderReference,
  });

  final String receivableId;
  final String customerId;
  final String customerName;
  final String originalAmount;
  final String outstandingAmount;
  final String status;
  final String? dueDateIso;
  final String? invoiceNumber;
  final String? saleId;
  final String? createdByUserId;
  final String? paymentLink;
  final String? paymentProviderReference;
  final String createdAtIso;

  factory ReceivableDto.fromJson(Map<String, dynamic> json) {
    return ReceivableDto(
      receivableId: (json['receivable_id'] ?? '') as String,
      customerId: (json['customer_id'] ?? '') as String,
      customerName: (json['customer_name'] ?? '') as String,
      originalAmount: '${json['original_amount'] ?? '0.00'}',
      outstandingAmount: '${json['outstanding_amount'] ?? '0.00'}',
      status: (json['status'] ?? 'open') as String,
      dueDateIso: json['due_date'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      saleId: json['sale_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      paymentLink: json['payment_link'] as String?,
      paymentProviderReference: json['payment_provider_reference'] as String?,
      createdAtIso: (json['created_at'] ?? '') as String,
    );
  }
}

/// Repayment record returned by `POST /receivables/{id}/repayments`.
class ReceivablePaymentDto {
  const ReceivablePaymentDto({
    required this.paymentId,
    required this.receivableId,
    required this.amount,
    required this.paymentMethodLabel,
    required this.createdAtIso,
  });

  final String paymentId;
  final String receivableId;
  final String amount;
  final String paymentMethodLabel;
  final String createdAtIso;

  factory ReceivablePaymentDto.fromJson(Map<String, dynamic> json) {
    return ReceivablePaymentDto(
      paymentId: (json['payment_id'] ?? '') as String,
      receivableId: (json['receivable_id'] ?? '') as String,
      amount: '${json['amount'] ?? '0.00'}',
      paymentMethodLabel: (json['payment_method_label'] ?? 'cash') as String,
      createdAtIso: (json['created_at'] ?? '') as String,
    );
  }
}

/// Customer + their receivables returned by `GET /receivables/customers/{id}`.
class CustomerDetailDto {
  const CustomerDetailDto({required this.customer, required this.receivables});

  final DebtCustomerDto customer;
  final List<ReceivableDto> receivables;

  factory CustomerDetailDto.fromJson(Map<String, dynamic> json) {
    final rawReceivables = json['receivables'];
    final receivables = rawReceivables is List
        ? rawReceivables
            .whereType<Map<String, dynamic>>()
            .map(ReceivableDto.fromJson)
            .toList(growable: false)
        : const <ReceivableDto>[];
    final rawCustomer = json['customer'];
    final customer = rawCustomer is Map<String, dynamic>
        ? DebtCustomerDto.fromJson(rawCustomer)
        : DebtCustomerDto.fromJson(const {});
    return CustomerDetailDto(customer: customer, receivables: receivables);
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
      throw const FormatException('Unexpected customers payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(DebtCustomerDto.fromJson)
        .toList(growable: false);
  }

  Future<CustomerDetailDto> fetchCustomerDetail(String customerId) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/receivables/customers/$customerId',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected customer detail payload.');
    }
    return CustomerDetailDto.fromJson(data);
  }

  Future<List<ReceivableDto>> fetchReceivables({int limit = 100}) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/receivables',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Unexpected receivables payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ReceivableDto.fromJson)
        .toList(growable: false);
  }

  Future<ReceivableDto> fetchReceivable(String receivableId) async {
    final response =
        await _apiClient.dio.get<dynamic>('/receivables/$receivableId');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected receivable payload.');
    }
    return ReceivableDto.fromJson(data);
  }

  Future<ReceivableDto> cancelReceivable(String receivableId) async {
    final response = await _apiClient.dio
        .post<dynamic>('/receivables/$receivableId/cancel');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected cancel response payload.');
    }
    return ReceivableDto.fromJson(data);
  }
}

String humanizeDebtsApiError(Object error) {
  if (error is FormatException) return error.message;
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic>) {
      final raw = detail['detail'];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is Map<String, dynamic>) {
          final msg = first['msg'];
          if (msg is String && msg.trim().isNotEmpty) return msg.trim();
        }
      }
    }
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Changes will sync later.';
    }
    final code = error.response?.statusCode;
    if (code != null) {
      return 'Debts request failed (HTTP $code). ${error.message ?? ''}'
          .trim();
    }
    return error.message ?? 'Debts request failed.';
  }
  return 'Debts request failed.';
}
