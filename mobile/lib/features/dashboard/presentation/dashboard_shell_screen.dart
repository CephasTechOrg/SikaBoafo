import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_screen.dart';
import '../providers/dashboard_providers.dart';
import 'more_screen.dart';
import 'widgets/dashboard_hero_section.dart';
import 'widgets/dashboard_kpi_strip.dart';
import 'widgets/dashboard_mockup_nav_bar.dart';
import 'widgets/dashboard_mockup_ui.dart';
import 'widgets/dashboard_recent_activity.dart';
import 'widgets/dashboard_top_selling_section.dart';

class DashboardShellScreen extends ConsumerStatefulWidget {
  const DashboardShellScreen({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  ConsumerState<DashboardShellScreen> createState() =>
      _DashboardShellScreenState();
}

class _DashboardShellScreenState
    extends ConsumerState<DashboardShellScreen> {
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

  void _onTab(int v) {
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
    // Force light status-bar icons on the dark-green hero.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DashboardMockup.bg,
        body: IndexedStack(
          index: _index,
          children: [
            _HomeDashboard(onSignOut: _signOut, onNavigate: _onTab),
            const SalesScreen(),
            const InventoryScreen(),
            const MoreScreen(),
          ],
        ),
        bottomNavigationBar: DashboardMockupNavBar(
          selectedIndex: _index,
          onSelected: _onTab,
        ),
      ),
    );
  }
}

// ── Home dashboard tab ────────────────────────────────────────────────────────

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({
    required this.onSignOut,
    required this.onNavigate,
  });

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
    final ctxAsync      = ref.watch(merchantContextProvider);
    final summaryAsync  = ref.watch(dashboardSummaryProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);
    final insightsAsync = ref.watch(dashboardInsightsProvider);
    final overlayAsync  = ref.watch(localDashboardOverlayProvider);

    // Hero-green is the scroll-area background so that:
    //  • pulling down to refresh extends the dark-green hero naturally
    //  • the loading skeleton matches the hero colour
    // The loaded scroll uses a gray base so the bottom inset + overscroll
    // bounce stay gray; a green band sits behind the hero so pulling down to
    // refresh still extends the hero green at the top.
    return ctxAsync.when(
      loading: () => const ColoredBox(
        color: DashboardMockup.heroGreen,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
      error: (e, _) => ColoredBox(
        color: DashboardMockup.heroGreen,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                Text(
                  userFriendlyError(e),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                TextButton(
                  onPressed: () {
                    ref.invalidate(merchantContextProvider);
                    ref.invalidate(dashboardSummaryProvider);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (mc) => ColoredBox(
        color: DashboardMockup.bg,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: const ColoredBox(color: DashboardMockup.heroGreen),
            ),
            // Disable the Android stretch/glow overscroll indicator so the
            // hero green doesn't bleed outside its region on pull-to-refresh.
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(overscroll: false),
              child: RefreshIndicator(
              color: DashboardMockup.green600,
              backgroundColor: DashboardMockup.card,
              strokeWidth: 2.5,
              displacement: 52,
              onRefresh: () => _refresh(ref),
              child: CustomScrollView(
                // Clamping (not bouncing) so content never overshoots its
                // bounds — no green/gray gap can be revealed on pull or fling.
                // RefreshIndicator still works; the glow is killed above.
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  // ── Hero ──────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: DashboardHeroSection(
                      mc: mc,
                      summaryAsync: summaryAsync,
                      onNavigate: onNavigate,
                    ),
                  ),

                  // ── Sheet content ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: DashboardMockup.bg,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DashboardMockup.gutter,
                          0,
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
                            const SizedBox(height: 20),
                            DashboardTopSellingSection(
                              insightsAsync: insightsAsync,
                              overlayAsync: overlayAsync,
                              onNavigate: onNavigate,
                            ),
                            const SizedBox(height: 18),
                            DashboardRecentActivity(
                              activityAsync: activityAsync,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ), // ScrollConfiguration
          ],
        ),
      ),
    );
  }
}
