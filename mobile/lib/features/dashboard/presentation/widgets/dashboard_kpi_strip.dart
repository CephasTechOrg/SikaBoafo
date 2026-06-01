import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../data/dashboard_api.dart';
import '../../providers/dashboard_providers.dart';
import 'dashboard_mockup_ui.dart';

class DashboardKpiStrip extends StatelessWidget {
  const DashboardKpiStrip({
    super.key,
    required this.summaryAsync,
    required this.overlayAsync,
    required this.onNavigate,
  });

  final AsyncValue<DashboardSummary> summaryAsync;
  final AsyncValue<LocalDashboardOverlay> overlayAsync;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final debtOutstanding = summary?.debtOutstandingTotal ?? '0.00';
    final lowStock        = summary?.lowStockCount ?? 0;
    final todaySales      = summary?.todaySalesTotal ?? '0.00';
    final todayProfit     = summary?.todayEstimatedProfit ?? '0.00';

    return Column(
      children: [
        // ── Today's estimated profit ─────────────────────────────────────
        _ProfitCard(
          todaySales: todaySales,
          todayProfit: todayProfit,
          onNavigate: onNavigate,
        ),
        const SizedBox(height: 12),

        // ── Debt + Low-stock tiles ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Unpaid Debt',
                value: '₵$debtOutstanding',
                tone: _Tone.danger,
                onTap: (ctx) => ctx.push(AppRoute.debts.path),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.inventory_2_outlined,
                label: 'Low Stock',
                value: lowStock == 0 ? '0' : '$lowStock',
                tone: _Tone.warn,
                onTap: (_) => onNavigate(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Profit card ──────────────────────────────────────────────────────────────

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({
    required this.todaySales,
    required this.todayProfit,
    required this.onNavigate,
  });

  final String todaySales;
  final String todayProfit;
  final ValueChanged<int> onNavigate;

  double _parse(String v) => double.tryParse(v.replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final sales     = _parse(todaySales);
    final profit    = _parse(todayProfit);
    final ratio     = sales > 0 ? (profit / sales).clamp(0.0, 1.0) : 0.0;
    final pct       = (ratio * 100).round();

    return GestureDetector(
      onTap: () => onNavigate(1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F7A4A), Color(0xFF0A5D38)],
          ),
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x470B4A2E),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // SikaBoafo logo watermark
            Positioned(
              right: -8,
              bottom: -8,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/sikaboafo.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S EST. PROFIT",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₵$todayProfit',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    width: 230,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          alignment: Alignment.centerLeft,
                          child: const ColoredBox(color: Color(0xFF7CE0B0)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct% margin on today\'s sales',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small stat tile ──────────────────────────────────────────────────────────

enum _Tone { danger, warn }

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final _Tone tone;
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = tone == _Tone.danger
        ? DashboardMockup.danger
        : DashboardMockup.warn;
    final iconBg = tone == _Tone.danger
        ? DashboardMockup.dangerTint
        : DashboardMockup.warnTint;

    return Container(
      decoration: BoxDecoration(
        color: DashboardMockup.card,
        borderRadius: BorderRadius.circular(DashboardMockup.tileRadius),
        border: Border.all(color: DashboardMockup.lineSoft),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(DashboardMockup.tileRadius),
        child: InkWell(
          onTap: onTap != null ? () => onTap!(context) : null,
          borderRadius: BorderRadius.circular(DashboardMockup.tileRadius),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 9),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.cardValue(size: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.cardLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
