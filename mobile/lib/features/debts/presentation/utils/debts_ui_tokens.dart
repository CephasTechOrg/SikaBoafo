import 'package:flutter/material.dart';

/// Local design tokens for the Debts/Receivables feature.
/// Use these instead of scattering raw hex values across widgets.
abstract final class DebtTokens {
  // ── Hero gradient ──────────────────────────────────────────────────────────
  static const Color hero900 = Color(0xFF03170A); // darkest — top-left
  static const Color hero700 = Color(0xFF064E2B); // mid green
  static const Color hero500 = Color(0xFF178A4B); // accent — bottom-right

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double sheetTopRadius = 32;
  static const double balanceCardRadius = 28;
  static const double panelRadius = 22;
  static const double debtCardRadius = 20;
  static const double metricTileRadius = 16;
  static const double buttonRadius = 16;
  static const double pillRadius = 999;

  // ── Shadows ────────────────────────────────────────────────────────────────
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x0A111827), blurRadius: 10, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x07111827), blurRadius: 6, offset: Offset(0, 1)),
  ];

  // ── Danger (pure red — overdue / destructive only) ─────────────────────────
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFFB91C1C);

  // ── Hero gradient helpers ──────────────────────────────────────────────────
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
