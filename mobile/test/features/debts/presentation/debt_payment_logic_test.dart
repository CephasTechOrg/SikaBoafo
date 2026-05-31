import 'package:biztrack_gh/features/debts/data/debts_api.dart';
import 'package:biztrack_gh/features/debts/data/debts_payments_api.dart';
import 'package:biztrack_gh/features/debts/presentation/utils/debt_payment_amount_validator.dart';
import 'package:biztrack_gh/features/debts/presentation/utils/debt_payment_link_state.dart';
import 'package:biztrack_gh/features/debts/presentation/utils/debt_payment_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebtPaymentLinkState', () {
    test('hasLink is false for null or blank link', () {
      expect(const DebtPaymentLinkState().hasLink, isFalse);
      expect(const DebtPaymentLinkState(paymentLink: '  ').hasLink, isFalse);
    });

    test('shouldWatchPassiveStatus requires open or partially_paid', () {
      expect(
        DebtPaymentLinkState.shouldWatchPassiveStatus(
          hasLink: true,
          receivableStatus: 'open',
        ),
        isTrue,
      );
      expect(
        DebtPaymentLinkState.shouldWatchPassiveStatus(
          hasLink: true,
          receivableStatus: 'settled',
        ),
        isFalse,
      );
    });

    test('expiryCountdownLabel formats remaining time', () {
      final now = DateTime(2026, 5, 29, 12, 0);
      final state = DebtPaymentLinkState(
        paymentLink: 'https://checkout.paystack.com/x',
        paymentLinkExpiresAtIso: now.add(const Duration(hours: 2, minutes: 5)).toUtc().toIso8601String(),
        now: now,
      );
      expect(state.isExpired, isFalse);
      expect(state.expiryCountdownLabel, 'Expires in 2h 5m');
    });

    test('isExpired when clock is past expiry', () {
      final expires = DateTime(2026, 5, 29, 13, 0);
      final state = DebtPaymentLinkState(
        paymentLink: 'https://checkout.paystack.com/x',
        paymentLinkExpiresAtIso: expires.toUtc().toIso8601String(),
        now: expires.add(const Duration(minutes: 1)),
      );
      expect(state.isExpired, isTrue);
      expect(state.expiryCountdownLabel, isNull);
    });
  });

  group('DebtPaymentAmountValidation', () {
    test('accepts charge within outstanding', () {
      final result = DebtPaymentAmountValidation.validate(
        amountRaw: '50.00',
        outstandingAmount: '120.00',
      );
      expect(result.isValid, isTrue);
      expect(result.amountMinor, 5000);
    });

    test('rejects malformed, zero, and over-limit amounts', () {
      expect(
        DebtPaymentAmountValidation.validate(
          amountRaw: 'abc',
          outstandingAmount: '120.00',
        ).isValid,
        isFalse,
      );
      expect(
        DebtPaymentAmountValidation.validate(
          amountRaw: '0',
          outstandingAmount: '120.00',
        ).isValid,
        isFalse,
      );
      expect(
        DebtPaymentAmountValidation.validate(
          amountRaw: '150.00',
          outstandingAmount: '120.00',
        ).isValid,
        isFalse,
      );
    });
  });

  group('DebtPaymentProgress', () {
    const openReceivable = ReceivableDto(
      receivableId: 'r1',
      customerId: 'c1',
      customerName: 'Ama',
      originalAmount: '120.00',
      outstandingAmount: '120.00',
      status: 'open',
      createdAtIso: '2026-01-01T00:00:00Z',
    );

    const partialReceivable = ReceivableDto(
      receivableId: 'r1',
      customerId: 'c1',
      customerName: 'Ama',
      originalAmount: '120.00',
      outstandingAmount: '70.00',
      status: 'partially_paid',
      createdAtIso: '2026-01-01T00:00:00Z',
    );

    test('hasReceivableProgressed detects settlement and partial pay', () {
      expect(
        DebtPaymentProgress.hasReceivableProgressed(
          server: partialReceivable,
          localOutstandingAmount: '120.00',
          localStatus: 'open',
        ),
        isTrue,
      );
      expect(
        DebtPaymentProgress.hasReceivableProgressed(
          server: openReceivable,
          localOutstandingAmount: '120.00',
          localStatus: 'open',
        ),
        isFalse,
      );
    });

    test('verifyIndicatesSuccess trusts settled webhook state', () {
      const verify = ReceivablePaymentVerifyOutDto(
        paymentId: 'p1',
        receivableId: 'r1',
        providerPaymentStatus: 'pending',
        receivableStatus: 'settled',
        outstandingAmount: '0.00',
        paystackTransactionStatus: 'pending',
      );
      expect(DebtPaymentProgress.verifyIndicatesSuccess(verify), isTrue);
    });

    test('paymentConfirmedMessage distinguishes partial vs settled', () {
      expect(
        DebtPaymentProgress.paymentConfirmedMessage(
          serverRow: partialReceivable,
        ),
        contains('Partial payment received'),
      );
      expect(
        DebtPaymentProgress.paymentConfirmedMessage(
          serverRow: const ReceivableDto(
            receivableId: 'r1',
            customerId: 'c1',
            customerName: 'Ama',
            originalAmount: '120.00',
            outstandingAmount: '0.00',
            status: 'settled',
            createdAtIso: '2026-01-01T00:00:00Z',
          ),
        ),
        'Payment received. Debt settled.',
      );
    });
  });
}
