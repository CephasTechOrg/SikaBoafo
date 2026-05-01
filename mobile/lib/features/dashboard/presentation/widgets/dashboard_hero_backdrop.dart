import 'package:flutter/material.dart';

class DashboardHeroBackdrop extends StatelessWidget {
  const DashboardHeroBackdrop({
    super.key,
    required this.swirlAssetPath,
    this.swirlOpacity = 0.72,
    this.topShade = 0.72,
    this.midShade = 0.40,
    this.shadeColor = const Color(0xFF04170A),
    this.tintColor = const Color(0xFF0A4F24),
    this.tintOpacity = 0.34,
  });

  final String swirlAssetPath;
  final double swirlOpacity;
  final double topShade;
  final double midShade;
  final Color shadeColor;
  final Color tintColor;
  final double tintOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark shade
        Positioned.fill(child: Container(color: shadeColor)),

        // Swirl image (e.g. flag or abstract pattern)
        Positioned.fill(
          child: Opacity(
            opacity: swirlOpacity,
            child: Image.asset(
              swirlAssetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Tint overlay
        Positioned.fill(
          child: Container(
            color: tintColor.withValues(alpha: tintOpacity),
          ),
        ),

        // Gradient for depth
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  shadeColor.withValues(alpha: topShade),
                  shadeColor.withValues(alpha: midShade),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
