import 'package:dio/dio.dart';

import '../../../app/env/app_config.dart';
import '../../../core/services/api_client.dart';

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

class DebtsPaymentsApi {
  DebtsPaymentsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<PaymentInitiationDto> initiateReceivablePaymentLink(
    String receivableId,
  ) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/payments/initiate',
        data: {'receivable_id': receivableId},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Unexpected payment initiation payload.');
      }
      return PaymentInitiationDto.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final expected = AppConfig.apiV1('/payments/initiate');
        throw DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error:
              'Endpoint not found (404). Expected backend route: $expected. '
              'Check API_BASE_URL points to the backend from this codebase.',
        );
      }
      rethrow;
    }
  }
}
