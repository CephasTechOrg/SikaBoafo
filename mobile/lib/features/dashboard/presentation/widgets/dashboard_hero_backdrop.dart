import 'package:flutter/material.dart';

class DashboardHeroBackdrop extends StatelessWidget {
  const DashboardHeroBackdrop({
    super.key,
    required this.swirlAssetPath,
  });

  final String swirlAssetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Deep forest base
        Positioned.fill(
          child: Container(color: const Color(0xFF031A0C)),
        ),

        // 2. Flag/swirl image — slightly dimmed so it's visible but not loud
        Positioned.fill(
          child: Opacity(
            opacity: 0.55,
            child: Image.asset(
              swirlAssetPath,
              fit: BoxFit.cover,
            ),
          ),
        ),

        // 3. Rich green radial bloom — centred top-right for depth
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.55, -0.6),
                radius: 1.1,
                colors: [
                  Color(0x881B7A44), // vivid green centre
                  Color(0x441A5C33), // mid
                  Color(0x00000000), // fades out
                ],
              ),
            ),
          ),
        ),

        // 4. Main top-to-bottom gradient — keeps text readable at top,
        //    and opens up to transparent at the bottom (where the card lifts)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.72, 1.0],
                colors: [
                  Color(0xCC031A0C), // dark at the very top (status bar)
                  Color(0x801A6840), // rich green mid-upper
                  Color(0x3A0D4023), // lighter green lower
                  Color(0x00000000), // fully transparent at sheet edge
                ],
              ),
            ),
          ),
        ),

        // 5. Subtle left-edge vignette for depth
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x44031A0C),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
