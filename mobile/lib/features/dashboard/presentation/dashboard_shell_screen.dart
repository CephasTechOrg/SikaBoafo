import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/sync_providers.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../data/dashboard_api.dart';
import '../providers/dashboard_providers.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../sales/presentation/sales_screen.dart';
import 'more_screen.dart';

// ─── Shell ────────────────────────────────────────────────────────────────────

class DashboardShellScreen extends ConsumerStatefulWidget {
  const DashboardShellScreen({super.key});

  @override
  ConsumerState<DashboardShellScreen> createState() =>
      _DashboardShellScreenState();
}

class _DashboardShellScreenState extends ConsumerState<DashboardShellScreen> {
  int _index = 0;

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
            onDestinationSelected: (v) => setState(() => _index = v),
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

// ─── Home tab ─────────────────────────────────────────────────────────────────

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
        const quickTileHeight = 72.0;
        // How far the curved top of the white sheet pulls up into the hero
        // so the rounded corners are clearly visible against the green/swirl.
        const sheetCurveLift = 28.0;
        // Cards should straddle the new (lifted) flat top of the sheet —
        // ~50% on green / ~50% on white.
        const quickOverlap = quickTileHeight * 0.48 + sheetCurveLift;

        return Container(
          decoration: const BoxDecoration(color: AppColors.canvas),
          child: ctxAsync.when(
            loading: () => const _DashboardLoading(),
            error: (e, _) => _ErrorView(
              message: humanizeDashboardError(e),
              onRetry: () {
                ref.invalidate(merchantContextProvider);
                ref.invalidate(dashboardSummaryProvider);
                ref.invalidate(dashboardRecentActivityProvider);
                ref.invalidate(dashboardInsightsProvider);
              },
            ),
            data: (mc) => Stack(
              children: [
                // Hero background (matches mockup)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: heroHeight,
                  child: const HeroBackdrop(),
                ),

                // White sheet — pulled slightly up into the hero so the
                // rounded top corners are visible against the green/swirl,
                // matching the dashboard mockup's curved transition.
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
                          ref.invalidate(merchantContextProvider);
                          ref.invalidate(dashboardSummaryProvider);
                          ref.invalidate(dashboardRecentActivityProvider);
                          ref.invalidate(dashboardInsightsProvider);
                          await Future.wait([
                            ref.read(merchantContextProvider.future),
                            ref.read(dashboardSummaryProvider.future),
                            ref.read(dashboardRecentActivityProvider.future),
                            ref.read(dashboardInsightsProvider.future),
                          ]);
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          // Leave room for the portion of the cards that
                          // overhangs into the white sheet (cards sit
                          // `quickOverlap` above the original seam, so the
                          // amount poking into the sheet is the rest of the
                          // card height, plus the lift we applied above).
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            (quickTileHeight - quickOverlap) +
                                sheetCurveLift +
                                24,
                            20,
                            40,
                          ),
                          children: [
                            _KpiStrip(
                              summaryAsync: summaryAsync,
                              overlayAsync: overlayAsync,
                              onNavigate: onNavigate,
                            ),
                            const SizedBox(height: 22),
                            _PaymentBreakdownStrip(
                              insightsAsync: insightsAsync,
                              overlayAsync: overlayAsync,
                            ),
                            const SizedBox(height: 22),
                            _TopSellingSection(
                              insightsAsync: insightsAsync,
                              overlayAsync: overlayAsync,
                            ),
                            const SizedBox(height: 22),
                            _RecentActivity(activityAsync: activityAsync),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Hero content (safe-area)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: heroHeight,
                  child: SafeArea(
                    bottom: false,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _Header(
                        mc: mc,
                        summaryAsync: summaryAsync,
                        onSettings: () => _openSettings(context),
                        onNavigate: onNavigate,
                      ),
                    ),
                  ),
                ),

                // Quick actions: straddle the hero / white-sheet seam.
                // The seam is at `heroHeight`; we lift the cards up by
                // `quickOverlap` so the top portion overlaps the hero and the
                // remainder sits on top of the white sheet.
                Positioned(
                  left: 20,
                  right: 20,
                  top: heroHeight - quickOverlap,
                  height: quickTileHeight,
                  child: _QuickActions(onNavigate: onNavigate),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({
    required this.mc,
    required this.summaryAsync,
    required this.onSettings,
    required this.onNavigate,
  });

  final MerchantContext mc;
  final AsyncValue<DashboardSummary> summaryAsync;
  final VoidCallback onSettings;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = summaryAsync.valueOrNull;
    final sales = summary?.todaySalesTotal ?? '--';
    final overlayAsync = ref.watch(localDashboardOverlayProvider);
    final overlay = overlayAsync.valueOrNull;
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final syncSnapshot = syncAsync.valueOrNull;
    final syncing = syncSnapshot?.isSyncing ?? syncAsync.isLoading;
    final overlayMinor = overlay?.todayPendingSalesMinor ?? 0;
    final overlayText = overlayMinor > 0 ? minorToMoney(overlayMinor) : null;
    // Note: we currently only overlay sales in the header headline.
    final displaySales =
        overlayText == null ? sales : _addMoneyStrings(sales, overlayText);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'SikaBoafo',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (syncSnapshot != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: _SyncPill(snapshot: syncSnapshot)),
                    ],
                  ],
                ),
              ),
              _HeaderBtn(
                icon: syncing ? Icons.sync_rounded : Icons.cloud_sync_outlined,
                onTap: () async {
                  final controller =
                      ref.read(syncStatusControllerProvider.notifier);
                  await controller.syncNow();
                  if (!context.mounted) return;
                  final latest =
                      ref.read(syncStatusControllerProvider).valueOrNull;
                  final reachable = latest?.backendReachable ?? false;
                  final failed = latest?.stats.failedCount ?? 0;
                  final pending = latest == null
                      ? 0
                      : latest.stats.pendingCount + latest.stats.sendingCount;

                  final message = !reachable
                      ? 'Offline — will sync when back online.'
                      : failed > 0
                          ? 'Sync completed with $failed failed item${failed == 1 ? '' : 's'}.'
                          : pending > 0
                              ? 'Sync in progress — $pending pending.'
                              : 'All synced.';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _HeaderBtn(
                icon: Icons.notifications_outlined,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications coming soon'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'SALES TODAY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '\u20B5$displaySales',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              fontFamily: 'Constantia',
              letterSpacing: -0.8,
              height: 1,
            ),
          ),
          if (overlayText != null) ...[
            const SizedBox(height: 8),
            Text(
              'Includes \u20B5$overlayText offline',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 6),
                Text(
                  '+12% from yesterday',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _addMoneyStrings(String a, String b) {
  final ma = _moneyToMinorSafe(a);
  final mb = _moneyToMinorSafe(b);
  return minorToMoney(ma + mb);
}

int _moneyToMinorSafe(String value) {
  final raw = value.trim();
  final match = RegExp(r'^-?\d+(\.\d{1,2})?$').firstMatch(raw);
  if (match == null) return 0;
  final negative = raw.startsWith('-');
  final normalized = negative ? raw.substring(1) : raw;
  final parts = normalized.split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final minor = int.tryParse(decimal) ?? 0;
  final total = (major * 100) + minor;
  return negative ? -total : total;
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.18),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// Compact pill that surfaces the most relevant sync state next to the brand.
/// Hidden when everything is healthy (online + nothing pending) to avoid noise.
class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.snapshot});
  final SyncStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final descriptor = _resolve(snapshot);
    if (descriptor == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: descriptor.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: descriptor.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (descriptor.spinner)
            const SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            Icon(descriptor.icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              descriptor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _SyncPillDescriptor? _resolve(SyncStatusSnapshot s) {
    if (s.isSyncing) {
      return _SyncPillDescriptor(
        label: 'Syncing…',
        icon: Icons.sync_rounded,
        spinner: true,
        background: Colors.white.withValues(alpha: 0.18),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (!s.backendReachable) {
      return _SyncPillDescriptor(
        label: 'Offline',
        icon: Icons.cloud_off_rounded,
        spinner: false,
        background: const Color(0xFFB54848).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (s.hasFailures || s.hasConflicts) {
      final count = s.stats.failedCount + s.stats.conflictCount;
      return _SyncPillDescriptor(
        label: 'Failed: $count',
        icon: Icons.error_outline_rounded,
        spinner: false,
        background: const Color(0xFFB54848).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    if (s.hasPendingWork) {
      final count = s.stats.pendingCount + s.stats.sendingCount;
      return _SyncPillDescriptor(
        label: 'Pending: $count',
        icon: Icons.cloud_upload_outlined,
        spinner: false,
        background: const Color(0xFFC68A2E).withValues(alpha: 0.85),
        border: Colors.white.withValues(alpha: 0.22),
      );
    }
    return null;
  }
}

class _SyncPillDescriptor {
  const _SyncPillDescriptor({
    required this.label,
    required this.icon,
    required this.spinner,
    required this.background,
    required this.border,
  });
  final String label;
  final IconData icon;
  final bool spinner;
  final Color background;
  final Color border;
}

// ─── Skeleton placeholders ────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E9EE),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _SkeletonChip extends StatelessWidget {
  const _SkeletonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SkeletonBox(width: 32, height: 32, borderRadius: 10),
          SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(width: 70, height: 9),
              SizedBox(height: 6),
              _SkeletonBox(width: 56, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonTopSellingRow extends StatelessWidget {
  const _SkeletonTopSellingRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _SkeletonBox(width: 32, height: 32, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 140, height: 11),
                SizedBox(height: 6),
                _SkeletonBox(width: 80, height: 9),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 64, height: 14),
        ],
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickTile(
            icon: Icons.shopping_cart_rounded,
            label: 'New Sale',
            backgroundColor: AppColors.navy,
            accentColor: AppColors.navySoft,
            foregroundColor: Colors.white,
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.payments_rounded,
            label: 'Collect Debt',
            backgroundColor: AppColors.forestDark,
            accentColor: AppColors.forest,
            foregroundColor: Colors.white,
            onTap: () => context.push(AppRoute.debts.path),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickTile(
            icon: Icons.inventory_2_rounded,
            label: 'Stock',
            backgroundColor: AppColors.forestNight,
            accentColor: AppColors.navySoft,
            foregroundColor: Colors.white,
            onTap: () => onNavigate(2),
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.accentColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color accentColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [accentColor, backgroundColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: foregroundColor, size: 16),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: foregroundColor,
                    height: 1.05,
                    letterSpacing: -0.1,
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

// ─── Business Insight Banner ──────────────────────────────────────────────────

// ─── KPI Strip ────────────────────────────────────────────────────────────────

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.summaryAsync,
    required this.overlayAsync,
    required this.onNavigate,
  });

  final AsyncValue<DashboardSummary> summaryAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = summaryAsync.valueOrNull;
    final isLoading = summaryAsync.isLoading && s == null;
    final overlay = overlayAsync.valueOrNull;
    final pendingProfitMinor = (overlay?.todayPendingSalesMinor ?? 0) -
        (overlay?.todayPendingExpensesMinor ?? 0);
    final pendingProfit =
        pendingProfitMinor == 0 ? null : minorToMoney(pendingProfitMinor);
    final profitDisplay = pendingProfit == null
        ? (s?.todayEstimatedProfit ?? '0.00')
        : _addMoneyStrings(s?.todayEstimatedProfit ?? '0.00', pendingProfit);

    final debtDisplayMinor = overlay?.debtOutstandingMinorLocal;
    final debtDisplay = debtDisplayMinor == null
        ? (s?.debtOutstandingTotal ?? '0.00')
        : minorToMoney(debtDisplayMinor);

    final lowStock = overlay?.lowStockCountLocal ?? s?.lowStockCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            label: "Today's Profit",
            value: isLoading ? '—' : '\u20B5$profitDisplay',
            icon: Icons.trending_up_rounded,
            tone: AppColors.forest,
            toneSoft: AppColors.successSoft,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            label: 'Outstanding',
            value: isLoading ? '—' : '\u20B5$debtDisplay',
            icon: Icons.account_balance_wallet_rounded,
            tone: AppColors.navySoft,
            toneSoft: AppColors.infoSoft,
            onTap: () => context.push(AppRoute.debts.path),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            label: 'Low Stock',
            value:
                isLoading ? '—' : '$lowStock item${lowStock == 1 ? '' : 's'}',
            icon: Icons.error_outline_rounded,
            tone: AppColors.danger,
            toneSoft: AppColors.dangerSoft,
            onTap: () => onNavigate(2),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.toneSoft,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final Color toneSoft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            gradient: LinearGradient(
              colors: [
                AppColors.surface,
                toneSoft.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: tone.withValues(alpha: 0.12)),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: tone),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── This Month Overview ──────────────────────────────────────────────────────

// ignore: unused_element
class _MonthOverviewCard extends StatelessWidget {
  const _MonthOverviewCard(
      {required this.insightsAsync, required this.overlayAsync});

  final AsyncValue<DashboardInsights> insightsAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;

  @override
  Widget build(BuildContext context) {
    final data = insightsAsync.valueOrNull;
    final month = data?.month;
    final overlay = overlayAsync.valueOrNull;
    final addSales = overlay?.monthPendingSalesMinor ?? 0;
    final addExpenses = overlay?.monthPendingExpensesMinor ?? 0;
    final addProfit = addSales - addExpenses;
    final salesText =
        _addMoneyStrings(month?.salesTotal ?? '0.00', minorToMoney(addSales));
    final expensesText = _addMoneyStrings(
        month?.expensesTotal ?? '0.00', minorToMoney(addExpenses));
    final profitText = _addMoneyStrings(
        month?.estimatedProfit ?? '0.00', minorToMoney(addProfit));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('This Month'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyMuted],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: const Icon(Icons.insights_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Performance',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Text(
                          'Month-to-date snapshot',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MonthStat(
                      label: 'Sales',
                      value: '\u20B5$salesText',
                      tone: const Color(0xFF8BE0B2),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  Expanded(
                    child: _MonthStat(
                      label: 'Expenses',
                      value: '\u20B5$expensesText',
                      tone: const Color(0xFFF6A6A6),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  Expanded(
                    child: _MonthStat(
                      label: 'Profit',
                      value: '\u20B5$profitText',
                      tone: const Color(0xFFFFD37A),
                    ),
                  ),
                ],
              ),
              if (addSales != 0 || addExpenses != 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Includes offline entries not yet synced.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tone,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Breakdown Strip ──────────────────────────────────────────────────

class _PaymentBreakdownStrip extends StatelessWidget {
  const _PaymentBreakdownStrip({
    required this.insightsAsync,
    required this.overlayAsync,
  });

  final AsyncValue<DashboardInsights> insightsAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;

  @override
  Widget build(BuildContext context) {
    final data = insightsAsync.valueOrNull;
    final rows = data?.monthlyPaymentBreakdown ?? const [];
    final overlay = overlayAsync.valueOrNull;
    final pendingByMethod =
        overlay?.monthPendingPaymentMinorByMethod ?? const {};
    final merged = _mergePaymentBreakdown(rows, pendingByMethod);
    if (insightsAsync.isLoading && rows.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Payment Methods'),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SkeletonChip(),
                SizedBox(width: 10),
                _SkeletonChip(),
                SizedBox(width: 10),
                _SkeletonChip(),
              ],
            ),
          ),
        ],
      );
    }
    if (merged.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Payment Methods'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No payments recorded yet this month.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Payment Methods'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < merged.length; i++) ...[
                _PaymentChip(row: merged[i]),
                if (i != merged.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

List<DashboardPaymentBreakdown> _mergePaymentBreakdown(
  List<DashboardPaymentBreakdown> server,
  Map<String, int> pendingMinorByMethod,
) {
  final byLabel = <String, DashboardPaymentBreakdown>{
    for (final r in server) r.paymentMethodLabel: r,
  };

  for (final entry in pendingMinorByMethod.entries) {
    final label = entry.key;
    final minor = entry.value;
    if (minor == 0) continue;
    final existing = byLabel[label];
    if (existing == null) {
      byLabel[label] = DashboardPaymentBreakdown(
        paymentMethodLabel: label,
        paymentMethodDisplay: _displayMethod(label),
        totalAmount: minorToMoney(minor),
        saleCount: 0,
      );
      continue;
    }
    final mergedMinor = _moneyToMinorSafe(existing.totalAmount) + minor;
    byLabel[label] = DashboardPaymentBreakdown(
      paymentMethodLabel: existing.paymentMethodLabel,
      paymentMethodDisplay: existing.paymentMethodDisplay,
      totalAmount: minorToMoney(mergedMinor),
      saleCount: existing.saleCount,
    );
  }

  final list = byLabel.values.toList(growable: false);
  list.sort((a, b) => _moneyToMinorSafe(b.totalAmount)
      .compareTo(_moneyToMinorSafe(a.totalAmount)));
  return list;
}

String _displayMethod(String label) {
  switch (label) {
    case 'cash':
      return 'Cash';
    case 'mobile_money':
      return 'Mobile money';
    case 'bank_transfer':
      return 'Bank transfer';
    case 'bank':
      return 'Bank';
    case 'card':
      return 'Card';
    default:
      return label.replaceAll('_', ' ');
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.row});

  final DashboardPaymentBreakdown row;

  IconData get _icon {
    switch (row.paymentMethodLabel) {
      case 'cash':
        return Icons.payments_rounded;
      case 'mobile_money':
        return Icons.phone_iphone_rounded;
      case 'card':
        return Icons.credit_card_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  Color get _tone {
    switch (row.paymentMethodLabel) {
      case 'cash':
        return AppColors.forest;
      case 'mobile_money':
        return AppColors.navy;
      case 'card':
        return AppColors.gold;
      case 'bank':
        return AppColors.info;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _tone, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.paymentMethodDisplay,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\u20B5${row.totalAmount}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Top Selling Items ────────────────────────────────────────────────────────

class _TopSellingSection extends StatelessWidget {
  const _TopSellingSection({
    required this.insightsAsync,
    required this.overlayAsync,
  });

  final AsyncValue<DashboardInsights> insightsAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;

  @override
  Widget build(BuildContext context) {
    final data = insightsAsync.valueOrNull;
    final rows = data?.monthlyTopSellingItems ?? const [];
    final overlay = overlayAsync.valueOrNull;
    final pending = overlay?.monthPendingTopSelling ?? const [];
    final merged = _mergeTopSelling(rows, pending, limit: 8);
    if (insightsAsync.isLoading && rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Top Selling This Month'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: const Column(
              children: [
                _SkeletonTopSellingRow(),
                Divider(height: 1, thickness: 1, color: AppColors.border),
                _SkeletonTopSellingRow(),
                Divider(height: 1, thickness: 1, color: AppColors.border),
                _SkeletonTopSellingRow(),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Top Selling This Month')),
            if (merged.isNotEmpty)
              Text(
                '${merged.length} item${merged.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (merged.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'No sales yet this month — start a sale to see your bestsellers here.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                for (var i = 0; i < merged.length; i++) ...[
                  if (i != 0)
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.border),
                  _TopSellingRow(rank: i + 1, row: merged[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

List<DashboardTopSellingItem> _mergeTopSelling(
    List<DashboardTopSellingItem> server,
    List<LocalTopSellingOverlayRow> pending,
    {int limit = 8}) {
  final byId = <String, _TopAgg>{};
  for (final r in server) {
    byId[r.itemId] = _TopAgg(
      itemId: r.itemId,
      itemName: r.itemName,
      qty: r.quantitySold,
      totalMinor: _moneyToMinorSafe(r.salesTotal),
    );
  }
  for (final p in pending) {
    final existing = byId[p.itemId];
    if (existing == null) {
      byId[p.itemId] = _TopAgg(
        itemId: p.itemId,
        itemName: p.itemName,
        qty: p.quantitySold,
        totalMinor: p.salesTotalMinor,
      );
    } else {
      byId[p.itemId] = existing.copyWith(
        qty: existing.qty + p.quantitySold,
        totalMinor: existing.totalMinor + p.salesTotalMinor,
      );
    }
  }

  final list = byId.values.toList(growable: false);
  list.sort((a, b) {
    final byQty = b.qty.compareTo(a.qty);
    if (byQty != 0) return byQty;
    return b.totalMinor.compareTo(a.totalMinor);
  });

  return list
      .take(limit)
      .map(
        (a) => DashboardTopSellingItem(
          itemId: a.itemId,
          itemName: a.itemName,
          quantitySold: a.qty,
          salesTotal: minorToMoney(a.totalMinor),
        ),
      )
      .toList(growable: false);
}

class _TopAgg {
  const _TopAgg({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.totalMinor,
  });
  final String itemId;
  final String itemName;
  final int qty;
  final int totalMinor;

  _TopAgg copyWith({int? qty, int? totalMinor}) => _TopAgg(
        itemId: itemId,
        itemName: itemName,
        qty: qty ?? this.qty,
        totalMinor: totalMinor ?? this.totalMinor,
      );
}

class _TopSellingRow extends StatelessWidget {
  const _TopSellingRow({required this.rank, required this.row});

  final int rank;
  final DashboardTopSellingItem row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${row.quantitySold} sold',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '\u20B5${row.salesTotal}',
            style: const TextStyle(
              color: AppColors.forest,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.activityAsync});
  final AsyncValue<List<DashboardActivity>> activityAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = activityAsync.valueOrNull ?? const <DashboardActivity>[];
    final pending = ref.watch(localPendingActivityProvider).valueOrNull ??
        const <LocalPendingActivityRow>[];
    final inventory = ref.watch(inventoryControllerProvider).valueOrNull ?? [];
    // Build a lookup: itemId → imageAsset
    final imageByItemId = <String, String?>{
      for (final item in inventory)
        if (item.imageAsset != null) item.id: item.imageAsset,
    };

    final mergedRows = <DashboardActivity>[
      for (final p in pending)
        DashboardActivity(
          activityType: p.activityType,
          title: p.title,
          detail: p.detail,
          amount: p.amount,
          createdAt: p.createdAt,
          itemId: p.itemId,
          itemName: p.itemName,
        ),
      ...rows,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Recent Activity')),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Activity list coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
              child: Text(
                'VIEW ALL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activityAsync.isLoading && rows.isEmpty && pending.isEmpty)
          _ActivitySkeleton()
        else if (mergedRows.isEmpty)
          _ActivityEmpty()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.card,
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: mergedRows.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, thickness: 1, color: AppColors.border),
              itemBuilder: (_, i) => _ActivityRow(
                data: mergedRows[i],
                imageAsset: mergedRows[i].itemId != null
                    ? imageByItemId[mergedRows[i].itemId]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data, this.imageAsset});
  final DashboardActivity data;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final v = _visual(data.activityType);
    final timeStr = _relativeTime(data.createdAt);
    final isIncome =
        data.activityType == 'sale' || data.activityType == 'repayment';
    final amountStr = '${isIncome ? '+' : '−'}\u20B5${data.amount}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Left: product image or type icon
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: imageAsset != null
                ? Image.asset(
                    imageAsset!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: v.color.withValues(alpha: 0.10),
                    child: Icon(v.icon, color: v.color, size: 22),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${data.detail}  ·  $timeStr',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: TextStyle(
                  color: isIncome ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: -0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Completed',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedSoft,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _ActivityVisual _visual(String type) => switch (type) {
        'repayment' => const _ActivityVisual(
            icon: Icons.payments_rounded,
            color: AppColors.success,
          ),
        'expense' => const _ActivityVisual(
            icon: Icons.receipt_long_rounded,
            color: AppColors.warning,
          ),
        _ => const _ActivityVisual(
            icon: Icons.shopping_basket_rounded,
            color: AppColors.forest,
          ),
      };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActivityVisual {
  const _ActivityVisual({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}

class _ActivitySkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(
          3,
          (i) => Column(
            children: [
              if (i != 0) const Divider(height: 1, color: AppColors.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _shimmer(44, 44, radius: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _shimmer(120, 13),
                          const SizedBox(height: 6),
                          _shimmer(80, 11),
                        ],
                      ),
                    ),
                    _shimmer(70, 13),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer(double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.muted, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No recent activity yet.\nRecord a sale to get started.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not reach the server',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'If your server is on a free hosting tier, the first request can\n'
              'take 30–60 seconds while it wakes up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.forest,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Loading your dashboard…',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
