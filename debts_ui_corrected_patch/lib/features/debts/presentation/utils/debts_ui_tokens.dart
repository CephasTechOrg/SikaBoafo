import 'package:flutter/material.dart';

/// Local design tokens for the Debts/Receivables feature.
/// Keep these presentation-only. Do not place business logic here.
abstract final class DebtTokens {
  // ── Hero gradient ──────────────────────────────────────────────────────────
  static const Color hero900 = Color(0xFF03170A);
  static const Color hero800 = Color(0xFF052E16);
  static const Color hero700 = Color(0xFF064E2B);
  static const Color hero600 = Color(0xFF0F7A3B);
  static const Color hero500 = Color(0xFF178A4B);

  // ── Neutral surfaces ───────────────────────────────────────────────────────
  static const Color paper = Color(0xFFFFFCF4);
  static const Color paperEdge = Color(0xFFF2E8D3);
  static const Color paperMuted = Color(0xFF7A6A52);
  static const Color sheetSurface = Color(0xFFFFFFFF);
  static const Color sheetCanvas = Color(0xFFF7F9F7);
  static const Color fieldSurface = Color(0xFFFFFFFF);
  static const Color fieldBorder = Color(0xFFDDE5DF);
  static const Color fieldFocused = hero700;
  static const Color inkStrong = Color(0xFF0F172A);

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double sheetTopRadius = 32;
  static const double balanceCardRadius = 28;
  static const double receiptRadius = 26;
  static const double panelRadius = 22;
  static const double debtCardRadius = 20;
  static const double metricTileRadius = 16;
  static const double buttonRadius = 16;
  static const double fieldRadius = 16;
  static const double pillRadius = 999;

  // ── Shadows ────────────────────────────────────────────────────────────────
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 10, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x07111827), blurRadius: 6, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x26111827), blurRadius: 28, offset: Offset(0, -10)),
  ];
  static const List<BoxShadow> receipt = [
    BoxShadow(color: Color(0x10111827), blurRadius: 20, offset: Offset(0, 8)),
  ];

  // ── Semantic colors ────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color successSoft = Color(0xFFE8F8EF);
  static const Color warningSoft = Color(0xFFFFF7E6);

  // ── Gradient helpers ───────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [hero900, hero700, hero500],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient balanceGradient = LinearGradient(
    colors: [Color(0xFF052E16), Color(0xFF064E2B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
