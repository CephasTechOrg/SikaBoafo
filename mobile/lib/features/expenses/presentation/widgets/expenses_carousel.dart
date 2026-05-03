import 'dart:async';

import 'package:flutter/material.dart';

import '../../../sales/presentation/utils/sales_ui_utils.dart';
import '../expenses_category_meta.dart';

/// Hero carousel for Expenses — mirrors [SalesHeroCarousel] layout and motion.
class ExpensesHeroCarousel extends StatefulWidget {
  const ExpensesHeroCarousel({
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
  State<ExpensesHeroCarousel> createState() => _ExpensesHeroCarouselState();
}

class _ExpensesHeroCarouselState extends State<ExpensesHeroCarousel> {
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
    final nextReduceMotion =
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
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
    const bottomPadding = 62.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemCount: _slideCount,
          itemBuilder: (context, index) {
            return switch (index) {
              0 => _TodaySpendSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  todayMinor: widget.todayMinor,
                  todayEntryCount: widget.todayEntryCount,
                ),
              1 => _GreetingSpendSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  businessName: widget.businessName,
                ),
              _ => _MonthMixSlide(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  topPadding: topPadding,
                  monthMinor: widget.monthMinor,
                  topCategoryKey: widget.topCategoryKey,
                  topCategoryMinor: widget.topCategoryMinor,
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

class _TodaySpendSlide extends StatelessWidget {
  const _TodaySpendSlide({
    required this.padding,
    required this.topPadding,
    required this.todayMinor,
    required this.todayEntryCount,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int todayMinor;
  final int todayEntryCount;

  @override
  Widget build(BuildContext context) {
    return _ExpenseHeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF2A1810),
        Color(0xFF4A2C1A),
        Color(0xFF6B3E24),
      ],
      glowColor: const Color(0xFFF59E0B),
      accentAlignment: const Alignment(0.84, -0.62),
      patternIcon: Icons.trending_down_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s spending',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SalesUiUtils.formatMinor(todayMinor, symbol: '₵'),
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
            todayEntryCount == 1
                ? '1 expense logged today'
                : '$todayEntryCount expenses logged today',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            'Log costs as you go to keep profit accurate.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingSpendSlide extends StatelessWidget {
  const _GreetingSpendSlide({
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
    return _ExpenseHeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF1E293B),
        Color(0xFF334155),
        Color(0xFF475569),
      ],
      glowColor: const Color(0xFF94A3B8),
      accentAlignment: const Alignment(0.86, -0.28),
      patternIcon: Icons.account_balance_wallet_rounded,
      child: Column(
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
            constraints: const BoxConstraints(maxWidth: 260),
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
          Text(
            'Stay on top of where your money goes.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const Spacer(),
          Text(
            'Your expense workspace is ready.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthMixSlide extends StatelessWidget {
  const _MonthMixSlide({
    required this.padding,
    required this.topPadding,
    required this.monthMinor,
    required this.topCategoryKey,
    required this.topCategoryMinor,
  });

  final EdgeInsets padding;
  final double topPadding;
  final int monthMinor;
  final String? topCategoryKey;
  final int? topCategoryMinor;

  @override
  Widget build(BuildContext context) {
    final key = topCategoryKey;
    final minorTop = topCategoryMinor ?? 0;
    final hasTop =
        key != null && key.isNotEmpty && minorTop > 0;
    final meta = hasTop ? expenseMetaFor(key) : null;
    return _ExpenseHeroSlideFrame(
      padding: padding.copyWith(top: topPadding),
      colors: const [
        Color(0xFF0F172A),
        Color(0xFF1E3A2F),
        Color(0xFF14532D),
      ],
      glowColor: const Color(0xFF4ADE80),
      accentAlignment: const Alignment(0.88, -0.52),
      patternIcon: Icons.pie_chart_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This month',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SalesUiUtils.formatMinor(monthMinor, symbol: '₵'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'Constantia',
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasTop
                ? 'Largest category: ${meta!.label}'
                : 'Categories will rank here as you add expenses.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasTop) ...[
            const SizedBox(height: 6),
            Text(
              SalesUiUtils.formatMinor(minorTop, symbol: '₵'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Review history anytime on the History tab.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseHeroSlideFrame extends StatelessWidget {
  const _ExpenseHeroSlideFrame({
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
                    glowColor.withValues(alpha: 0.32),
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
