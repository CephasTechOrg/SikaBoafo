import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _phoneFocusNode = FocusNode();
  final GlobalKey _phoneFieldKey = GlobalKey();
  String _provider = 'mtn';
  Timer? _timer;
  bool _sending = false;
  bool _checking = false;
  bool _promptSent = false;
  String? _paymentId;
  String? _paystackDisplayText;
  int _pollCount = 0;
  static const _maxPolls = 40;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
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
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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
      });
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
                  _promptSent ? 'Waiting for customer approval' : 'Pay with MoMo number',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _promptSent
                      ? 'Ask the customer to check their phone and approve the MoMo prompt.'
                      : 'For customers without a smartphone. Enter their MoMo number and network.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text('Amount ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                      Text(
                        '₵${widget.amountDisplay}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.paystackTestMode && !_promptSent) ...[
                  const SizedBox(height: 12),
                  Container(
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
                          'Paystack will not send a real network prompt to customer phones while you use test (sk_test_) keys. '
                          'For Ghana MTN tests, use number 0551234987 and network MTN (Paystack test docs). '
                          'Telecel and other real numbers need live keys in Settings → Paystack.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_promptSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: _phoneFieldKey,
                    controller: _phoneCtrl,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]'))],
                    scrollPadding: EdgeInsets.only(
                      bottom: keyboardInset + 120,
                      left: 16,
                      right: 16,
                      top: 24,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Customer MoMo number',
                      hintText: widget.paystackTestMode
                          ? 'Test MTN: 0551234987'
                          : 'e.g. 055 123 4567',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Network',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _provider,
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
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _sending ? null : _sendPrompt,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_sending ? 'Sending…' : 'Send MoMo prompt'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.phone_android_rounded,
                              size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        _checking ? 'Checking…' : 'Waiting for payment',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _timer?.cancel();
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
