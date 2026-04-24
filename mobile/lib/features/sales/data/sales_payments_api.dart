import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

class SalePaymentInitiationDto {
  const SalePaymentInitiationDto({
    required this.paymentId,
    required this.provider,
    required this.providerReference,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.status,
    required this.saleId,
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
  final String saleId;

  factory SalePaymentInitiationDto.fromJson(Map<String, dynamic> json) {
    return SalePaymentInitiationDto(
      paymentId: (json['payment_id'] ?? '') as String,
      provider: (json['provider'] ?? 'paystack') as String,
      providerReference: (json['provider_reference'] ?? '') as String,
      checkoutUrl: (json['checkout_url'] ?? '') as String,
      accessCode: json['access_code'] as String?,
      amount: '${json['amount'] ?? '0.00'}',
      currency: (json['currency'] ?? 'GHS') as String,
      status: (json['status'] ?? 'pending') as String,
      saleId: (json['sale_id'] ?? '') as String,
    );
  }
}

class SalePaymentStatusDto {
  const SalePaymentStatusDto({
    required this.saleId,
    required this.paymentStatus,
    required this.saleStatus,
  });

  final String saleId;
  final String paymentStatus;
  final String saleStatus;

  bool get isTerminal =>
      paymentStatus == 'succeeded' || paymentStatus == 'failed';

  factory SalePaymentStatusDto.fromJson(Map<String, dynamic> json) {
    return SalePaymentStatusDto(
      saleId: (json['sale_id'] ?? '') as String,
      paymentStatus: (json['payment_status'] ?? 'recorded') as String,
      saleStatus: (json['sale_status'] ?? 'recorded') as String,
    );
  }
}

class SalesPaymentsApi {
  SalesPaymentsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<SalePaymentInitiationDto> initiateSalePayment(String saleId) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/payments/initiate-sale',
      data: {'sale_id': saleId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
          'Unexpected sale payment initiation payload.');
    }
    return SalePaymentInitiationDto.fromJson(data);
  }

  Future<SalePaymentStatusDto> fetchSalePaymentStatus(String saleId) async {
    final response = await _apiClient.dio.get<dynamic>('/sales/$saleId');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected sale payment status payload.');
    }
    return SalePaymentStatusDto.fromJson(data);
  }
}

String humanizeSalesPaymentsError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Sale saved locally.';
    }
    return error.message ?? 'Payment initiation failed.';
  }
  return 'Payment initiation failed.';
}
