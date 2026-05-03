import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../utils/sales_ui_utils.dart';
import 'sales_revenue_details_sheet.dart';

class SalesCarousel extends StatefulWidget {
  const SalesCarousel({
    super.key,
    required this.businessName,
    required this.todayRevenueMinor,
    required this.cashTotalMinor,
    required this.momoTotalMinor,
    required this.todayTxnsCount,
    this.topSellingItemName,
    this.topSellingQty,
    this.topSellingImageUrl,
  });

  final String businessName;
  final int todayRevenueMinor;
  final int cashTotalMinor;
  final int momoTotalMinor;
  final int todayTxnsCount;
  final String? topSellingItemName;
  final int? topSellingQty;
  final String? topSellingImageUrl;

  @override
  State<SalesCarousel> createState() => _SalesCarouselState();
}

class _SalesCarouselState extends State<SalesCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted) return;
      final nextPage = (_currentPage + 1) % 3;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 900),
        curve: Curves.fastOutSlowIn,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: 3,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page ?? index.toDouble()) - index;
                    value = (1 - (value.abs() * 0.1)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 140,
                      width: Curves.easeOut.transform(value) * MediaQuery.of(context).size.width,
                      child: child,
                    ),
                  );
                },
                child: _buildSlide(index),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildExpandingDots(),
      ],
    );
  }

  Widget _buildSlide(int index) {
    return switch (index) {
      0 => _RevenueSlide(
          revenueMinor: widget.todayRevenueMinor,
          txns: widget.todayTxnsCount,
          onTap: () => _showDetails(context),
        ),
      1 => _BusinessSlide(businessName: widget.businessName),
      _ => _InsightSlide(
          itemName: widget.topSellingItemName,
          qty: widget.topSellingQty,
          imageUrl: widget.topSellingImageUrl,
        ),
    };
  }

  Widget _buildExpandingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final active = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 3,
          width: active ? 16 : 4,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => SalesRevenueDetailsSheet(
        todayRevenueMinor: widget.todayRevenueMinor,
        cashTotalMinor: widget.cashTotalMinor,
        momoTotalMinor: widget.momoTotalMinor,
        todayTxnsCount: widget.todayTxnsCount,
      ),
    );
  }
}

// ─── Revenue Slide ──────────────────────────────────────────

class _RevenueSlide extends StatelessWidget {
  const _RevenueSlide({
    required this.revenueMinor,
    required this.txns,
    required this.onTap,
  });

  final int revenueMinor;
  final int txns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseSlide(
      onTap: onTap,
      accentColor: AppColors.forest,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "TODAY'S REVENUE",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SalesUiUtils.formatMinor(revenueMinor, symbol: '₵'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Constantia',
                    letterSpacing: -1.0,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                _MiniBadge(
                  icon: Icons.bolt_rounded,
                  label: '$txns sales',
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Business Slide ─────────────────────────────────────────

class _BusinessSlide extends StatelessWidget {
  const _BusinessSlide({required this.businessName});
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return _BaseSlide(
      accentColor: AppColors.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            greeting.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            businessName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Insight Slide ──────────────────────────────────────────

class _InsightSlide extends StatelessWidget {
  const _InsightSlide({this.itemName, this.qty, this.imageUrl});
  final String? itemName;
  final int? qty;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final name = itemName ?? 'No sales yet';
    final count = qty ?? 0;

    return _BaseSlide(
      accentColor: AppColors.gold,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "TOP SELLER THIS MONTH",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count items sold',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Product Image or Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.white.withValues(alpha: 0.1),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_graph_rounded,
                        color: AppColors.gold,
                        size: 24,
                      ),
                    )
                  : const Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseSlide extends StatelessWidget {
  const _BaseSlide({required this.child, this.onTap, required this.accentColor});
  final Widget child;
  final VoidCallback? onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Layer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Content Layer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
