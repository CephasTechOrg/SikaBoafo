import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SikaBofo auth screens — tokens from `tokens.css`.
abstract final class AuthMockup {
  static const bg = Color(0xFFF6F8F7);
  static const ink = Color(0xFF111827);
  static const ink2 = Color(0xFF6B7280);
  static const ink3 = Color(0xFF9AA3AF);
  static const line = Color(0xFFE5E7EB);
  static const lineSoft = Color(0xFFEEF1F0);
  static const green600 = Color(0xFF168A55);
  static const green700 = Color(0xFF0F7A4A);
  static const green900 = Color(0xFF073B2A);
  static const heroGreen = Color(0xFF0A4A34);

  static const gutter = 20.0;
  static const welcomeSheetRadius = 32.0;
  static const loginSheetRadius = 28.0;
  static const sheetOverlap = 28.0;

  static const fieldShadow = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

// ── Brand mark (logo in white rounded square) ────────────────────────────────

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
            ? const [BoxShadow(color: Color(0x2E071C14), blurRadius: 14, offset: Offset(0, 4))]
            : const [BoxShadow(color: Color(0x1F071C14), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

// ── Uppercase section label ───────────────────────────────────────────────────

class AuthSecLabel extends StatelessWidget {
  const AuthSecLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AuthMockup.ink3,
          height: 1.2,
        ),
      );
}

// ── Primary button ────────────────────────────────────────────────────────────

class AuthMockupPrimaryButton extends StatelessWidget {
  const AuthMockupPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
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
        boxShadow: (disabled || loading)
            ? null
            : const [BoxShadow(color: Color(0x47168A55), blurRadius: 16, offset: Offset(0, 6))],
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
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

// ── Ghost button ──────────────────────────────────────────────────────────────

class AuthMockupGhostButton extends StatelessWidget {
  const AuthMockupGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: disabled
                    ? AuthMockup.line.withValues(alpha: 0.6)
                    : AuthMockup.line,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
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

// ── Input field with focus border ─────────────────────────────────────────────

class AuthMockupField extends StatefulWidget {
  const AuthMockupField({
    super.key,
    required this.icon,
    required this.focusNode,
    required this.child,
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
  void didUpdateWidget(covariant AuthMockupField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
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
        color: Colors.white,
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

// ── Welcome hero (businesswoman image + gradient + brand) ─────────────────────

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
        // Gradient overlay matching mockup exactly
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
        // Brand row — bottom left
        const SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(AuthMockup.gutter, 0, AuthMockup.gutter, 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AuthMockupBrandMark(size: 46, radius: 13, light: true),
                  SizedBox(width: 12),
                  _BrandName(text: 'SikaBoafo', size: 22),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared green hero — used by login, OTP, and any future auth step ─────────

class AuthGreenHero extends StatelessWidget {
  const AuthGreenHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.sheetColor = AuthMockup.bg,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Color sheetColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Full-height gradient fills whatever height the Column drives
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AuthMockup.heroGreen, AuthMockup.green900],
                stops: [0.0, 0.75],
              ),
            ),
          ),
        ),

        // Glow orb — top right
        Positioned(
          right: -70, top: -80,
          child: _GlowOrb(size: 230, color: const Color(0xFF2EA06E).withValues(alpha: 0.40)),
        ),

        // Glow orb — bottom left
        Positioned(
          left: -70, bottom: -40,
          child: _GlowOrb(size: 200, color: const Color(0xFF145A3C).withValues(alpha: 0.50)),
        ),

        // Content column drives Stack height
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuthMockup.gutter - 6, 4, AuthMockup.gutter, 0,
                ),
                child: Column(
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onBack,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 38, height: 38,
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const AuthMockupBrandMark(size: 62, radius: 18, light: true),
                    const SizedBox(height: 14),
                    const _BrandName(text: 'SikaBoafo', size: 24),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.60),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Rounded cap — baked in so it is never viewport-clipped
            const SizedBox(height: 18),
            _AuthSheetCap(radius: AuthMockup.loginSheetRadius, color: sheetColor),
          ],
        ),
      ],
    );
  }
}

/// Login hero — thin wrapper that keeps the original public API intact.
class AuthLoginHero extends StatelessWidget {
  const AuthLoginHero({super.key, required this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => AuthGreenHero(
        title: 'Welcome back',
        subtitle: '',
        onBack: onBack,
      );
}

class _AuthSheetCap extends StatelessWidget {
  const _AuthSheetCap({required this.radius, required this.color});
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      );
}

class _BrandName extends StatelessWidget {
  const _BrandName({required this.text, required this.size});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.24,
          height: 1.1,
          shadows: const [Shadow(color: Color(0x59000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
      );
}

// ── PIN field styling ─────────────────────────────────────────────────────────

InputDecoration authPinInputDecoration({required bool obscured}) =>
    InputDecoration(
      hintText: '••••',
      hintStyle: GoogleFonts.plusJakartaSans(
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

TextStyle get authPhoneFieldStyle => GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AuthMockup.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

TextStyle get authPinFieldStyle => GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 6.4,
      color: AuthMockup.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
