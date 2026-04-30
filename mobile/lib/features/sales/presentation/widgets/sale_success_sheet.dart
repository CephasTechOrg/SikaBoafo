import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import 'dart:math' show sqrt;
import 'package:flutter/services.dart';


class SaleSuccessSheet extends StatefulWidget {
  const SaleSuccessSheet({super.key, required this.amount, required this.method});

  /// Decimal string e.g. "120.00"
  final String amount;

  /// 'cash' | 'mobile_money'
  final String method;

  @override
  State<SaleSuccessSheet> createState() => SaleSuccessSheetState();
}
class SaleSuccessSheetState extends State<SaleSuccessSheet>
    with TickerProviderStateMixin {
  late final AnimationController _circleCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _circleAnim;
  late final Animation<double> _checkAnim;
  late final Animation<double> _contentAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _circleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _circleAnim =
        CurvedAnimation(parent: _circleCtrl, curve: Curves.elasticOut);
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);
    _contentAnim =
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut);

    HapticFeedback.heavyImpact();
    _circleCtrl.forward().then((_) {
      _checkCtrl.forward().then((_) {
        HapticFeedback.mediumImpact();
        _contentCtrl.forward();
        _pulseCtrl.repeat();
      });
    });
  }

  @override
  void dispose() {
    _circleCtrl.dispose();
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCash = widget.method == 'cash';
    final accent = isCash ? AppColors.success : AppColors.gold;
    final title = isCash ? 'Sale Recorded!' : 'Payment Confirmed!';
    final subtitle = isCash ? 'Cash · Paid in full' : 'Mobile Money · Paystack';
    final subtitleIcon =
        isCash ? Icons.payments_rounded : Icons.phone_android_rounded;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated circle + pulse ring
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding pulse ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: (1.0 - _pulseAnim.value) * 0.5,
                        child: Container(
                          width: 120 + 56 * _pulseAnim.value,
                          height: 120 + 56 * _pulseAnim.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accent, width: 2.5),
                          ),
                        ),
                      ),
                    ),
                    // Check circle
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_circleCtrl, _checkCtrl]),
                      builder: (_, __) => SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: SuccessCheckPainter(
                            circleProgress: _circleAnim.value,
                            checkProgress: _checkAnim.value,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _contentAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(_contentAnim),
                  child: Column(
                    children: [
                      // "Sale Recorded" badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: accent, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Sale Recorded',
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Amount
                      Text(
                        '₵${widget.amount}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: -0.8,
                          fontFamily: 'Constantia',
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Method pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(subtitleIcon,
                                color: AppColors.muted, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class SuccessCheckPainter extends CustomPainter {
  const SuccessCheckPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.color,
  });

  final double circleProgress;
  final double checkProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final p = circleProgress.clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      radius * p,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      center,
      (radius - 10) * p,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    if (checkProgress <= 0 || p < 0.7) return;

    final p1 = Offset(center.dx - 22, center.dy + 2);
    final p2 = Offset(center.dx - 6, center.dy + 18);
    final p3 = Offset(center.dx + 24, center.dy - 16);

    final seg1 = _dist(p1, p2);
    final seg2 = _dist(p2, p3);
    final total = seg1 + seg2;
    final drawn = total * checkProgress.clamp(0.0, 1.0);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - seg1) / seg2;
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _dist(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  bool shouldRepaint(SuccessCheckPainter old) =>
      old.circleProgress != circleProgress ||
      old.checkProgress != checkProgress ||
      old.color != color;
}
