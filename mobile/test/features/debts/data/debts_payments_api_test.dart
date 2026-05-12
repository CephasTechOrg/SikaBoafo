import 'package:biztrack_gh/features/debts/data/debts_payments_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceivablePaymentVerifyOutDto', () {
    test('isPaymentSuccessful evaluates correctly', () {
      final verifySuccess1 = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'success',
        receivableStatus: 'partially_paid',
        outstandingAmount: '50.00',
        paystackTransactionStatus: 'success',
      );

      final verifySuccess2 = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'succeeded',
        receivableStatus: 'settled',
        outstandingAmount: '0.00',
        paystackTransactionStatus: 'success',
      );

      final verifyFailed = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'failed',
        receivableStatus: 'open',
        outstandingAmount: '100.00',
        paystackTransactionStatus: 'failed',
      );

      final verifyPending = ReceivablePaymentVerifyOutDto(
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
      final verifySettled = ReceivablePaymentVerifyOutDto(
        paymentId: '123',
        receivableId: '456',
        providerPaymentStatus: 'success',
        receivableStatus: 'settled',
        outstandingAmount: '0.00',
        paystackTransactionStatus: 'success',
      );

      final verifyPartial = ReceivablePaymentVerifyOutDto(
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
}
