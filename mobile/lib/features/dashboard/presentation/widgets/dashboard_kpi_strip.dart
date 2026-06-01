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
            // Coins icon watermark (exact SVG paths from the mockup's icons.jsx)
            Positioned(
              right: -10,
              bottom: -16,
              child: Opacity(
                opacity: 0.90,
                child: CustomPaint(
                  size: const Size(108, 108),
                  painter: _CoinsIconPainter(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
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
                    fontSize: 13,
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

// ── Coins icon (exact SVG paths from mockup icons.jsx) ──────────────────────
//
// SVG viewBox 0 0 24 24, fill=none, stroke=color, strokeWidth=1.8,
// strokeLinecap=round, strokeJoin=round.
//
//   ellipse cx=9 cy=6 rx=6 ry=2.6
//   M3 6v5c0 1.4 2.7 2.6 6 2.6s6-1.2 6-2.6V6
//   M3 11v5c0 1.4 2.7 2.6 6 2.6 1 0 2-.1 2.8-.3
//   ellipse cx=16.5 cy=14 rx=5 ry=2.3
//   M11.5 14v4c0 1.2 2.2 2.2 5 2.2s5-1 5-2.2v-4

class _CoinsIconPainter extends CustomPainter {
  const _CoinsIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Ellipse 1 — top of first coin stack
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(9, 6), width: 12, height: 5.2),
      paint,
    );

    // Body of first coin stack (partial cylinder — middle section)
    canvas.drawPath(
      Path()
        ..moveTo(3, 6)
        ..lineTo(3, 11)
        // c0 1.4 2.7 2.6 6 2.6
        ..cubicTo(3, 12.4, 5.7, 13.6, 9, 13.6)
        // s6 -1.2 6 -2.6  (smooth cubic — reflected cp1 = (12.3, 13.6))
        ..cubicTo(12.3, 13.6, 15, 12.4, 15, 11)
        // V6
        ..lineTo(15, 6),
      paint,
    );

    // Bottom of first coin stack
    canvas.drawPath(
      Path()
        ..moveTo(3, 11)
        ..lineTo(3, 16)
        // c0 1.4 2.7 2.6 6 2.6
        ..cubicTo(3, 17.4, 5.7, 18.6, 9, 18.6)
        // 1 0 2 -.1 2.8 -.3  (second triplet of same 'c' command)
        ..cubicTo(10, 18.6, 11, 18.5, 11.8, 18.3),
      paint,
    );

    // Ellipse 2 — top of second coin stack
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(16.5, 14), width: 10, height: 4.6),
      paint,
    );

    // Body of second coin stack
    canvas.drawPath(
      Path()
        ..moveTo(11.5, 14)
        ..lineTo(11.5, 18)
        // c0 1.2 2.2 2.2 5 2.2
        ..cubicTo(11.5, 19.2, 13.7, 20.2, 16.5, 20.2)
        // s5 -1 5 -2.2  (smooth cubic — reflected cp1 = (19.3, 20.2))
        ..cubicTo(19.3, 20.2, 21.5, 19.2, 21.5, 18)
        // v-4
        ..lineTo(21.5, 14),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoinsIconPainter old) =>
      old.color != color;
}

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
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(height: 7),
                // FittedBox shrinks the value on very narrow screens
                // so long amounts (e.g. ₵1,250.00) never overflow
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: DSText.cardValue(size: 17),
                  ),
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
