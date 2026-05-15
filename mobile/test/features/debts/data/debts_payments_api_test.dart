import 'package:biztrack_gh/features/debts/data/debts_payments_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceivablePaymentVerifyOutDto', () {
    test('isPaymentSuccessful evaluates correctly', () {
      const verifySuccess1 = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'success',
        receivableStatus: 'partially_paid',
        outstandingAmount: '50.00',
        paystackTransactionStatus: 'success',
      );

      const verifySuccess2 = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'succeeded',
        receivableStatus: 'settled',
        outstandingAmount: '0.00',
        paystackTransactionStatus: 'success',
      );

      const verifyFailed = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'failed',
        receivableStatus: 'open',
        outstandingAmount: '100.00',
        paystackTransactionStatus: 'failed',
      );

      const verifyPending = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'pending',
        receivableStatus: 'open',
        outstandingAmount: '100.00',
        paystackTransactionStatus: 'pending',
      );

      expect(verifySuccess1.isPaymentSuccessful, isTrue);
      expect(verifySuccess2.isPaymentSuccessful, isTrue);
      expect(verifyFailed.isPaymentSuccessful, isFalse);
      expect(verifyPending.isPaymentSuccessful, isFalse);
    });

    test('isSettled evaluates based on receivableStatus', () {
      const verifySettled = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'success',
        receivableStatus: 'settled',
        outstandingAmount: '0.00',
        paystackTransactionStatus: 'success',
      );

      const verifyPartial = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'success',
        receivableStatus: 'partially_paid',
        outstandingAmount: '50.00',
        paystackTransactionStatus: 'success',
      );

      expect(verifySettled.isSettled, isTrue);
      expect(verifyPartial.isSettled, isFalse);
    });
  });

  group('humanizeDebtsPaymentsError', () {
    test('maps timeout-like Dio errors to backend unreachable message', () {
      final request = RequestOptions(path: '/payments/test');
      final timeoutError = DioException(
        requestOptions: request,
        type: DioExceptionType.connectionTimeout,
      );

      final message = humanizeDebtsPaymentsError(timeoutError);
      expect(message, contains('Cannot reach backend'));
    });
  });
}
