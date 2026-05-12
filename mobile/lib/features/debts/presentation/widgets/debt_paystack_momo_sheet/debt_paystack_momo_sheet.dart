import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../shared/providers/sync_providers.dart';
import '../../../data/debts_payments_api.dart';
import '../../../providers/debt_detail_provider.dart';
import '../../../providers/debts_providers.dart';
import '../../utils/debts_ui_utils.dart';
import 'debt_momo_otp_field.dart';
import 'debt_momo_phone_field.dart';
import 'debt_momo_provider_selector.dart';

/// Paystack direct MoMo push for a receivable. Mirror of
/// `paystack_momo_sheet.dart` from the sales feature.
///
/// **Verification:** Same intent as sales Paystack flows and [DebtPaystackQrSheet]
/// — poll [DebtsPaymentsApi.verifyPayment] until the server marks the payment
/// successful (webhook-backed), then refresh receivable detail + list.
///
/// Flow:
///   1. Merchant enters the customer's MoMo number + network.
///   2. Backend pushes a charge to the customer's handset.
///   3. If Paystack returns `send_otp`, merchant collects the 6-digit code
///      from the customer and submits it.
///   4. Sheet polls `/payments/receivables/{id}/verify` every 3s until the
///      receivable is settled.
class DebtPaystackMomoSheet extends ConsumerStatefulWidget {
  const DebtPaystackMomoSheet({
    super.key,
    required this.receivableId,
    required this.amountDisplay,
    required this.chargeAmount,
    required this.customerName,
    required this.onPaymentConfirmed,
    this.paystackTestMode = false,
  });

  final String receivableId;
  final String amountDisplay;
  final String chargeAmount;
  final String customerName;
  final VoidCallback onPaymentConfirmed;
  final bool paystackTestMode;

  @override
  ConsumerState<DebtPaystackMomoSheet> createState() =>
      _DebtPaystackMomoSheetState();
}

