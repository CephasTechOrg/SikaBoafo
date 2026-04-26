import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'app_components.dart';

class MockupHeroHeader extends StatelessWidget {
  const MockupHeroHeader({
    required this.child,
    this.waveHeight = 42,
    this.enableSwirl = true,
    super.key,
  });

  final Widget child;
  final double waveHeight;
  final bool enableSwirl;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(waveHeight: waveHeight),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.hero)),
          if (enableSwirl)
            CustomPaint(
              painter: _SwirlPainter(
                light: const Color(0x33FFFFFF),
                accent: const Color(0x22C49A2A),
                dark: const Color(0x22000000),
              ),
            ),
          // Slight softening like the mockup texture
          if (enableSwirl)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6),
              child: const SizedBox.expand(),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24 + 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class MockupAppMark extends StatelessWidget {
  const MockupAppMark({
    this.size = 72,
    this.assetPath = 'assets/images/sikaboafo.png',
    super.key,
  });

  final double size;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.18),
        child: Image.asset(assetPath, fit: BoxFit.cover),
      ),
    );
  }
}

class MockupCtaButton extends StatelessWidget {
  const MockupCtaButton.primary({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.primary;

  const MockupCtaButton.secondary({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  }) : variant = AppButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      variant: variant,
      size: AppButtonSize.lg,
      icon: icon,
      loading: loading,
      fullWidth: true,
    );
  }
}

class OtpCodeInputRow extends StatelessWidget {
  const OtpCodeInputRow({
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      maxLength: length,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            letterSpacing: 20,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
      decoration: InputDecoration(
        counterText: '',
        hintText: ' ' * math.max(1, length),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      onChanged: (v) {
        final digits = v.replaceAll(RegExp(r'\D+'), '');
        if (digits != v) controller.text = digits;
        if (controller.text.length > length) {
          controller.text = controller.text.substring(0, length);
        }
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        onChanged?.call(controller.text);
      },
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  _WaveClipper({required this.waveHeight});

  final double waveHeight;

  @override
  Path getClip(Size size) {
    final h = waveHeight;
    final path = Path()..lineTo(0, size.height - h);
    path.quadraticBezierTo(
      size.width * 0.22,
      size.height - h * 1.4,
      size.width * 0.5,
      size.height - h * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.78,
      size.height - h * 0.35,
      size.width,
      size.height - h * 0.85,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _WaveClipper oldClipper) {
    return oldClipper.waveHeight != waveHeight;
  }
}

class _SwirlPainter extends CustomPainter {
  const _SwirlPainter({
    required this.light,
    required this.accent,
    required this.dark,
  });

  final Color light;
  final Color accent;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.55, size.height * 0.45);

    void strokePath(Path path, Color color, double width, double blur) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..strokeWidth = width
        ..maskFilter = blur <= 0 ? null : MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawPath(path, p);
    }

    // Build a few smooth “latte” ribbons.
    Path ribbon(double phase, double radius) {
      final path = Path();
      const steps = 7;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final ang = (t * math.pi * 2) + phase;
        final r = radius * (0.9 + 0.18 * math.sin(ang * 1.6 + phase));
        final x = center.dx + math.cos(ang) * r * 1.25;
        final y = center.dy + math.sin(ang) * r * 0.85;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.quadraticBezierTo(
            (x + center.dx) / 2,
            (y + center.dy) / 2,
            x,
            y,
          );
        }
      }
      return path;
    }

    // Dark under-ribbons (depth)
    for (int i = 0; i < 4; i++) {
      final path = ribbon(i * 0.55, size.shortestSide * (0.30 + i * 0.06));
      strokePath(path, dark, 36 - i * 4, 10);
    }

    // Highlight ribbons (milk)
    for (int i = 0; i < 4; i++) {
      final path = ribbon(0.35 + i * 0.6, size.shortestSide * (0.26 + i * 0.06));
      strokePath(path, light, 28 - i * 4, 8);
    }

    // A touch of warm accent
    strokePath(
      ribbon(1.15, size.shortestSide * 0.34),
      accent,
      22,
      7,
    );

    // Subtle vignette so text remains readable.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, -0.3),
        radius: 1.05,
        colors: [
          Colors.transparent,
          const Color(0x22000000),
          const Color(0x3A000000),
        ],
        stops: const [0.0, 0.72, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _SwirlPainter oldDelegate) {
    return oldDelegate.light != light ||
        oldDelegate.accent != accent ||
        oldDelegate.dark != dark;
  }
}
