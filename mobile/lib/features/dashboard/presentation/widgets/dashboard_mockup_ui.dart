import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from SikaBofo tokens.css — single source of truth.
abstract final class DashboardMockup {
  // Colours
  static const bg         = Color(0xFFF6F8F7);
  static const card       = Color(0xFFFFFFFF);
  static const ink        = Color(0xFF111827);
  static const ink2       = Color(0xFF6B7280);
  static const ink3       = Color(0xFF9AA3AF);
  static const line       = Color(0xFFE5E7EB);
  static const lineSoft   = Color(0xFFEEF1F0);
  static const green900   = Color(0xFF073B2A);
  static const green700   = Color(0xFF0F7A4A);
  static const green600   = Color(0xFF168A55);
  static const greenTint  = Color(0xFFEAF6EF);
  static const greenTint2 = Color(0xFFF1F9F4);
  static const danger     = Color(0xFFD23B3B);
  static const dangerTint = Color(0xFFFBECEC);
  static const warn       = Color(0xFFBE8A2C);
  static const warnTint   = Color(0xFFFAF3E1);
  static const ok         = Color(0xFF2F7D58);
  static const okTint     = Color(0xFFEBF4EF);
  static const heroGreen  = Color(0xFF0A4A34);

  // Layout
  static const double gutter      = 20;
  static const double sheetOverlap = 24;
  static const double sheetRadius  = 20;
  static const double cardRadius   = 20;
  static const double tileRadius   = 14;
  static const double inputRadius  = 14;
  static const double btnRadius    = 14;

  // Shadows
  static const cardShadow = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2,  offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const popShadow = [
    BoxShadow(color: Color(0x1F101828), blurRadius: 30, offset: Offset(0, 8)),
  ];
  static const navShadow = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 0,  offset: Offset(0, -1)),
    BoxShadow(color: Color(0x0D101828), blurRadius: 24, offset: Offset(0, -8)),
  ];
}

/// Plus Jakarta Sans text style factory — all dashboard typography goes here.
abstract final class DSText {
  static TextStyle pjs({
    required double size,
    required FontWeight weight,
    Color color = DashboardMockup.ink,
    double? height,
    double letterSpacing = 0,
    List<FontFeature>? fontFeatures,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
      );

  // ── Hero / sales number ──────────────────────────────────────────────────
  static TextStyle heroAmount({Color color = Colors.white}) => pjs(
        size: 46,
        weight: FontWeight.w800,
        color: color,
        height: 1,
        letterSpacing: -1.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Section label (uppercase small caps) ────────────────────────────────
  static TextStyle secLabel({bool onDark = false}) => pjs(
        size: 12,
        weight: FontWeight.w700,
        letterSpacing: 1.2,
        color: onDark
            ? Colors.white.withValues(alpha: 0.60)
            : DashboardMockup.ink3,
      );

  // ── Section title ────────────────────────────────────────────────────────
  static TextStyle secTitle() => pjs(
        size: 18,
        weight: FontWeight.w700,
        color: DashboardMockup.ink,
        letterSpacing: -0.2,
      );

  // ── Link ─────────────────────────────────────────────────────────────────
  static TextStyle link() => pjs(
        size: 14,
        weight: FontWeight.w600,
        color: DashboardMockup.green700,
      );

  // ── Card big value ───────────────────────────────────────────────────────
  static TextStyle cardValue({double size = 21}) => pjs(
        size: size,
        weight: FontWeight.w800,
        color: DashboardMockup.ink,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Card label ───────────────────────────────────────────────────────────
  static TextStyle cardLabel() => pjs(
        size: 13,
        weight: FontWeight.w500,
        color: DashboardMockup.ink2,
      );

  // ── Row title ────────────────────────────────────────────────────────────
  static TextStyle rowTitle() => pjs(
        size: 16,
        weight: FontWeight.w700,
        color: DashboardMockup.ink,
      );

  // ── Row sub ──────────────────────────────────────────────────────────────
  static TextStyle rowSub() => pjs(
        size: 13,
        weight: FontWeight.w500,
        color: DashboardMockup.ink2,
      );

  // ── Activity title / amount ──────────────────────────────────────────────
  static TextStyle activityTitle() => pjs(
        size: 15,
        weight: FontWeight.w700,
        color: DashboardMockup.ink,
      );

  static TextStyle activitySub() => pjs(
        size: 13,
        weight: FontWeight.w500,
        color: DashboardMockup.ink2,
      );

  static TextStyle activityAmount({required bool income}) => pjs(
        size: 15,
        weight: FontWeight.w800,
        color: income ? DashboardMockup.green700 : DashboardMockup.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle activityPayLabel() => pjs(
        size: 12,
        weight: FontWeight.w600,
        color: DashboardMockup.ink3,
      );

  // ── Nav label ────────────────────────────────────────────────────────────
  static TextStyle navLabel({required bool selected}) => pjs(
        size: 12,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
        color:
            selected ? DashboardMockup.green900 : DashboardMockup.ink3,
      );
}

// ── Shared card widget ───────────────────────────────────────────────────────

class DashboardCard extends StatelessWidget {
  const DashboardCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardMockup.card,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        border: Border.all(color: DashboardMockup.lineSoft),
        boxShadow: DashboardMockup.cardShadow,
      ),
      padding: padding,
      child: child,
    );
  }
}

// ── Section head ─────────────────────────────────────────────────────────────

class DashSectionHead extends StatelessWidget {
  const DashSectionHead({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: DSText.secTitle())),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: DSText.link()),
          ),
      ],
    );
  }
}

// ── Uppercase section label ───────────────────────────────────────────────────

class DashSecLabel extends StatelessWidget {
  const DashSecLabel(this.text, {this.onDark = false, super.key});

  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: DSText.secLabel(onDark: onDark),
      );
}

// ── Row divider ──────────────────────────────────────────────────────────────

class DashRowDivider extends StatelessWidget {
  const DashRowDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: DashboardMockup.lineSoft,
      );
}

// ── Skeleton box ─────────────────────────────────────────────────────────────

class DashSkeletonBox extends StatelessWidget {
  const DashSkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E9EE),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ── Legacy alias (kept so other screens that import this still compile) ───────
@Deprecated('Use DashboardCard')
typedef DashboardMockupCard = DashboardCard;
@Deprecated('Use DashSectionHead')
typedef DashboardSectionHead = DashSectionHead;
@Deprecated('Use DashSecLabel')
typedef DashboardSecLabel = DashSecLabel;
