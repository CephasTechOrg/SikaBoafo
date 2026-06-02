import 'package:flutter/material.dart';
import 'sales_mockup_hero.dart';

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
    return SalesMockupHero(
      topSellingItemName: topSellingItemName,
      topSellingQty:      topSellingQty,
      topSellingImageUrl: topSellingImageUrl,
    );
  }
}
