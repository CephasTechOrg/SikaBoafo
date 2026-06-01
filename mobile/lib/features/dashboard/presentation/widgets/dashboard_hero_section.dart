import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_api.dart';
import 'dashboard_header.dart';
import 'dashboard_hero_backdrop.dart';
import 'dashboard_mockup_ui.dart';

/// Hero tall area: dark-green backdrop + all header content.
/// Height is driven by content; backdrop fills it via Positioned.fill.
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
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(child: DashboardHeroBackdrop()),
        Padding(
          padding: EdgeInsets.only(
            top: topInset + 8,
            bottom: DashboardMockup.sheetOverlap + 36,
          ),
          child: DashboardHeader(
            mc: mc,
            summaryAsync: summaryAsync,
            onNavigate: onNavigate,
          ),
        ),
      ],
    );
  }
}
