import 'package:flutter/material.dart';
import 'sales_carousel.dart';

class SalesHeader extends StatelessWidget {
  const SalesHeader({
    super.key,
    required this.businessName,
    required this.todayRevenueMinor,
    required this.todayTxnsCount,
    required this.cashTotalMinor,
    required this.momoTotalMinor,
    this.topSellingItemName,
    this.topSellingQty,
    this.topSellingImageUrl,
  });

  final String businessName;
  final int todayRevenueMinor;
  final int todayTxnsCount;
  final int cashTotalMinor;
  final int momoTotalMinor;
  final String? topSellingItemName;
  final int? topSellingQty;
  final String? topSellingImageUrl;

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
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
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

          // ── Content ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
            child: SalesCarousel(
              businessName: businessName,
              todayRevenueMinor: todayRevenueMinor,
              cashTotalMinor: cashTotalMinor,
              momoTotalMinor: momoTotalMinor,
              todayTxnsCount: todayTxnsCount,
              topSellingItemName: topSellingItemName,
              topSellingQty: topSellingQty,
              topSellingImageUrl: topSellingImageUrl,
            ),
          ),
        ],
      ),
    );
  }
}
