import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/sales_payments_api.dart';
import '../../providers/sales_providers.dart';

/// Paystack Ghana **MoMo push**: cashier enters customer number + network;
/// customer approves the prompt on their own phone (no smartphone / QR needed).
class PaystackMomoSheet extends ConsumerStatefulWidget {
  const PaystackMomoSheet({
    super.key,
    required this.saleId,
    required this.amountDisplay,
    required this.onPaymentConfirmed,
    this.paystackTestMode = false,
  });

  final String saleId;
  final String amountDisplay;
  final VoidCallback onPaymentConfirmed;

  /// When the merchant's Paystack connection uses **test** keys, only Paystack's
  /// sandbox MoMo numbers work (see Paystack test payments docs). Real phones
  /// need **live** keys.
  final bool paystackTestMode;

  @override
  ConsumerState<PaystackMomoSheet> createState() => _PaystackMomoSheetState();
}

class _PaystackMomoSheetState extends ConsumerState<PaystackMomoSheet> {
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
  static const _maxPolls = 40;
  static const _otpLength = 6;
  /// After submitting an OTP, lock resubmit briefly so merchants don't spam Paystack
  /// while the customer's network is still delivering the prompt.
  static const _otpResubmitCooldown = Duration(seconds: 28);

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
    _otpFocusNode.addListener(_onOtpFocusChange);
  }

  void _onOtpFocusChange() {
    if (mounted) setState(() {});
  }

  void _onPhoneFocusChange() {
    if (!_phoneFocusNode.hasFocus) return;
    void scrollIntoView() {
      if (!mounted || !_phoneFocusNode.hasFocus) return;
      final ctx = _phoneFieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.12,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => scrollIntoView());
    Future<void>.delayed(const Duration(milliseconds: 280), scrollIntoView);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCooldownTimer?.cancel();
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _otpFocusNode.removeListener(_onOtpFocusChange);
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _clearOtpFields() {
    _otpCtrl.clear();
  }

  void _startOtpSubmitCooldown() {
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

  Widget _buildOtpOvalSlots() {
    final text = _otpCtrl.text;
    final focused = _otpFocusNode.hasFocus;
    final activeIndex = focused
        ? (text.length >= _otpLength
            ? -1
            : text.length.clamp(0, _otpLength - 1))
        : -1;

    return AutofillGroup(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (i) {
              final ch = i < text.length ? text[i] : '';
              final isActive = activeIndex >= 0 && i == activeIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5, right: i == _otpLength - 1 ? 0 : 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        width: isActive ? 1.5 : 1,
                        color: isActive ? AppColors.forest : AppColors.border,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.forest.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      ch,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Invisible field: one char per keypress, paste, autofill — avoids six separate fields.
          Positioned.fill(
            child: TextField(
              controller: _otpCtrl,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _otpLength,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.transparent, height: 0.01, fontSize: 1),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) {
                if (mounted) setState(() {});
              },
              onSubmitted: (_) {
                if (_canSubmitOtp) _submitOtp();
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check(auto: true));
  }

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
      final out = await ref.read(salesPaymentsApiProvider).initiateSaleMomoCharge(
            saleId: widget.saleId,
            phone: raw,
            provider: _provider,
          );
      if (!mounted) return;
      setState(() {
        _promptSent = true;
        _paymentId = out.paymentId;
        _paystackDisplayText = out.displayText;
        _needsOtp = out.needsOtp;
      });
      if (out.needsOtp) {
        _clearOtpFields();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      }
      _startPolling();
      await _check(auto: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeSalesPaymentsError(e))),
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
      final verify = await ref.read(salesPaymentsApiProvider).verifySalePayment(paymentId);
      if (!mounted) return;
      setState(() {
        _needsOtp = verify.needsOtp;
        final t = verify.displayText;
        if (t != null && t.trim().isNotEmpty) {
          _paystackDisplayText = t.trim();
        }
      });
      if (verify.salePaymentStatus == 'succeeded') {
        _timer?.cancel();
        widget.onPaymentConfirmed();
        return;
      }
      if (verify.salePaymentStatus == 'failed' && !auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment not completed. You can retry or cancel.')),
        );
      }
    } catch (_) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check status. Try again.')),
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
        const SnackBar(
          content: Text('Enter all 6 digits from the customer.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    var saleCompleted = false;
    var cooldownAfterSubmit = false;
    setState(() => _submittingOtp = true);
    try {
      final out = await ref.read(salesPaymentsApiProvider).submitSaleMomoOtp(
            paymentId: paymentId,
            otp: code,
          );
      if (!mounted) return;
      if (out.salePaymentStatus == 'succeeded') {
        saleCompleted = true;
        _otpCooldownTimer?.cancel();
        _timer?.cancel();
        widget.onPaymentConfirmed();
        return;
      }
      cooldownAfterSubmit = out.needsOtp;
      setState(() {
        _needsOtp = out.needsOtp;
        final t = out.displayText;
        if (t != null && t.trim().isNotEmpty) {
          _paystackDisplayText = t.trim();
        }
      });
      if (out.needsOtp) {
        _clearOtpFields();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocusNode.requestFocus();
        });
      } else {
        await _check(auto: true);
      }
    } catch (e) {
      if (!mounted) return;
      cooldownAfterSubmit = _needsOtp;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeSalesPaymentsError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingOtp = false);
        if (!saleCompleted && cooldownAfterSubmit) {
          _startOtpSubmitCooldown();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final title = !_promptSent
        ? 'Pay with MoMo'
        : _needsOtp
            ? 'Enter verification code'
            : 'Waiting for approval';

    final subtitle = !_promptSent
        ? 'For customers without a smartphone. Enter their MoMo number and network below.'
        : _needsOtp
            ? 'Some networks send a 6-digit OTP or USSD voucher. Enter the code the customer receives.'
            : 'Ask the customer to check their phone and approve the MoMo prompt.';

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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F101828),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Grip ───────────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Merchant badge pill ─────────────────────────────────────
                  Center(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F7),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF073B2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.phone_android_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MoMo Push Payment',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF168A55),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Title + subtitle ────────────────────────────────────────
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Amount block ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBFDFC), Color(0xFFF3F8F5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AMOUNT DUE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                  color: const Color(0xFF9AA3AF),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₵${widget.amountDisplay}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                  letterSpacing: -0.4,
                                  height: 1,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6EF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'MoMo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F7A4A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Test mode warning ───────────────────────────────────────
                  if (widget.paystackTestMode && !_promptSent) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF3E1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8D49A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test keys — sandbox MoMo only',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Use MTN test number 0551234987. Real customer phones need live keys in Settings → Paystack.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.4,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Phone entry form ────────────────────────────────────────
                  if (!_promptSent) ...[
                    const SizedBox(height: 16),
                    _MomoField(
                      label: 'Customer MoMo number',
                      hint: widget.paystackTestMode ? 'Test MTN: 0551234987' : 'e.g. 055 123 4567',
                      controller: _phoneCtrl,
                      focusNode: _phoneFocusNode,
                      fieldKey: _phoneFieldKey,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]'))],
                      scrollPadding: EdgeInsets.only(
                        bottom: keyboardInset + 120,
                        left: 16, right: 16, top: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Network selector
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F7),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cell_tower_rounded, size: 18, color: Color(0xFF9AA3AF)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _provider,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'mtn', child: Text('MTN')),
                                  DropdownMenuItem(value: 'atl', child: Text('AirtelTigo')),
                                  DropdownMenuItem(value: 'vod', child: Text('Telecel')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _provider = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _sending ? null : _sendPrompt,
                      icon: _sending
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sending ? 'Sending…' : 'Send MoMo prompt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7A4A),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  // ── Post-prompt states ──────────────────────────────────────
                  ] else ...[
                    const SizedBox(height: 16),
                    // Paystack status message
                    if (_paystackDisplayText != null &&
                        _paystackDisplayText!.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8F7),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _paystackDisplayText!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // OTP input
                    if (_needsOtp) ...[
                      _buildOtpOvalSlots(),
                      const SizedBox(height: 8),
                      Text(
                        _otpCooldownActive
                            ? 'Wait a moment before submitting again.'
                            : 'Tap the boxes to type. One digit per box.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: _otpCooldownActive
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF9AA3AF),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _canSubmitOtp ? _submitOtp : null,
                        icon: _submittingOtp
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: _canSubmitOtp
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                        label: Text(
                          _submittingOtp ? 'Submitting…'
                              : _otpCooldownActive ? 'Wait…'
                              : 'Submit code',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7A4A),
                          disabledBackgroundColor: const Color(0xFF0F7A4A).withValues(alpha: 0.45),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Status band
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F7),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_checking)
                            const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFF0F7A4A),
                              ),
                            )
                          else
                            const Icon(Icons.phone_android_rounded,
                                size: 18, color: Color(0xFF168A55)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _checking ? 'Checking payment…' : 'Waiting for customer',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  _checking
                                      ? 'Confirming with Paystack, please wait'
                                      : 'We\'ll confirm once the customer approves',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    color: const Color(0xFF6B7280),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _checking ? null : () => _check(auto: false),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('I\'ve received payment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F7A4A),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  // ── Cancel / close ──────────────────────────────────────────
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: () {
                        _timer?.cancel();
                        _otpCooldownTimer?.cancel();
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5, fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(_promptSent ? 'Close' : 'Cancel'),
                    ),
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

// ── Reusable styled text field ────────────────────────────────────────────────

class _MomoField extends StatelessWidget {
  const _MomoField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    this.keyboardType,
    this.inputFormatters,
    this.scrollPadding,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey fieldKey;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsets? scrollPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 7),
        Container(
          key: fieldKey,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F7),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.phone_iphone_rounded,
                    size: 18, color: Color(0xFF9AA3AF)),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  scrollPadding: scrollPadding ?? EdgeInsets.zero,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF9AA3AF),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(right: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
