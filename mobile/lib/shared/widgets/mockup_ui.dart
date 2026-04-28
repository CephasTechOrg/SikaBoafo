import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'app_components.dart';

class MockupHeroHeader extends StatelessWidget {
  const MockupHeroHeader({
    required this.child,
    this.waveHeight = 42,
    this.backgroundAssetPath = 'assets/images/swirlLatte.png',
    super.key,
  });

  final Widget child;
  final double waveHeight;
  final String? backgroundAssetPath;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(waveHeight: waveHeight),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.hero),
          ),
          if (backgroundAssetPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: Image.asset(
                  backgroundAssetPath!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          // Keep text readable (matches mockup's soft vignette)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
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

/// Reusable hero backdrop used behind every primary screen header.
///
/// Layers (bottom → top):
///   1. Green brand gradient (`AppGradients.hero`)
///   2. Swirl/latte texture at reduced opacity (so it tints the green
///      instead of replacing it — keeps brand color, adds depth)
///   3. Dark vignette that's strongest at the top so white headlines /
///      sub-titles always have enough contrast against the texture.
class HeroBackdrop extends StatelessWidget {
  const HeroBackdrop({
    super.key,
    this.swirlAssetPath = 'assets/images/swirlLatte.png',
    this.swirlOpacity = 0.55,
    this.topShade = 0.60,
    this.midShade = 0.20,
    this.shadeColor = Colors.black,
    this.tintColor = Colors.transparent,
    this.tintOpacity = 0,
  });

  final String swirlAssetPath;

  /// 0–1: how visible the swirl texture is (lower = more solid green).
  final double swirlOpacity;

  /// 0–1: alpha of the dark vignette at the very top of the hero.
  final double topShade;

  /// 0–1: alpha of the dark vignette around the middle of the hero.
  final double midShade;

  /// Base tint used for the hero vignette.
  final Color shadeColor;

  /// Color wash laid across the hero to shift the overall mood.
  final Color tintColor;

  /// 0-1: opacity of the color wash laid across the hero.
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.hero),
        ),
        Opacity(
          opacity: swirlOpacity,
          child: Image.asset(
            swirlAssetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        if (tintOpacity > 0)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  tintColor.withValues(alpha: tintOpacity),
                  tintColor.withValues(alpha: tintOpacity * 0.78),
                  tintColor.withValues(alpha: tintOpacity * 0.22),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.34, 0.72, 1.0],
              ),
            ),
          ),
        if (tintOpacity > 0)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.08),
                radius: 0.44,
                colors: [
                  tintColor.withValues(alpha: tintOpacity * 1.9),
                  tintColor.withValues(alpha: tintOpacity * 0.9),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.24, 1.0],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                shadeColor.withValues(alpha: topShade),
                shadeColor.withValues(alpha: midShade),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class MockupAppMark extends StatelessWidget {
  const MockupAppMark({
    this.size = 72,
    this.assetPath = 'assets/images/logo.png',
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
        hintText: ' ' * (length < 1 ? 1 : length),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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

/// Page scaffold matching the dashboard mockup language: a swirl/latte hero
/// with a title bar at the top, then a white curved content sheet below.
///
/// Use this for top-level screens like Inventory, Expenses, Customers, etc.
/// where you want a consistent look without rewriting every screen.
class MockupScreenScaffold extends StatelessWidget {
  const MockupScreenScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.onBack,
    this.actions,
    this.heroExtra,
    this.heroHeight = 168,
    this.bottomNavSafeArea = false,
    this.backgroundAssetPath = 'assets/images/swirlLatte.png',
    this.bottomBar,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? heroExtra;
  final double heroHeight;
  final bool bottomNavSafeArea;
  final String? backgroundAssetPath;
  final Widget body;

  /// Optional persistent footer (e.g. a primary "Save" button). Renders as the
  /// Scaffold's `bottomNavigationBar` so it sticks above the keyboard / nav bar.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    const sheetCurveLift = 28.0;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      bottomNavigationBar: bottomBar,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.canvas),
        child: Stack(
          children: [
            // Hero swirl
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.hero),
                  ),
                  if (backgroundAssetPath != null)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.55,
                        child: Image.asset(
                          backgroundAssetPath!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // White content sheet (lifted slightly so its rounded corners are
            // visible against the hero swirl).
            Positioned(
              left: 0,
              right: 0,
              top: heroHeight - sheetCurveLift,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.vertical(
                    top: AppRadii.heroRadius,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 28,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  bottom: bottomNavSafeArea,
                  child: Padding(
                    padding: const EdgeInsets.only(top: sheetCurveLift + 6),
                    child: body,
                  ),
                ),
              ),
            ),

            // Hero content (title + actions + extras)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: heroHeight,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    onBack != null ? 6 : 18,
                    8,
                    18,
                    sheetCurveLift + 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (onBack != null)
                            IconButton(
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white),
                              tooltip: 'Back',
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.78),
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (actions != null && actions!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            for (final a in actions!) ...[
                              a,
                              const SizedBox(width: 6),
                            ],
                          ],
                        ],
                      ),
                      if (heroExtra != null) ...[
                        const Spacer(),
                        heroExtra!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact circular header action button that mirrors the dashboard mockup.
class MockupHeaderAction extends StatelessWidget {
  const MockupHeaderAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.18),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}
