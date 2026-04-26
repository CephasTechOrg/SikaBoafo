import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'app_components.dart';

class MockupHeroHeader extends StatelessWidget {
  const MockupHeroHeader({
    required this.child,
    this.waveHeight = 42,
    super.key,
  });

  final Widget child;
  final double waveHeight;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(waveHeight: waveHeight),
      child: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24 + 18),
            child: child,
          ),
        ),
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
