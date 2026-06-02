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
  // Brand greens — anchored to mockup's green-900/#073B2A (deep) → green-700/#0F7A4A (primary)
  static const Color greenDeep = Color(0xFF073B2A);
  static const Color greenDark = Color(0xFF0A4A34);
  static const Color greenMid = Color(0xFF0F7A4A);
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
  /// Main background behind Debts / Customers list + detail feeds (neutral gray).
  static const Color pageBackground = Color(0xFFF6F8F7);
  /// Toolbar band under rounded header — search + filter pills sit here.
  static const Color toolbarBackground = Color(0xFFF7F8F8);
  /// Borders on list tiles / neutral cards — less mint than [border].
  static const Color borderNeutral = Color(0xFFE5E8E6);
  /// Legacy mint canvas; prefer [pageBackground] for new layouts.
  static const Color canvas = pageBackground;

  /// Inset stroke for forms and tinted panels (warm gray-green hint).
  static const Color border = Color(0xFFE0EDE8);

  // Radii
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  /// Soft gray shadow — list cards on neutral page (no green cast).
  static const List<BoxShadow> shadowNeutralSm = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Green-tinted shadow (FAB, emphasis on greens).
  static const List<BoxShadow> shadowSm = <BoxShadow>[
    BoxShadow(
      color: Color(0x1207401A),
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
  // Nearly-vertical gradient matching mockup's linear-gradient(178deg, #0A4A34 0%, #073B2A 70%)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [greenDark, greenDeep],
    stops: [0.0, 0.7],
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
  static const Color avatarNeutralBg = Color(0xFFF3F6F4);
  static const Color avatarNeutralFg = Color(0xFF5A7268);
  static const Color avatarNeutralBorder = Color(0xFFE5EBE8);

  // Status badge tones
  static const Color settledBg = avatarNeutralBg;
  static const Color settledFg = avatarNeutralFg;
  static const Color settledBorder = avatarNeutralBorder;

  static const Color openBg = accentGoldSoft;
  static const Color openFg = accentGoldInk;
  static const Color openBorder = accentGoldBorder;

  static const Color overdueBg = dangerSoft;
  static const Color overdueFg = danger;
  static const Color overdueBorder = dangerBorder;

  /// Selected filter pill (charcoal fill, white label).
  static const Color tabSelectedFill = textPrimary;
  static const Color tabSelectedFg = Color(0xFFFFFFFF);
}
