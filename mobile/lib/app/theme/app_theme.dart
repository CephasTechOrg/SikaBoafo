import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand — unchanged
  static const Color forest = Color(0xFF0F5C4F);
  static const Color forestDark = Color(0xFF0A3A34);
  static const Color forestNight = Color(0xFF062824);
  static const Color gold = Color(0xFFB8902E);
  static const Color goldSoft = Color(0xFFF5E7C6);

  // Cool neutral ramp
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color ink = Color(0xFF0F172A);
  static const Color inkSoft = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color mutedSoft = Color(0xFF94A3B8);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSoft = Color(0xFFDBEAFE);

  // Legacy aliases — retained so existing call-sites compile until per-screen migration.
  static const Color mint = Color(0xFFE8F4F0);
  static const Color mist = Color(0xFFF1F5F9);
  static const Color amber = warning;
  static const Color coral = Color(0xFFE16C5B);
  static const Color sky = info;
  static const Color surfaceSoft = surfaceAlt;
}

abstract final class AppInsets {
  static const double xxs = 6;
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
}

abstract final class AppRadii {
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;
  static const Radius heroRadius = Radius.circular(32);
}

abstract final class AppGradients {
  static const LinearGradient hero = LinearGradient(
    colors: [AppColors.forestNight, AppColors.forestDark, AppColors.forest],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shell = LinearGradient(
    colors: [AppColors.forestNight, AppColors.forest, AppColors.canvas],
    stops: [0.0, 0.28, 0.28],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accent = LinearGradient(
    colors: [Color(0x33D4A94D), Color(0x14FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 8,
      offset: Offset(0, 1),
    ),
  ];
}

// Legacy aliases retained for backwards-compat.
const List<BoxShadow> kCardShadow = AppShadows.card;
const List<BoxShadow> kSubtleShadow = AppShadows.subtle;

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.forest,
    brightness: Brightness.light,
    primary: AppColors.forest,
    secondary: AppColors.gold,
    surface: AppColors.surface,
    error: AppColors.danger,
  ).copyWith(
    primary: AppColors.forest,
    onPrimary: Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surfaceAlt,
    outline: AppColors.border,
    outlineVariant: AppColors.borderStrong,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'SegoeUI',
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.6,
      height: 1.12,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.4,
      height: 1.14,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.2,
      height: 1.25,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.1,
      height: 1.4,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      height: 1.33,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.38,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.43,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.inkSoft,
      height: 1.47,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.inkSoft,
      height: 1.43,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.muted,
      height: 1.38,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      letterSpacing: 0.1,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
      letterSpacing: 0.3,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
      letterSpacing: 0.4,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: AppColors.mint,
      height: 76,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? AppColors.forest : AppColors.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.forest : AppColors.muted,
          size: 22,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.mutedSoft),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forest,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    iconTheme: const IconThemeData(color: AppColors.inkSoft, size: 22),
  );
}
