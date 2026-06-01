import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../../notifications/providers/notifications_inbox_providers.dart';
import '../../../sales/presentation/utils/sales_ui_utils.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';
import '../utils/dashboard_ui_utils.dart';
import 'dashboard_mockup_ui.dart';
import 'dashboard_quick_actions.dart';

/// Full hero content: top bar → sales section → quick actions.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.mc,
    required this.summaryAsync,
    required this.onNavigate,
  });

  final MerchantContext mc;
  final AsyncValue<DashboardSummary> summaryAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary     = summaryAsync.valueOrNull;
    final overlayAsync = ref.watch(localDashboardOverlayProvider);
    final overlay     = overlayAsync.valueOrNull;

    // ── Sales total (with offline overlay) ──────────────────────────────────
    final rawSales      = summary?.todaySalesTotal ?? '--';
    final overlayMinor  = overlay?.todayPendingSalesMinor ?? 0;
    final overlayText   =
        overlayMinor > 0 ? SalesUiUtils.minorToMoney(overlayMinor) : null;
    final displaySales  = overlayText == null
        ? rawSales
        : DashboardUiUtils.addMoneyStrings(rawSales, overlayText);

    // ── Trend badge ──────────────────────────────────────────────────────────
    final trend = summary != null
        ? DashboardUiUtils.trendBadge(displaySales, summary.yesterdaySalesTotal)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DashboardMockup.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Row(
            children: [
              _BusinessAvatar(name: mc.businessName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DashboardUiUtils.greeting(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.66),
                        height: 1.2,
                      ),
                    ),
                    Text(
                      mc.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const _SyncStatusButton(),
              const SizedBox(width: 8),
              const _NotificationButton(),
            ],
          ),

          const SizedBox(height: 16),

          // ── Sales label ───────────────────────────────────────────────────
          const DashSecLabel('Sales Today', onDark: true),
          const SizedBox(height: 4),

          // ── Sales amount ──────────────────────────────────────────────────
          Text(
            '₵$displaySales',
            style: DSText.heroAmount(),
          ),

          // ── Offline indicator ─────────────────────────────────────────────
          if (overlayText != null) ...[
            const SizedBox(height: 6),
            Text(
              'Includes ₵$overlayText offline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],

          // ── Trend badge ───────────────────────────────────────────────────
          if (trend != null) ...[
            const SizedBox(height: 8),
            _TrendBadge(trend: trend),
          ],

          const SizedBox(height: 16),

          // ── Quick actions ─────────────────────────────────────────────────
          DashboardHeroQuickActions(onNavigate: onNavigate),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Business avatar ──────────────────────────────────────────────────────────

class _BusinessAvatar extends StatelessWidget {
  const _BusinessAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        DashboardUiUtils.initials(name),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

// ── Trend badge pill ─────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});

  final String trend;

  @override
  Widget build(BuildContext context) {
    final isUp = !trend.startsWith('-');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: const Color(0xFF7CE0B0),
          ),
          const SizedBox(width: 6),
          Text(
            trend,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFCFEFDD),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification bell button ─────────────────────────────────────────────────

class _NotificationButton extends ConsumerWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountLiveProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () => context.push(AppRoute.notifications.path),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: DashboardMockup.danger,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFF0A4632),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Sync status button ────────────────────────────────────────────────────────

/// Shows a rotating sync icon while the queue is active, an amber dot when
/// items are pending, and a red dot when failures exist.
/// Fades to 40 % when everything is idle so the header stays clean.
class _SyncStatusButton extends ConsumerStatefulWidget {
  const _SyncStatusButton();

  @override
  ConsumerState<_SyncStatusButton> createState() => _SyncStatusButtonState();
}

class _SyncStatusButtonState extends ConsumerState<_SyncStatusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(syncStatusControllerProvider);
    final sync = syncAsync.valueOrNull;

    final isSyncing  = sync?.isSyncing  ?? false;
    final hasPending = sync?.hasPendingWork ?? false;
    final hasErrors  = sync?.hasFailures ?? false;

    // Drive the spin animation
    if (isSyncing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!isSyncing && _spin.isAnimating) {
      _spin.stop();
      _spin.reset();
    }

    // Badge colour: red for errors, amber for pending, none when idle
    final Color? badgeColor = hasErrors
        ? DashboardMockup.danger
        : hasPending
            ? DashboardMockup.warn
            : null;

    final double iconOpacity =
        (isSyncing || hasPending || hasErrors) ? 1.0 : 0.40;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () => ref.invalidate(syncStatusControllerProvider),
            borderRadius: BorderRadius.circular(13),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: RotationTransition(
                  turns: _spin,
                  child: Icon(
                    Icons.sync_rounded,
                    color: Colors.white.withValues(alpha: iconOpacity),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (badgeColor != null)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: DashboardMockup.heroGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
