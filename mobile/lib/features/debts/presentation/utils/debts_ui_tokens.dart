import 'package:flutter/material.dart';

/// Visual tokens for the Debts feature, aligned to the mockup design system.
///
/// Two namespaces live here:
///   * Legacy fields (`heroDark`, `pillRadius`, ...) are retained so older
///     widgets keep compiling during the mockup migration.
///   * `DebtsUi` is the new mockup-aligned token set: green ramp, gold/red
///     accents, surface tints, radii, shadows, and gradients used by every
///     debts screen, sheet, and popup so they share one visual language.
abstract final class DebtsUiTokens {
  // ----- Legacy aliases (kept for migration safety) -----
  static const Color heroDark = DebtsUi.greenDeep;
  static const Color heroMid = DebtsUi.greenDark;
  static const Color heroLight = DebtsUi.greenMid;

  static const double pillRadius = 999;
  static const double cardRadius = DebtsUi.radiusMd;
  static const double tileRadius = DebtsUi.radiusMd;

  static const Duration tabSwitchAnimation = Duration(milliseconds: 180);
}

/// Mockup-aligned design tokens for the debts module.
abstract final class DebtsUi {
  // Brand greens
  static const Color greenDeep = Color(0xFF0D3D2B);
  static const Color greenDark = Color(0xFF145233);
  static const Color greenMid = Color(0xFF1A6B42);
  static const Color greenBright = Color(0xFF22A05A);
  static const Color greenLight = Color(0xFFD4F0E1);
  static const Color greenPale = Color(0xFFEDF8F2);

  // Accents
  static const Color accentGold = Color(0xFFF5A623);
  static const Color accentGoldSoft = Color(0xFFFFF8EC);
  static const Color accentGoldBorder = Color(0xFFFFE8B0);
  static const Color accentGoldInk = Color(0xFFB07C1A);

  static const Color danger = Color(0xFFE05252);
  static const Color dangerSoft = Color(0xFFFEF0F0);
  static const Color dangerBorder = Color(0xFFFCDCDC);

  // Text
  static const Color textPrimary = Color(0xFF0D1F17);
  static const Color textSecondary = Color(0xFF4D6B5B);
  static const Color textMuted = Color(0xFF8AAB98);

  // Surfaces
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF5FAF7);
  static const Color canvas = Color(0xFFE8F2EC);
  static const Color border = Color(0xFFE0EDE8);

  // Radii
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  // Shadows
  static const List<BoxShadow> shadowSm = <BoxShadow>[
    BoxShadow(
      color: Color(0x1207401A), // rgba(13,61,43,0.07)
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowMd = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0D3D2B), // rgba(13,61,43,0.12)
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> shadowLg = <BoxShadow>[
    BoxShadow(
      color: Color(0x290D3D2B), // rgba(13,61,43,0.16)
      blurRadius: 48,
      offset: Offset(0, 16),
    ),
  ];

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenDeep, greenDark, greenMid],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenBright, greenMid],
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [greenBright, greenMid],
  );

  // Avatar tints
  static const Color avatarGreenBg = greenPale;
  static const Color avatarGreenFg = greenMid;
  static const Color avatarGreenBorder = greenLight;
  static const Color avatarGoldBg = accentGoldSoft;
  static const Color avatarGoldFg = accentGoldInk;
  static const Color avatarGoldBorder = accentGoldBorder;

  // Status badge tones
  static const Color settledBg = greenPale;
  static const Color settledFg = greenMid;
  static const Color settledBorder = greenLight;

  static const Color openBg = accentGoldSoft;
  static const Color openFg = accentGoldInk;
  static const Color openBorder = accentGoldBorder;

  static const Color overdueBg = dangerSoft;
  static const Color overdueFg = danger;
  static const Color overdueBorder = dangerBorder;
}
