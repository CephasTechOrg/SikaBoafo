import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dashboard_api.dart';
import 'dashboard_header.dart';
import 'dashboard_hero_backdrop.dart';

/// Mockup `Hero tall map` — gradient + header scrolls with the sheet below.
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
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: DashboardHeroBackdrop()),
        Padding(
          padding: EdgeInsets.only(
            top: topInset + 8,
            bottom: 64,
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
