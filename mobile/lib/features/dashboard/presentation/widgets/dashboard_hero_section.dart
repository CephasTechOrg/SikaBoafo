import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_api.dart';
import 'dashboard_header.dart';
import 'dashboard_hero_backdrop.dart';
import 'dashboard_mockup_ui.dart';

/// Hero section + the white rounded "sheet cap" baked into one sliver.
///
/// Rendering the cap here (not via Transform.translate in a separate sliver)
/// prevents Flutter's scroll-viewport clipping from cutting off the rounded
/// corners — which is what caused the "straight line" artefact.
class DashboardHeroSection extends StatelessWidget {
  const DashboardHeroSection({
    super.key,
    required this.mc,
    required this.summaryAsync,
    required this.onNavigate,
  });

  final MerchantContext mc;
  final AsyncValue<DashboardSummary> summaryAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      // hardEdge clips glow-orbs that bleed outside; the cap itself is
      // fully inside the Stack so its corners are not clipped.
      clipBehavior: Clip.hardEdge,
      children: [
        // ── Full-height green backdrop ─────────────────────────────────
        const Positioned.fill(child: DashboardHeroBackdrop()),

        // ── Content column drives the Stack height ─────────────────────
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: topInset + 8),
              child: DashboardHeader(
                mc: mc,
                summaryAsync: summaryAsync,
                onNavigate: onNavigate,
              ),
            ),

            // Short green breathing room between quick-actions and cap
            const SizedBox(height: 12),

            // White rounded cap — the visible "curve" of the sheet
            const _SheetCap(),
          ],
        ),
      ],
    );
  }
}

/// The 28 px white rounded top that creates the sheet overlap illusion.
/// Painted inside the hero so it's never outside the sliver's paint bounds.
class _SheetCap extends StatelessWidget {
  const _SheetCap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: DashboardMockup.sheetRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DashboardMockup.bg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DashboardMockup.sheetRadius),
          ),
        ),
      ),
    );
  }
}
