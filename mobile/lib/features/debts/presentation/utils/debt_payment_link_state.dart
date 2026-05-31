/// Active Paystack link expiry and passive-watch eligibility (MOB-02).
class DebtPaymentLinkState {
  const DebtPaymentLinkState({
    this.paymentLink,
    this.paymentLinkExpiresAtIso,
    this.now,
  });

  final String? paymentLink;
  final String? paymentLinkExpiresAtIso;

  /// Injectable clock for unit tests.
  final DateTime? now;

  DateTime get _clock => now ?? DateTime.now();

  bool get hasLink {
    final link = paymentLink;
    return link != null && link.trim().isNotEmpty;
  }

  /// Passive background poll runs only while a link exists and the debt can
  /// still accept payment.
  static bool shouldWatchPassiveStatus({
    required bool hasLink,
    required String receivableStatus,
  }) {
    return hasLink &&
        (receivableStatus == 'open' || receivableStatus == 'partially_paid');
  }

  DateTime? get expiresAt {
    final iso = paymentLinkExpiresAtIso;
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  bool get isExpired {
    final at = expiresAt;
    if (at == null) return false;
    return !_clock.isBefore(at);
  }

  /// Compact "Expires in 23h 12m" copy, or `null` when unknown / past expiry.
  String? get expiryCountdownLabel {
    final at = expiresAt;
    if (at == null) return null;
    final remaining = at.difference(_clock);
    if (!remaining.isNegative && remaining.inSeconds <= 60) {
      return 'Expires in <1m';
    }
    if (remaining.isNegative) return null;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours <= 0) return 'Expires in ${minutes}m';
    return 'Expires in ${hours}h ${minutes}m';
  }
}
