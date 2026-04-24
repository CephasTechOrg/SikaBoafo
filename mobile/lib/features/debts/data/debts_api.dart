import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

class DebtCustomerDto {
  const DebtCustomerDto({
    required this.customerId,
    required this.name,
    this.phoneNumber,
    this.whatsappNumber,
    this.email,
    this.notes,
    this.totalOutstanding = '0.00',
  });

  final String customerId;
  final String name;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? email;
  final String? notes;
  final String totalOutstanding;

  factory DebtCustomerDto.fromJson(Map<String, dynamic> json) {
    return DebtCustomerDto(
      customerId: (json['customer_id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      phoneNumber: json['phone_number'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      totalOutstanding: '${json['total_outstanding'] ?? '0.00'}',
    );
  }
}

class CustomerDetailDto {
  const CustomerDetailDto({
    required this.customer,
    required this.receivables,
  });

  final DebtCustomerDto customer;
  final List<ReceivableDto> receivables;

  factory CustomerDetailDto.fromJson(Map<String, dynamic> json) {
    return CustomerDetailDto(
      customer: DebtCustomerDto.fromJson(
        json['customer'] as Map<String, dynamic>? ?? {},
      ),
      receivables: (json['receivables'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ReceivableDto.fromJson)
          .toList(growable: false),
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
    this.invoiceNumber,
    this.paymentLink,
  });

  final String receivableId;
  final String customerId;
  final String customerName;
  final String originalAmount;
  final String outstandingAmount;
  final String status;
  final String createdAtIso;
  final String? dueDateIso;
  final String? invoiceNumber;
  final String? paymentLink;

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
      invoiceNumber: json['invoice_number'] as String?,
      paymentLink: json['payment_link'] as String?,
    );
  }
}

class PaymentInitiationDto {
  const PaymentInitiationDto({
    required this.paymentId,
    required this.provider,
    required this.providerReference,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.status,
    required this.receivableId,
    this.accessCode,
  });

  final String paymentId;
  final String provider;
  final String providerReference;
  final String checkoutUrl;
  final String? accessCode;
  final String amount;
  final String currency;
  final String status;
  final String receivableId;

  factory PaymentInitiationDto.fromJson(Map<String, dynamic> json) {
    return PaymentInitiationDto(
      paymentId: (json['payment_id'] ?? '') as String,
      provider: (json['provider'] ?? 'paystack') as String,
      providerReference: (json['provider_reference'] ?? '') as String,
      checkoutUrl: (json['checkout_url'] ?? '') as String,
      accessCode: json['access_code'] as String?,
      amount: '${json['amount'] ?? '0.00'}',
      currency: (json['currency'] ?? 'GHS') as String,
      status: (json['status'] ?? 'pending') as String,
      receivableId: (json['receivable_id'] ?? '') as String,
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
      throw const FormatException('Unexpected receivable list payload.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ReceivableDto.fromJson)
        .toList(growable: false);
  }

  Future<ReceivableDto> fetchReceivableById(String receivableId) async {
    final response = await _apiClient.dio.get<dynamic>(
      '/receivables/$receivableId',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected receivable detail payload.');
    }
    return ReceivableDto.fromJson(data);
  }

  Future<ReceivableDto> cancelReceivable(String receivableId) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/receivables/$receivableId/cancel',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected cancel payload.');
    }
    return ReceivableDto.fromJson(data);
  }

  Future<PaymentInitiationDto> initiateReceivablePaymentLink(
    String receivableId,
  ) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/payments/initiate',
      data: {'receivable_id': receivableId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected payment initiation payload.');
    }
    return PaymentInitiationDto.fromJson(data);
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
