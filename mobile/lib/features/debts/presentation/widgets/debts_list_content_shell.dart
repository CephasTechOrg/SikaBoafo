import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../utils/debts_ui_tokens.dart';

/// Shared list chrome for Debts and Customers — neutral page gray, rounded
/// white stripe under the hero, toolbar band for search + filters, gray list
/// well for cards (no greenDeep bleed behind `RefreshIndicator`).
class DebtsListContentShell extends StatelessWidget {
  const DebtsListContentShell({
    super.key,
    required this.onRefresh,
    required this.staleBanner,
    required this.searchBar,
    required this.tabFilter,
    required this.children,
    this.bottomInset = 110,
    this.horizontalPadding = 18,
    this.staleBannerTopPadding = 8,
  });

  final Future<void> Function() onRefresh;

  /// Usually [StaleBanner].
  final Widget staleBanner;

  final Widget searchBar;

  /// When null, the gap between search bar and cards section is omitted and
  /// toolbar bottom padding shrinks — used on screens with no filter chips.
  final Widget? tabFilter;

  /// Rows below toolbar (labels, tiles, empty state).
  final List<Widget> children;

  final double bottomInset;
  final double horizontalPadding;

  /// Top-padding inside the white rounded surface before the stale banner.
  /// Keep small — the curved sheet should feel close to the hero bottom.
  final double staleBannerTopPadding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: DebtsUi.textMuted,
      backgroundColor: DebtsUi.surface,
      onRefresh: onRefresh,
      child: ColoredBox(
        color: DebtsUi.greenDeep,
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: AppRadii.heroRadius),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset),
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: DebtsUi.surface,
                  borderRadius:
                      BorderRadius.vertical(top: AppRadii.heroRadius),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    staleBannerTopPadding,
                    horizontalPadding,
                    4,
                  ),
                  child: staleBanner,
                ),
              ),
              ColoredBox(
                color: DebtsUi.toolbarBackground,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    tabFilter != null ? 14 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchBar,
                      if (tabFilter != null) ...[
                        const SizedBox(height: 10),
                        tabFilter!,
                      ],
                    ],
                  ),
                ),
              ),
              ColoredBox(
                color: DebtsUi.pageBackground,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    14,
                    horizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
