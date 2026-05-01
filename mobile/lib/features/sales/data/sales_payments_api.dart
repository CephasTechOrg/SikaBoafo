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

class SaleMomoChargeOutDto {
  const SaleMomoChargeOutDto({
    required this.paymentId,
    required this.provider,
    required this.providerReference,
    required this.amount,
    required this.currency,
    required this.status,
    required this.saleId,
    this.displayText,
  });

  final String paymentId;
  final String provider;
  final String providerReference;
  final String amount;
  final String currency;
  final String status;
  final String saleId;
  final String? displayText;

  factory SaleMomoChargeOutDto.fromJson(Map<String, dynamic> json) {
    return SaleMomoChargeOutDto(
      paymentId: (json['payment_id'] ?? '') as String,
      provider: (json['provider'] ?? 'paystack') as String,
      providerReference: (json['provider_reference'] ?? '') as String,
      amount: '${json['amount'] ?? '0.00'}',
      currency: (json['currency'] ?? 'GHS') as String,
      status: (json['status'] ?? 'pending') as String,
      saleId: (json['sale_id'] ?? '') as String,
      displayText: json['display_text'] as String?,
    );
  }
}

class PaymentVerifyOutDto {
  const PaymentVerifyOutDto({
    required this.paymentId,
    required this.saleId,
    required this.providerPaymentStatus,
    required this.salePaymentStatus,
    required this.paystackTransactionStatus,
  });

  final String paymentId;
  final String saleId;
  final String providerPaymentStatus;
  final String salePaymentStatus;
  final String paystackTransactionStatus;

  factory PaymentVerifyOutDto.fromJson(Map<String, dynamic> json) {
    return PaymentVerifyOutDto(
      paymentId: (json['payment_id'] ?? '') as String,
      saleId: (json['sale_id'] ?? '') as String,
      providerPaymentStatus:
          (json['provider_payment_status'] ?? '') as String,
      salePaymentStatus: (json['sale_payment_status'] ?? '') as String,
      paystackTransactionStatus:
          (json['paystack_transaction_status'] ?? '') as String,
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

  Future<SaleMomoChargeOutDto> initiateSaleMomoCharge({
    required String saleId,
    required String phone,
    required String provider,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/payments/sales/$saleId/momo-charge',
      data: {'phone': phone, 'provider': provider},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected MoMo charge payload.');
    }
    return SaleMomoChargeOutDto.fromJson(data);
  }

  Future<PaymentVerifyOutDto> verifySalePayment(String paymentId) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/payments/$paymentId/verify',
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected payment verify payload.');
    }
    return PaymentVerifyOutDto.fromJson(data);
  }
}

String humanizeSalesPaymentsError(Object error) {
  if (error is FormatException) {
    return error.message;
  }
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic>) {
      final raw = detail['detail'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        if (first is Map<String, dynamic>) {
          final msg = first['msg'];
          if (msg is String && msg.trim().isNotEmpty) {
            return msg.trim();
          }
        }
      }
    }
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach backend. Sale saved locally.';
    }
    final code = error.response?.statusCode;
    if (code != null) {
      return 'Payment request failed (HTTP $code). ${error.message ?? ''}'.trim();
    }
    return error.message ?? 'Payment initiation failed.';
  }
  return 'Payment initiation failed.';
}
