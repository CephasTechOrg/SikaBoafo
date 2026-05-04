import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../shared/widgets/product_image_catalog.dart';
import '../utils/sales_ui_utils.dart';
import 'hero_stat_chip.dart';
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
  State<SalesCarousel> createState() => _SalesCarouselProxyState();
}

class _SalesCarouselProxyState extends State<SalesCarousel> {
  @override
  Widget build(BuildContext context) {
    return SalesHeroCarousel(
      businessName: widget.businessName,
      todayRevenueMinor: widget.todayRevenueMinor,
      cashTotalMinor: widget.cashTotalMinor,
      momoTotalMinor: widget.momoTotalMinor,
      todayTxnsCount: widget.todayTxnsCount,
      topSellingItemName: widget.topSellingItemName,
      topSellingQty: widget.topSellingQty,
      topSellingImageUrl: widget.topSellingImageUrl,
    );
  }
}

class SalesHeroCarousel extends StatefulWidget {
  const SalesHeroCarousel({
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
  State<SalesHeroCarousel> createState() => _SalesHeroCarouselState();
}

class _SalesHeroCarouselState extends State<SalesHeroCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _reduceMotion = false;

  static const int _slideCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextReduceMotion = MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (nextReduceMotion != _reduceMotion || _timer == null) {
      _reduceMotion = nextReduceMotion;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _slideCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 14;
    const horizontalPadding = 20.0;
    const bottomPadding = 56.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemCount: _slideCount,
          itemBuilder: (context, index) {
            return switch (index) {
              0 => RevenueHeroSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  revenueMinor: widget.todayRevenueMinor,
                  txns: widget.todayTxnsCount,
                  onTap: () => _showDetails(context),
                ),
              1 => GreetingHeroSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  businessName: widget.businessName,
                ),
              _ => TopSellerHeroSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  itemName: widget.topSellingItemName,
                  qty: widget.topSellingQty,
                  imageUrl: widget.topSellingImageUrl,
                ),
            };
          },
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 18,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slideCount, (index) {
                final active = _currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 26 : 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
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

class RevenueHeroSlide extends StatelessWidget {
  const RevenueHeroSlide({
    super.key,
    required this.padding,
    required this.topPadding,
    required this.revenueMinor,
    required this.txns,
    required this.onTap,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int revenueMinor;
  final int txns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HeroSlideFrame(
      onTap: onTap,
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF051A0E),
        Color(0xFF0C3A24),
        Color(0xFF1A6A43),
      ],
      glowColor: const Color(0xFF49D17B),
      accentAlignment: const Alignment(0.84, -0.66),
      patternIcon: Icons.payments_rounded,
      child: Stack(
        children: [
          const Positioned(
            right: -8,
            top: 16,
            child: _HeroCircleCluster(
              accent: Color(0x2BFFFFFF),
              icon: Icons.bar_chart_rounded,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s revenue',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                SalesUiUtils.formatMinor(revenueMinor, symbol: '₵'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Constantia',
                  letterSpacing: -1.1,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                txns == 1
                    ? '1 transaction recorded today'
                    : '$txns transactions recorded today',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const _TrendSparkline(),
                  const SizedBox(width: 12),
                  Text(
                    'Tap to view revenue breakdown',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GreetingHeroSlide extends StatelessWidget {
  const GreetingHeroSlide({
    super.key,
    required this.padding,
    required this.topPadding,
    required this.businessName,
  });

  final EdgeInsets padding;
  final double topPadding;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final greeting = SalesUiUtils.greetingFor(DateTime.now());
    return _HeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF0A2418),
        Color(0xFF123D2C),
        Color(0xFF224E3C),
      ],
      glowColor: const Color(0xFF97E1B4),
      accentAlignment: const Alignment(0.86, -0.28),
      patternIcon: Icons.storefront_rounded,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 14,
            child: _HeroMerchantIllustration(
              accent: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  'Ready to record today\'s sales?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select products below',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Your sales workspace is ready.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TopSellerHeroSlide extends StatelessWidget {
  const TopSellerHeroSlide({
    super.key,
    required this.padding,
    required this.topPadding,
    this.itemName,
    this.qty,
    this.imageUrl,
  });

  final EdgeInsets padding;
  final double topPadding;
  final String? itemName;
  final int? qty;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasTopSeller =
        itemName != null && itemName!.trim().isNotEmpty && (qty ?? 0) > 0;
    final safeName = itemName?.trim();

    return _HeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF132717),
        Color(0xFF20402A),
        Color(0xFF44634D),
      ],
      glowColor: const Color(0xFFD8C178),
      accentAlignment: const Alignment(0.86, -0.56),
      patternIcon: Icons.workspace_premium_rounded,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top seller this month',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  hasTopSeller
                      ? safeName!
                      : 'Start selling to unlock top products',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  hasTopSeller
                      ? '${qty ?? 0} units sold so far this month'
                      : 'Your best-selling products will appear here once you start recording sales.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    HeroStatChip(
                      icon: Icons.workspace_premium_rounded,
                      value: hasTopSeller ? '${qty ?? 0}' : '0',
                      label: 'Units sold',
                    ),
                    HeroStatChip(
                      icon: Icons.insights_rounded,
                      value: hasTopSeller ? 'Live insight' : 'Coming soon',
                      label: 'Sales momentum',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TopSellerVisual(
            imageUrl: imageUrl,
            hasTopSeller: hasTopSeller,
          ),
        ],
      ),
    );
  }
}

class _HeroSlideFrame extends StatelessWidget {
  const _HeroSlideFrame({
    required this.child,
    required this.padding,
    required this.colors,
    required this.glowColor,
    required this.accentAlignment,
    required this.patternIcon,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final List<Color> colors;
  final Color glowColor;
  final Alignment accentAlignment;
  final IconData patternIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: accentAlignment,
                    radius: 0.95,
                    colors: [
                      glowColor.withValues(alpha: 0.34),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.14),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: 26,
              child: Icon(
                patternIcon,
                size: 170,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSparkline extends StatelessWidget {
  const _TrendSparkline();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 18,
      child: CustomPaint(
        painter: _SparklinePainter(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(0, size.height * 0.78),
      Offset(size.width * 0.20, size.height * 0.58),
      Offset(size.width * 0.40, size.height * 0.62),
      Offset(size.width * 0.58, size.height * 0.30),
      Offset(size.width * 0.78, size.height * 0.42),
      Offset(size.width, size.height * 0.12),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final paint = Paint()
      ..color = const Color(0xFFE3F8EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    canvas.drawCircle(points.last, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroCircleCluster extends StatelessWidget {
  const _HeroCircleCluster({
    required this.accent,
    required this.icon,
  });

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Icon(icon, color: Colors.white.withValues(alpha: 0.60), size: 28),
        ],
      ),
    );
  }
}

class _HeroMerchantIllustration extends StatelessWidget {
  const _HeroMerchantIllustration({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 120,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 84,
              height: 64,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 10,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 36,
            top: 26,
            child: Icon(
              Icons.storefront_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          Positioned(
            right: 18,
            top: 14,
            child: Icon(
              Icons.inventory_2_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Icon(
              Icons.query_stats_rounded,
              size: 24,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSellerVisual extends StatelessWidget {
  const _TopSellerVisual({
    required this.imageUrl,
    required this.hasTopSeller,
  });

  final String? imageUrl;
  final bool hasTopSeller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: hasTopSeller && imageUrl != null
                    ? ClipOval(
                        child: ItemImage(
                          imageUrl: imageUrl,
                          size: 72,
                          fallbackIcon: Icons.workspace_premium_rounded,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      )
                    : Icon(
                        hasTopSeller
                            ? Icons.workspace_premium_rounded
                            : Icons.auto_graph_rounded,
                        color: const Color(0xFFE4D08A),
                        size: 32,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasTopSeller ? 'Best performer' : 'Insight locked',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
