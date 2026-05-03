import 'package:flutter/material.dart';

import 'expenses_carousel.dart';

class ExpensesHeader extends StatelessWidget {
  const ExpensesHeader({
    super.key,
    required this.businessName,
    required this.todayMinor,
    required this.monthMinor,
    required this.todayEntryCount,
    this.topCategoryKey,
    this.topCategoryMinor,
  });

  final String businessName;
  final int todayMinor;
  final int monthMinor;
  final int todayEntryCount;
  final String? topCategoryKey;
  final int? topCategoryMinor;

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
      child: ExpensesHeroCarousel(
        businessName: businessName,
        todayMinor: todayMinor,
        monthMinor: monthMinor,
        todayEntryCount: todayEntryCount,
        topCategoryKey: topCategoryKey,
        topCategoryMinor: topCategoryMinor,
      ),
    );
  }
}
