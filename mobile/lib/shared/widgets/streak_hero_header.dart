import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class StreakHeroHeader extends StatelessWidget {
  const StreakHeroHeader({
    required this.leadingContentInset,
    required this.title,
    required this.subtitle,
    this.badge,
    this.gradient,
    super.key,
  });

  final double leadingContentInset;
  final String title;
  final String subtitle;
  final Widget? badge;

  /// Override the default gradient. When set, the decorative soft circles
  /// are also hidden so the look matches a simpler flat-gradient header.
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient ??
                    const LinearGradient(
                      colors: [
                        Color(0xFF041C0B),
                        Color(0xFF083A1A),
                        Color(0xFF0F5A30),
                        Color(0xFF196E3D),
                      ],
                      stops: [0.0, 0.28, 0.62, 1.0],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
              ),
            ),
          ),
          if (gradient == null) ...[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.68, -0.72),
                    radius: 0.92,
                    colors: [
                      const Color(0xFF27A84E).withValues(alpha: 0.40),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF010A04).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            const Positioned(
              left: -42,
              top: -38,
              child: _SoftCircle(size: 120, opacity: 0.14),
            ),
            const Positioned(
              right: -54,
              top: 24,
              child: _SoftCircle(size: 160, opacity: 0.10),
            ),
            const Positioned(
              right: 22,
              bottom: -48,
              child: _SoftCircle(size: 140, opacity: 0.12),
            ),
          ],
          if (gradient != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.72, -0.65),
                    radius: 0.75,
                    colors: [
                      const Color(0xFF22C55E).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                leadingContentInset,
                18,
                20,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[
                    badge!,
                    const SizedBox(height: 10),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      height: 1.25,
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

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mint.withValues(alpha: opacity),
      ),
    );
  }
}

