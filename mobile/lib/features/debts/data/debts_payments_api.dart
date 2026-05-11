import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

/// Initiation result from `POST /payments/initiate` for a receivable.
/// Mirror of `SalePaymentInitiationDto`.
class ReceivablePaymentInitiationDto {
  const ReceivablePaymentInitiationDto({
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

  factory ReceivablePaymentInitiationDto.fromJson(Map<String, dynamic> json) {
    return ReceivablePaymentInitiationDto(
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

  Future<ReceivablePaymentInitiationDto> initiatePayment(
    String receivableId,
  ) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/payments/initiate',
      data: {'receivable_id': receivableId},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'Unexpected receivable payment initiation payload.',
      );
    }
    return ReceivablePaymentInitiationDto.fromJson(data);
  }
}

String humanizeDebtsPaymentsError(Object error) {
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
      return 'Cannot reach backend. Try again when online.';
    }
    final code = error.response?.statusCode;
    if (code != null) {
      return 'Payment request failed (HTTP $code). ${error.message ?? ''}'
          .trim();
    }
    return error.message ?? 'Payment request failed.';
  }
  return 'Payment request failed.';
}
