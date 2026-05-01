import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/sales_ui_utils.dart';

class SalesHeader extends StatelessWidget {
  const SalesHeader({
    super.key,
    required this.todayRevenueMinor,
    required this.todayTxnsCount,
    required this.cashTotalMinor,
    required this.momoTotalMinor,
  });

  final int todayRevenueMinor;
  final int todayTxnsCount;
  final int cashTotalMinor;
  final int momoTotalMinor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Background gradient ──────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF041C0B),
                    Color(0xFF083A1A),
                    Color(0xFF0F5A30),
                    Color(0xFF196E3D),
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          ),
          // Subtle radial bloom top-right
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.68, -0.72),
                  radius: 0.92,
                  colors: [
                    const Color(0xFF27A84E).withValues(alpha: 0.40),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Bottom fade for depth
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF010A04).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          // Top highlight line
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.0,
            child: ColoredBox(color: Color(0x18FFFFFF)),
          ),

          // ── Decorative image (subtle) ────────────────────────
          Positioned(
            right: -10,
            bottom: -8,
            child: Opacity(
              opacity: 0.18, // reduced — texture not feature
              child: Image.asset(
                'assets/images/sales.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 18), // Increased top padding manually for sliver
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page title + freshness — clean, no icon box
                  Row(
                    children: [
                      Text(
                        'Sales',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: DataFreshnessLabel(
                          kvKey: KvCacheRepository.kSalesTs,
                          color: AppColors.heroSubtitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Hero figure — left-aligned, not centred
                  Text(
                    "TODAY'S REVENUE",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SalesUiUtils.formatMinor(todayRevenueMinor, symbol: '₵'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Constantia',
                      letterSpacing: -0.8,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Two key stats — clean, spaced out
                  Row(
                    children: [
                      _StatPill(
                        icon: Icons.receipt_long_rounded,
                        value: '$todayTxnsCount',
                        label: 'transactions',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.payments_rounded,
                        value: SalesUiUtils.formatMinor(cashTotalMinor,
                            symbol: '₵'),
                        label: 'cash',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.phone_android_rounded,
                        value: SalesUiUtils.formatMinor(momoTotalMinor,
                            symbol: '₵'),
                        label: 'MoMo',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.55), size: 13),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
