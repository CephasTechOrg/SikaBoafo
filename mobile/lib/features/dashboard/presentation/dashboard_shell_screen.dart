import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_screen.dart';
import '../providers/dashboard_providers.dart';
import 'more_screen.dart';
import 'widgets/dashboard_hero_section.dart';
import 'widgets/dashboard_kpi_strip.dart';
import 'widgets/dashboard_top_selling_section.dart';
import 'widgets/dashboard_recent_activity.dart';
import 'widgets/dashboard_mockup_ui.dart';
import 'widgets/dashboard_mockup_nav_bar.dart';

class DashboardShellScreen extends ConsumerStatefulWidget {
  const DashboardShellScreen({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  ConsumerState<DashboardShellScreen> createState() =>
      _DashboardShellScreenState();
}

class _DashboardShellScreenState extends ConsumerState<DashboardShellScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 3);
  }

  Future<void> _signOut() async {
    await ref.read(sessionServiceProvider).signOut();
    if (!mounted) return;
    context.go(AppRoute.auth.path);
  }

  void _onTabSelected(int v) {
    if (v == 0 && _index != 0) {
      ref.read(dashboardApiProvider).clearDashboardCache();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(dashboardRecentActivityProvider);
      ref.invalidate(dashboardInsightsProvider);
      ref.invalidate(localDashboardOverlayProvider);
    }
    setState(() => _index = v);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeDashboard(
        onSignOut: _signOut,
        onNavigate: _onTabSelected,
      ),
      const SalesScreen(),
      const InventoryScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: DashboardMockupNavBar(
        selectedIndex: _index,
        onSelected: _onTabSelected,
      ),
    );
  }
}

/// Mockup `Screen` + `screen__scroll` + `sheet` — one scroll, hero then overlapping content.
class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.onSignOut, required this.onNavigate});

  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(dashboardApiProvider).clearDashboardCache();
    ref.invalidate(merchantContextProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardRecentActivityProvider);
    ref.invalidate(dashboardInsightsProvider);
    ref.invalidate(localDashboardOverlayProvider);
    await Future.wait([
      ref.read(merchantContextProvider.future),
      ref.read(dashboardSummaryProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);
    final insightsAsync = ref.watch(dashboardInsightsProvider);
    final overlayAsync = ref.watch(localDashboardOverlayProvider);

    return ColoredBox(
      color: DashboardMockup.bg,
      child: ctxAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DashboardMockup.green600),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(userFriendlyError(e), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () {
                    ref.invalidate(merchantContextProvider);
                    ref.invalidate(dashboardSummaryProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (mc) => RefreshIndicator(
          color: DashboardMockup.green600,
          backgroundColor: AppColors.surface,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: DashboardHeroSection(
                  mc: mc,
                  summaryAsync: summaryAsync,
                  onNavigate: onNavigate,
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -DashboardMockup.sheetOverlap),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: DashboardMockup.bg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(DashboardMockup.sheetRadius),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DashboardMockup.gutter,
                        22,
                        DashboardMockup.gutter,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DashboardKpiStrip(
                            summaryAsync: summaryAsync,
                            overlayAsync: overlayAsync,
                            onNavigate: onNavigate,
                          ),
                          const SizedBox(height: 26),
                          DashboardTopSellingSection(
                            insightsAsync: insightsAsync,
                            overlayAsync: overlayAsync,
                            onNavigate: onNavigate,
                          ),
                          const SizedBox(height: 24),
                          DashboardRecentActivity(
                            activityAsync: activityAsync,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
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
