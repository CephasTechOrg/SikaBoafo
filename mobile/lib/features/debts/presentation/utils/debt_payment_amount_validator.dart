import 'debts_ui_utils.dart';

/// Charge-amount parsing and bounds checks for online Paystack collection.
abstract final class DebtPaymentAmountValidator {
  static final RegExp _pattern = RegExp(r'^\d+(\.\d{1,2})?$');

  /// Returns minor units for a valid decimal string, or `null` when malformed.
  static int? tryParseChargeMinor(String raw) {
    final value = raw.trim();
    if (!_pattern.hasMatch(value)) return null;
    return DebtsUiUtils.amountToMinor(value);
  }
}

class DebtPaymentAmountValidation {
  const DebtPaymentAmountValidation._({
    required this.isValid,
    this.amountMinor,
    this.outstandingMinor,
  });

  final bool isValid;
  final int? amountMinor;
  final int? outstandingMinor;

  factory DebtPaymentAmountValidation.validate({
    required String amountRaw,
    required String outstandingAmount,
  }) {
    final amountMinor =
        DebtPaymentAmountValidator.tryParseChargeMinor(amountRaw);
    final outstandingMinor = DebtsUiUtils.amountToMinor(outstandingAmount);
    final isValid = amountMinor != null &&
        amountMinor > 0 &&
        outstandingMinor > 0 &&
        amountMinor <= outstandingMinor;
    return DebtPaymentAmountValidation._(
      isValid: isValid,
      amountMinor: amountMinor,
      outstandingMinor: outstandingMinor,
    );
  }

  String validationSnackMessage(String formattedOutstanding) {
    return 'Enter an amount between GHS 0.01 and $formattedOutstanding.';
  }
}
