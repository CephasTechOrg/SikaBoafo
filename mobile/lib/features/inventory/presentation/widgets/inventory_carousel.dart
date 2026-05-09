import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../../../../data/local/kv_cache_repository.dart';

class InventoryCarousel extends StatefulWidget {
  const InventoryCarousel({
    super.key,
    required this.totalValueMinor,
    required this.activeItemsCount,
    required this.lowStockCount,
    required this.categoriesCount,
  });

  final int totalValueMinor;
  final int activeItemsCount;
  final int lowStockCount;
  final int categoriesCount;

  @override
  State<InventoryCarousel> createState() => _InventoryCarouselState();
}

class _InventoryCarouselState extends State<InventoryCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;
  bool _reduceMotion = false;

  static const int _slideCount = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Start the timer immediately on first mount with the current reduce-motion
    // state. We do this here rather than waiting for didChangeDependencies so
    // there's a single, clear start point. didChangeDependencies will restart
    // it if the accessibility setting changes later.
    _reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
    _restartTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextReduceMotion =
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    // Only restart the timer when the setting actually changes — not on every
    // dependency rebuild. The null check was removed because initState now
    // guarantees the timer is always started on first mount.
    if (nextReduceMotion != _reduceMotion) {
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
              0 => _StockValueSlide(
                  padding: const EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, bottomPadding),
                  topPadding: topPadding,
                  totalValueMinor: widget.totalValueMinor,
                ),
              1 => _HealthSlide(
                  padding: const EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, bottomPadding),
                  topPadding: topPadding,
                  activeItems: widget.activeItemsCount,
                  lowStock: widget.lowStockCount,
                ),
              _ => _CatalogSlide(
                  padding: const EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, bottomPadding),
                  topPadding: topPadding,
                  categories: widget.categoriesCount,
                  totalItems: widget.activeItemsCount,
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
}

class _StockValueSlide extends StatelessWidget {
  const _StockValueSlide({
    required this.padding,
    required this.topPadding,
    required this.totalValueMinor,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int totalValueMinor;

  String _fmtMoney(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '₵$major.$cents';
  }

  @override
  Widget build(BuildContext context) {
    return _HeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF041C0B),
        Color(0xFF083A1A),
        Color(0xFF0F5A30),
        Color(0xFF196E3D),
      ],
      glowColor: const Color(0xFF27A84E),
      accentAlignment: const Alignment(0.68, -0.72),
      patternIcon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: DataFreshnessLabel(
                  kvKey: KvCacheRepository.kInventoryTs,
                  color: AppColors.heroSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'TOTAL RETAIL VALUE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtMoney(totalValueMinor),
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
          const Spacer(),
          Text(
            'Value if all stock sold at listed price',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSlide extends StatelessWidget {
  const _HealthSlide({
    required this.padding,
    required this.topPadding,
    required this.activeItems,
    required this.lowStock,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int activeItems;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    return _HeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF132717),
        Color(0xFF20402A),
        Color(0xFF44634D),
      ],
      glowColor: const Color(0xFFD8C178),
      accentAlignment: const Alignment(0.86, -0.56),
      patternIcon: Icons.monitor_heart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: DataFreshnessLabel(
                  kvKey: KvCacheRepository.kInventoryTs,
                  color: AppColors.heroSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'STOCK HEALTH',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeroStatChip(
                icon: Icons.inventory_2_rounded,
                value: '$activeItems',
                label: 'Active items',
              ),
              const SizedBox(width: 12),
              _HeroStatChip(
                icon: Icons.warning_amber_rounded,
                value: '$lowStock',
                label: 'Low stock',
                alert: lowStock > 0,
              ),
            ],
          ),
          const Spacer(),
          Text(
            lowStock > 0 ? 'Action needed to restock' : 'Inventory is healthy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSlide extends StatelessWidget {
  const _CatalogSlide({
    required this.padding,
    required this.topPadding,
    required this.categories,
    required this.totalItems,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int categories;
  final int totalItems;

  @override
  Widget build(BuildContext context) {
    return _HeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF0A2418),
        Color(0xFF123D2C),
        Color(0xFF224E3C),
      ],
      glowColor: const Color(0xFF97E1B4),
      accentAlignment: const Alignment(0.86, -0.28),
      patternIcon: Icons.category_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: DataFreshnessLabel(
                  kvKey: KvCacheRepository.kInventoryTs,
                  color: AppColors.heroSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'CATALOG ORGANIZATION',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeroStatChip(
                icon: Icons.folder_copy_rounded,
                value: '$categories',
                label: 'Categories',
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Across $totalItems distinct products',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({
    required this.icon,
    required this.value,
    required this.label,
    this.alert = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: alert
            ? AppColors.dangerSoft.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert
              ? AppColors.danger.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: alert
                  ? AppColors.danger
                  : Colors.white.withValues(alpha: 0.65),
              size: 16),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: alert ? AppColors.danger : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: alert
                      ? AppColors.danger
                      : Colors.white.withValues(alpha: 0.60),
                  fontSize: 11,
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

class _HeroSlideFrame extends StatelessWidget {
  const _HeroSlideFrame({
    required this.child,
    required this.padding,
    required this.colors,
    required this.glowColor,
    required this.accentAlignment,
    required this.patternIcon,
  });

  final Widget child;
  final EdgeInsets padding;
  final List<Color> colors;
  final Color glowColor;
  final Alignment accentAlignment;
  final IconData patternIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
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
    );
  }
}
