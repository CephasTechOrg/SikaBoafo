import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// SikaBofo auth screens — tokens from `tokens.css`.
abstract final class AuthMockup {
  static const bg = Color(0xFFF6F8F7);
  static const ink2 = Color(0xFF6B7280);
  static const ink3 = Color(0xFF9AA3AF);
  static const line = Color(0xFFE5E7EB);
  static const green600 = Color(0xFF168A55);
  static const green700 = Color(0xFF0F7A4E);
  static const green900 = Color(0xFF073B2A);
  static const heroGreen = Color(0xFF0A4A34);

  static const gutter = 20.0;
  static const welcomeSheetRadius = 32.0;
  static const loginSheetRadius = 28.0;
  static const sheetOverlap = 28.0;

  static const fieldShadow = [
    BoxShadow(
      color: Color(0x0A101828),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A101828),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

/// Mockup `BrandMark` with optional light shadow.
class AuthMockupBrandMark extends StatelessWidget {
  const AuthMockupBrandMark({
    super.key,
    this.size = 44,
    this.radius,
    this.light = false,
    this.assetPath = 'assets/images/logo.png',
  });

  final double size;
  final double? radius;
  final bool light;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * (13 / 44);
    final pad = size * 0.13;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: light
            ? const [
                BoxShadow(
                  color: Color(0x2E071C14),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x1F071C14),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

/// Mockup `.sec-label` for form fields.
class AuthSecLabel extends StatelessWidget {
  const AuthSecLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AuthMockup.ink3,
        height: 1.2,
      ),
    );
  }
}

/// Mockup `btn btn--primary` (54px).
class AuthMockupPrimaryButton extends StatelessWidget {
  const AuthMockupPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: disabled || loading
            ? null
            : const [
                BoxShadow(
                  color: Color(0x47168A55),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Material(
          color: disabled ? const Color(0xFFE7EAE9) : AuthMockup.green600,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: disabled ? AuthMockup.ink3 : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mockup `btn btn--ghost`.
class AuthMockupGhostButton extends StatelessWidget {
  const AuthMockupGhostButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: disabled ? AuthMockup.line.withValues(alpha: 0.6) : AuthMockup.line,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: disabled ? AuthMockup.ink3 : AuthMockup.green700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mockup `Field` with focus border highlight.
class AuthMockupField extends StatefulWidget {
  const AuthMockupField({
    required this.icon,
    required this.focusNode,
    required this.child,
    super.key,
    this.trailing,
  });

  final IconData icon;
  final FocusNode focusNode;
  final Widget child;
  final Widget? trailing;

  @override
  State<AuthMockupField> createState() => _AuthMockupFieldState();
}

class _AuthMockupFieldState extends State<AuthMockupField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AuthMockupField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AuthMockup.green600 : AuthMockup.line,
          width: 1.5,
        ),
        boxShadow: AuthMockup.fieldShadow,
      ),
      child: Row(
        children: [
          Icon(
            widget.icon,
            size: 19,
            color: focused ? AuthMockup.green700 : AuthMockup.ink3,
          ),
          const SizedBox(width: 11),
          Expanded(child: widget.child),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}

/// Welcome hero — businesswoman image + gradient + brand.
class AuthWelcomeHero extends StatelessWidget {
  const AuthWelcomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/businesswoman.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.76),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.28, 0.60, 1.0],
              colors: [
                Color(0x5907281C),
                Color(0x0007281C),
                Color(0x0007281C),
                Color(0x8C073B2A),
              ],
            ),
          ),
        ),
        const SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AuthMockup.gutter,
                0,
                AuthMockup.gutter,
                40,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AuthMockupBrandMark(size: 46, radius: 13, light: true),
                  SizedBox(width: 12),
                  Text(
                    'SikaBoafo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.22,
                      height: 1.1,
                      shadows: [
                        Shadow(
                          color: Color(0x59000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Login hero — green gradient, glows, back + brand.
class AuthLoginHero extends StatelessWidget {
  const AuthLoginHero({super.key, required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 52),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.05, -1),
          end: Alignment(0.05, 1),
          colors: [AuthMockup.heroGreen, AuthMockup.green900],
          stops: [0.0, 0.75],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -70,
            top: -80,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2EA06E).withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            left: -70,
            bottom: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF145A3C).withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AuthMockup.gutter - 6,
                2,
                AuthMockup.gutter,
                0,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: onBack,
                        borderRadius: BorderRadius.circular(12),
                        child: const SizedBox(
                          width: 38,
                          height: 38,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AuthMockupBrandMark(size: 62, radius: 18, light: true),
                  const SizedBox(height: 14),
                  const Text(
                    'SikaBoafo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.23,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pin field styling — large letter-spaced digits.
InputDecoration authPinInputDecoration({required bool obscured}) {
  return InputDecoration(
    hintText: '••••',
    hintStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 6,
      color: AuthMockup.ink3.withValues(alpha: 0.5),
    ),
    border: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
    counterText: '',
  );
}

TextStyle get authPhoneFieldStyle => const TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    );

TextStyle get authPinFieldStyle => const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 6.4,
      color: AppColors.ink,
      fontFeatures: [FontFeature.tabularFigures()],
    );
