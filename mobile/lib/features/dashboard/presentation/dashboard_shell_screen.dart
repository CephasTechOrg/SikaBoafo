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
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_kpi_strip.dart';
import 'widgets/dashboard_top_selling_section.dart';
import 'widgets/dashboard_recent_activity.dart';
import 'widgets/dashboard_hero_backdrop.dart';

// ─── Shell ────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeDashboard(
        onSignOut: _signOut,
        onNavigate: (i) => setState(() => _index = i),
      ),
      const SalesScreen(),
      const InventoryScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (v) {
              if (v == 0 && _index != 0) {
                ref.read(dashboardApiProvider).clearDashboardCache();
                ref.invalidate(dashboardSummaryProvider);
                ref.invalidate(dashboardRecentActivityProvider);
                ref.invalidate(dashboardInsightsProvider);
                ref.invalidate(localDashboardOverlayProvider);
              }
              setState(() => _index = v);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded),
                label: 'Sales',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventory',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home tab ────────────────────────────────────────────────

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.onSignOut, required this.onNavigate});

  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;

  void _openSettings(BuildContext ctx) => ctx.push(AppRoute.settings.path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctxAsync = ref.watch(merchantContextProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final activityAsync = ref.watch(dashboardRecentActivityProvider);
    final insightsAsync = ref.watch(dashboardInsightsProvider);
    final overlayAsync = ref.watch(localDashboardOverlayProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final heroHeight = (h * 0.40).clamp(280.0, 360.0);
        const sheetCurveLift = 44.0;

        return Container(
          decoration: const BoxDecoration(color: AppColors.canvas),
          child: ctxAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
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
            data: (mc) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: heroHeight,
                  child: const DashboardHeroBackdrop(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: heroHeight - sheetCurveLift,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.vertical(
                        top: AppRadii.heroRadius,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F0F172A),
                          blurRadius: 28,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: RefreshIndicator(
                        color: AppColors.forest,
                        onRefresh: () async {
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
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
                          children: [
                            const _SectionLabel('Quick Actions'),
                            const SizedBox(height: 12),
                            DashboardQuickActions(onNavigate: onNavigate),
                            const SizedBox(height: 16),
                            DashboardKpiStrip(
                              summaryAsync: summaryAsync,
                              overlayAsync: overlayAsync,
                              onNavigate: onNavigate,
                            ),
                            const SizedBox(height: 18),
                            DashboardTopSellingSection(
                              insightsAsync: insightsAsync,
                              overlayAsync: overlayAsync,
                            ),
                            const SizedBox(height: 18),
                            DashboardRecentActivity(activityAsync: activityAsync),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: heroHeight,
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: DashboardHeader(
                        mc: mc,
                        summaryAsync: summaryAsync,
                        onSettings: () => _openSettings(context),
                        onNavigate: onNavigate,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -0.2,
      ),
    );
  }
}