class _DebtPaystackMomoSheetState extends ConsumerState<DebtPaystackMomoSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  final GlobalKey _phoneFieldKey = GlobalKey();
  String _provider = 'mtn';

  Timer? _timer;
  Timer? _otpCooldownTimer;
  bool _sending = false;
  bool _checking = false;
  bool _submittingOtp = false;
  bool _otpCooldownActive = false;
  bool _promptSent = false;
  bool _needsOtp = false;
  String? _paymentId;
  String? _paystackDisplayText;
  int _pollCount = 0;
  int _autoCheckFailures = 0;
  String? _statusError;

  static const _maxPolls = 40;
  static const _otpLength = 6;
  static const _otpResubmitCooldown = Duration(seconds: 28);

  @override
  void initState() {
    super.initState();
    _otpFocusNode.addListener(_onOtpFocusChange);
  }

  void _onOtpFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCooldownTimer?.cancel();
    _otpFocusNode.removeListener(_onOtpFocusChange);
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _check(auto: true),
    );
  }

  void _startOtpCooldown() {
    _otpCooldownTimer?.cancel();
    setState(() => _otpCooldownActive = true);
    _otpCooldownTimer = Timer(_otpResubmitCooldown, () {
      if (!mounted) return;
      setState(() => _otpCooldownActive = false);
    });
  }

  bool get _canSubmitOtp =>
      !_submittingOtp &&
      !_otpCooldownActive &&
      _otpCtrl.text.length == _otpLength;

  Future<void> _sendPrompt() async {
    final raw = _phoneCtrl.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid MoMo number.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final out = await ref.read(debtsPaymentsApiProvider).initiateMomoCharge(
            receivableId: widget.receivableId,
            phone: raw,
            provider: _provider,
            amount: widget.chargeAmount,
          );
      if (!mounted) return;
      setState(() {
        _promptSent = true;
        _paymentId = out.paymentId;
        _paystackDisplayText = out.displayText;
        _needsOtp = out.needsOtp;
      });
      if (out.needsOtp) {
        _otpCtrl.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
      _startPolling();
      await _check(auto: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeDebtsPaymentsError(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check({bool auto = false}) async {
    final paymentId = _paymentId;
    if (paymentId == null || paymentId.isEmpty) return;
    if (_checking) return;
    if (auto && _pollCount >= _maxPolls) {
      _timer?.cancel();
      return;
    }
    if (auto) _pollCount++;
    setState(() => _checking = true);
    try {
      final verify =
          await ref.read(debtsPaymentsApiProvider).verifyPayment(paymentId);
      if (!mounted) return;
      setState(() {
        _needsOtp = verify.needsOtp;
        final t = verify.displayText;
        if (t != null && t.trim().isNotEmpty) {
          _paystackDisplayText = t.trim();
        }
      });
      if (verify.isPaymentSuccessful) {
        _timer?.cancel();
        ref.invalidate(receivableDetailProvider(widget.receivableId));
        await ref.read(debtsControllerProvider.notifier).refresh();
        if (!mounted) return;
        widget.onPaymentConfirmed();
        return;
      }
      _autoCheckFailures = 0;
      _statusError = null;
      if (verify.isFailed && !auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed. You can retry or cancel.'),
          ),
        );
      }
    } catch (error) {
      if (auto) {
        _autoCheckFailures++;
        if (_autoCheckFailures >= 2) {
          _statusError = 'Could not reach backend to verify payment status.';
        }
      }
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeDebtsPaymentsError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submitOtp() async {
    final paymentId = _paymentId;
    if (paymentId == null || paymentId.isEmpty) return;
    final code = _otpCtrl.text.trim();
    if (code.length != _otpLength) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter all 6 digits from the customer.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    var completed = false;
    var cooldownAfter = false;
    setState(() => _submittingOtp = true);
    try {
      final out = await ref.read(debtsPaymentsApiProvider).submitMomoOtp(
            paymentId: paymentId,
            otp: code,
          );
      if (!mounted) return;
      if (out.isPaymentSuccessful) {
        completed = true;
        _otpCooldownTimer?.cancel();
        _timer?.cancel();
        ref.invalidate(receivableDetailProvider(widget.receivableId));
        await ref.read(debtsControllerProvider.notifier).refresh();
        if (!mounted) return;
        widget.onPaymentConfirmed();
        return;
      }
      cooldownAfter = out.needsOtp;
      setState(() {
        _needsOtp = out.needsOtp;
        final t = out.displayText;
        if (t != null && t.trim().isNotEmpty) {
          _paystackDisplayText = t.trim();
        }
      });
      if (out.needsOtp) {
        _otpCtrl.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      } else {
        await _check(auto: true);
      }
    } catch (error) {
      if (!mounted) return;
      cooldownAfter = _needsOtp;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeDebtsPaymentsError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingOtp = false);
        if (!completed && cooldownAfter) {
          _startOtpCooldown();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.elevated,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.borderStrong,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    !_promptSent
                        ? 'Push MoMo prompt'
                        : _needsOtp
                            ? 'Enter customer verification code'
                            : 'Waiting for customer approval',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !_promptSent
                        ? 'Push a payment prompt to ${widget.customerName}\'s '
                            'handset. No smartphone needed.'
                        : _needsOtp
                            ? 'Some networks send a 6-digit OTP or USSD '
                                'voucher. Get it from the customer, then enter '
                                'it below.'
                            : 'Ask ${widget.customerName} to check their '
                                'phone and approve the MoMo prompt.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Outstanding ',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          DebtsUiUtils.formatAmount(widget.amountDisplay),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.ink,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.paystackTestMode && !_promptSent) ...[
                    const SizedBox(height: 12),
                    _TestModeBanner(),
                  ],
                  if (!_promptSent) ...[
                    const SizedBox(height: 16),
                    DebtMomoPhoneField(
                      controller: _phoneCtrl,
                      focusNode: _phoneFocusNode,
                      fieldKey: _phoneFieldKey,
                      keyboardInset: keyboardInset,
                      testMode: widget.paystackTestMode,
                    ),
                    const SizedBox(height: 12),
                    DebtMomoProviderSelector(
                      value: _provider,
                      onChanged: (v) => setState(() => _provider = v),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendPrompt,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sending ? 'Sending…' : 'Send MoMo prompt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    if (_paystackDisplayText != null &&
                        _paystackDisplayText!.trim().isNotEmpty) ...[
                      Text(
                        _paystackDisplayText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_needsOtp) ...[
                      DebtMomoOtpField(
                        controller: _otpCtrl,
                        focusNode: _otpFocusNode,
                        length: _otpLength,
                        onChanged: () => setState(() {}),
                        onSubmitted: () {
                          if (_canSubmitOtp) _submitOtp();
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _otpCooldownActive
                            ? 'Wait a moment before submitting again so the '
                                'customer can receive the prompt.'
                            : 'Tap the boxes to type. One digit per box.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _otpCooldownActive
                              ? AppColors.inkSoft
                              : AppColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _canSubmitOtp ? _submitOtp : null,
                        icon: _submittingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: _canSubmitOtp
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                        label: Text(
                          _submittingOtp
                              ? 'Submitting…'
                              : _otpCooldownActive
                                  ? 'Wait…'
                                  : 'Submit code',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          disabledBackgroundColor:
                              AppColors.forest.withValues(alpha: 0.45),
                          disabledForegroundColor:
                              Colors.white.withValues(alpha: 0.85),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _checking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.phone_android_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          _checking ? 'Checking…' : 'Waiting for payment',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    if (_statusError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _statusError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _checking ? null : () => _check(auto: false),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Check status'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _timer?.cancel();
                      _otpCooldownTimer?.cancel();
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(_promptSent ? 'Close' : 'Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TestModeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test keys — sandbox MoMo only',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Paystack will not push a real prompt while you use test '
            '(sk_test_) keys. For Ghana MTN tests, use number 0551234987 '
            'and network MTN. Other networks need live keys in '
            'Settings → Paystack.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDebtPaystackMomoSheet(
  BuildContext context, {
  required String receivableId,
  required String amountDisplay,
  required String chargeAmount,
  required String customerName,
  required VoidCallback onPaymentConfirmed,
  bool paystackTestMode = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DebtPaystackMomoSheet(
      receivableId: receivableId,
      amountDisplay: amountDisplay,
      chargeAmount: chargeAmount,
      customerName: customerName,
      onPaymentConfirmed: onPaymentConfirmed,
      paystackTestMode: paystackTestMode,
    ),
  );
}
