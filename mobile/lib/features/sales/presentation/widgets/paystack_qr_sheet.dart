import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/sales_providers.dart';

class PaystackQrSheet extends ConsumerStatefulWidget {
  const PaystackQrSheet({
    super.key,
    required this.checkoutUrl,
    required this.saleId,
    required this.onPaymentConfirmed,
    this.merchantName,
    this.amountDisplay,
    this.saleRef,
  });

  final String checkoutUrl;
  final String saleId;
  final VoidCallback onPaymentConfirmed;
  final String? merchantName;
  final String? amountDisplay;
  final String? saleRef;

  @override
  ConsumerState<PaystackQrSheet> createState() => PaystackQrSheetState();
}

class PaystackQrSheetState extends ConsumerState<PaystackQrSheet> {
  Timer? _timer;
  int    _pollCount = 0;
  _QrState _state  = _QrState.waiting;

  static const _maxPolls = 20;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll({bool manual = false}) async {
    if (_state == _QrState.verifying) return;
    if (!manual && _pollCount >= _maxPolls) {
      _timer?.cancel();
      if (mounted) setState(() => _state = _QrState.failed);
      return;
    }
    if (!manual) _pollCount++;
    setState(() => _state = _QrState.verifying);
    try {
      final status = await ref
          .read(salesPaymentsApiProvider)
          .fetchSalePaymentStatus(widget.saleId);
      if (!mounted) return;
      if (status.paymentStatus == 'succeeded') {
        _timer?.cancel();
        setState(() => _state = _QrState.success);
        widget.onPaymentConfirmed();
      } else {
        setState(() => _state = _QrState.waiting);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _QrState.waiting);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.checkoutUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment link copied.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareLink() async {
    final box    = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      widget.checkoutUrl,
      subject: 'Payment link',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final merchantName  = widget.merchantName ?? 'My Shop';
    final amountDisplay = widget.amountDisplay;
    final saleRef       = widget.saleRef ?? widget.saleId.substring(0, 8).toUpperCase();
    final isBusy        = _state == _QrState.verifying;
    final hasFailed     = _state == _QrState.failed;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // ── Grip ─────────────────────────────────────────────────────
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

              // ── Merchant badge pill ───────────────────────────────────────
              Container(
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
                        Icons.storefront_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      merchantName,
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
              const SizedBox(height: 14),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'Scan to Pay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Show this QR to your customer. Payment confirms automatically.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),

              // ── Amount block ──────────────────────────────────────────────
              if (amountDisplay != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFBFDFC), Color(0xFFF3F8F5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(18),
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
                              amountDisplay,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                                letterSpacing: -0.5,
                                height: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF6EF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Sale Payment',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F7A4A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.sell_outlined,
                                size: 13,
                                color: Color(0xFF9AA3AF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                saleRef,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9AA3AF),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // ── QR code container ─────────────────────────────────────────
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12101828),
                      blurRadius: 22,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: widget.checkoutUrl,
                      version: QrVersions.auto,
                      size: 200,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F7A4A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF073B2A),
                      ),
                    ),
                    // ₵ logo badge in center
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x291C2920),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF073B2A),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '₵',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // State overlay (verifying / failed)
                    if (_state != _QrState.waiting)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            color: hasFailed
                                ? const Color(0xDBF8F2F2)
                                : const Color(0xDBFFFFFF),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_state == _QrState.verifying) ...[
                                  const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Color(0xFF0F7A4A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Verifying…',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F7A4A),
                                    ),
                                  ),
                                ] else if (_state == _QrState.success) ...[
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF168A55),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Paid',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F7A4A),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFD23B3B)
                                          .withValues(alpha: 0.12),
                                    ),
                                    child: const Icon(
                                      Icons.timer_off_rounded,
                                      size: 30,
                                      color: Color(0xFFD23B3B),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Expired',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD23B3B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Payment link row ──────────────────────────────────────────
              const SizedBox(height: 16),
              Text(
                'PAYMENT LINK',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                  color: const Color(0xFF9AA3AF),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F7),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 16,
                      color: Color(0xFF0F7A4A),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.checkoutUrl,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF6B7280),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy link'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _shareLink,
                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Status band ───────────────────────────────────────────────
              const SizedBox(height: 16),
              _StatusBand(state: _state),

              // ── Primary CTA ───────────────────────────────────────────────
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: hasFailed
                    ? FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Generate new QR'),
                        style: _primaryBtnStyle,
                      )
                    : FilledButton.icon(
                        onPressed: isBusy ? null : () => _poll(manual: true),
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded,
                                size: 18),
                        label: Text(
                          isBusy ? 'Verifying payment…' : 'I\'ve received payment',
                        ),
                        style: _primaryBtnStyle,
                      ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
              ),     // Column
            ),       // SingleChildScrollView
          ),         // ConstrainedBox
        ),           // Container
      ),             // Padding
    );               // SafeArea
  }
}

// ── Status band ───────────────────────────────────────────────────────────────

class _StatusBand extends StatelessWidget {
  const _StatusBand({required this.state});
  final _QrState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _QrState.verifying:
        return const _Band(
          bg: Color(0xFFEAF1FB),
          border: Color(0xFFDCE7F6),
          leading: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF2563A8),
            ),
          ),
          title: 'Verifying payment…',
          titleColor: Color(0xFF1E4E86),
          sub: 'Confirming with Paystack, please wait',
          subColor: Color(0xFF4B72A8),
        );
      case _QrState.success:
        return _Band(
          bg: const Color(0xFFEAF6EF),
          border: const Color(0xFFCDEAD9),
          leading: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF168A55),
            ),
            child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
          ),
          title: 'Payment received',
          titleColor: const Color(0xFF0F7A4A),
          sub: 'Confirmed — payment was successful',
          subColor: const Color(0xFF6B7280),
        );
      case _QrState.failed:
        return _Band(
          bg: const Color(0xFFFBECEC),
          border: const Color(0xFFF6D9D9),
          leading: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD23B3B),
            ),
            child: const Icon(Icons.timer_off_rounded, size: 16, color: Colors.white),
          ),
          title: 'QR expired',
          titleColor: const Color(0xFFD23B3B),
          sub: 'This code timed out. Generate a new one to retry.',
          subColor: const Color(0xFF6B7280),
        );
      case _QrState.waiting:
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F7),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Pulsing dot
              SizedBox(
                width: 14,
                height: 14,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _PulseDot(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF168A55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waiting for payment',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'We\'ll confirm automatically once it\'s paid',
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
        );
    }
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.bg,
    required this.border,
    required this.leading,
    required this.title,
    required this.titleColor,
    required this.sub,
    required this.subColor,
  });

  final Color bg;
  final Color border;
  final Widget leading;
  final String title;
  final Color titleColor;
  final String sub;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: subColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scale   = Tween<double>(begin: 0.5, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF168A55),
            ),
          ),
        ),
      ),
    );
  }
}

enum _QrState { waiting, verifying, success, failed }

ButtonStyle get _primaryBtnStyle => FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0F7A4A),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    );
