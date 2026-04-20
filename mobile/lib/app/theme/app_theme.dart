import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color forest = Color(0xFF0F5C4F);
  static const Color forestDark = Color(0xFF0A3A34);
  static const Color forestNight = Color(0xFF062824);
  static const Color mint = Color(0xFFE8F4F0);
  static const Color mist = Color(0xFFF4F8F6);
  static const Color gold = Color(0xFFD4A94D);
  static const Color goldSoft = Color(0xFFF5E7C6);
  static const Color amber = Color(0xFFD48B22);
  static const Color sky = Color(0xFF6E97D8);
  static const Color ink = Color(0xFF162321);
  static const Color muted = Color(0xFF677774);
  static const Color canvas = Color(0xFFF3F1EA);
  static const Color surface = Color(0xFFFFFCF7);
  static const Color surfaceSoft = Color(0xFFF9F6EF);
  static const Color border = Color(0xFFE4DED0);
  static const Color success = Color(0xFF0D7A6B);
  static const Color warning = Color(0xFFAF6A12);
  static const Color danger = Color(0xFFB33A2E);
  static const Color coral = Color(0xFFE16C5B);
}

abstract final class AppInsets {
  static const double xxs = 6;
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppRadii {
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
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

const kCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 28,
    offset: Offset(0, 10),
  ),
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

const kSubtleShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x10000000),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];

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
    onSecondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surfaceSoft,
    outline: AppColors.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'SegoeUI',
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.copyWith(
      fontFamily: 'Constantia',
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -1.1,
      height: 1.02,
    ),
    displayMedium: base.textTheme.displayMedium?.copyWith(
      fontFamily: 'Constantia',
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.8,
      height: 1.04,
    ),
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontFamily: 'Constantia',
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.6,
      height: 1.08,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontFamily: 'Constantia',
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: 0.1,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      color: AppColors.ink,
      height: 1.4,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: 14,
      color: AppColors.muted,
      height: 1.42,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: AppColors.muted,
      height: 1.35,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: 0.1,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 0.35,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 0.5,
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
      backgroundColor: Colors.white.withValues(alpha: 0.98),
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
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
        borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
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
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
  );
}
