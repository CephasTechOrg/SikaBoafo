import 'package:flutter/material.dart';

/// Shared visual constants for the Debts feature. Matches the cool-neutral
/// palette used by Sales / Inventory / Customers screens (forest-green hero,
/// navy chips, surface cards).
abstract final class DebtsUiTokens {
  static const Color heroDark = Color(0xFF041C0B);
  static const Color heroMid = Color(0xFF083A1A);
  static const Color heroLight = Color(0xFF196E3D);

  /// Pill / tab radii used across debt cards and filters.
  static const double pillRadius = 999;
  static const double cardRadius = 18;
  static const double tileRadius = 18;

  static const Duration tabSwitchAnimation = Duration(milliseconds: 180);
}
