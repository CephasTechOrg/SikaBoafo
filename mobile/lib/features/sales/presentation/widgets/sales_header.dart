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
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SalesHeroCarousel(
        businessName: businessName,
        todayRevenueMinor: todayRevenueMinor,
        cashTotalMinor: cashTotalMinor,
        momoTotalMinor: momoTotalMinor,
        todayTxnsCount: todayTxnsCount,
        topSellingItemName: topSellingItemName,
        topSellingQty: topSellingQty,
        topSellingImageUrl: topSellingImageUrl,
      ),
    );
  }
}
