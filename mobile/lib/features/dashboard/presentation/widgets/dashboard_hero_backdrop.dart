import 'package:flutter/material.dart';

import 'dashboard_mockup_ui.dart';

/// Dark-green hero background: gradient + glow orbs + Ghana map watermark.
class DashboardHeroBackdrop extends StatelessWidget {
  const DashboardHeroBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Base gradient ──────────────────────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [DashboardMockup.heroGreen, DashboardMockup.green900],
              stops: [0.0, 0.70],
            ),
          ),
        ),

        // ── Glow orb — top right ───────────────────────────────────────────
        Positioned(
          right: -70,
          top: -90,
          child: _GlowOrb(
            size: 240,
            color: const Color(0xFF2EA06E).withValues(alpha: 0.45),
          ),
        ),

        // ── Glow orb — bottom left ─────────────────────────────────────────
        Positioned(
          left: -80,
          bottom: -70,
          child: _GlowOrb(
            size: 200,
            color: const Color(0xFF145A3C).withValues(alpha: 0.50),
          ),
        ),

        // ── Ghana map watermark ────────────────────────────────────────────
        Positioned(
          right: -40,
          top: 4,
          width: 320,
          child: Opacity(
            opacity: 0.10,
            child: Image.asset(
              'assets/images/map.png',
              fit: BoxFit.contain,
              alignment: Alignment.topRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
}
