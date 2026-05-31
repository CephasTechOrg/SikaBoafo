import '../../data/debts_api.dart';
import '../../data/debts_payments_api.dart';
import 'debts_ui_utils.dart';

/// Shared Paystack payment progress rules for sheets and the link panel (MOB-02).
abstract final class DebtPaymentProgress {
  static bool isReceivableFullySettled(ReceivableDto dto) {
    final outstandingMinor = DebtsUiUtils.amountToMinor(dto.outstandingAmount);
    return dto.status == 'settled' || outstandingMinor == 0;
  }

  static bool verifyIndicatesSuccess(ReceivablePaymentVerifyOutDto verify) {
    if (verify.isPaymentSuccessful) return true;
    if (verify.isSettled) return true;
    return DebtsUiUtils.amountToMinor(verify.outstandingAmount) == 0;
  }

  static bool hasReceivableProgressed({
    required ReceivableDto server,
    required String localOutstandingAmount,
    required String localStatus,
  }) {
    final localMinor = DebtsUiUtils.amountToMinor(localOutstandingAmount);
    final serverMinor = DebtsUiUtils.amountToMinor(server.outstandingAmount);
    final settled = isReceivableFullySettled(server);
    return settled ||
        serverMinor < localMinor ||
        server.status != localStatus;
  }

  static String paymentConfirmedMessage({
    ReceivableDto? serverRow,
    String? fallbackStatus,
    String? fallbackOutstanding,
  }) {
    final status = serverRow?.status ?? fallbackStatus;
    final outstandingAmount =
        serverRow?.outstandingAmount ?? fallbackOutstanding;
    final outstandingMinor = outstandingAmount == null
        ? 0
        : DebtsUiUtils.amountToMinor(outstandingAmount);
    final settled = status == 'settled' || outstandingMinor == 0;
    if (settled) return 'Payment received. Debt settled.';
    if (outstandingAmount != null) {
      return 'Partial payment received. Remaining: '
          '${DebtsUiUtils.formatAmount(outstandingAmount)}.';
    }
    return 'Payment received.';
  }

  static String watcherProgressMessage({
    required ReceivableDto server,
    required bool settled,
  }) {
    if (settled) return 'Payment received. Debt settled.';
    return 'Payment received. Remaining balance: '
        '${DebtsUiUtils.formatAmount(server.outstandingAmount)}.';
  }
}
