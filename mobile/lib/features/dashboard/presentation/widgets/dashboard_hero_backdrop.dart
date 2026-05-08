import 'dart:async';
import 'package:flutter/material.dart';

class DashboardHeroBackdrop extends StatefulWidget {
  const DashboardHeroBackdrop({
    super.key,
  });

  @override
  State<DashboardHeroBackdrop> createState() => _DashboardHeroBackdropState();
}

class _DashboardHeroBackdropState extends State<DashboardHeroBackdrop> {
  Timer? _timer;
  int _currentIndex = 0;
  bool _reduceMotion = false;

  final List<String> _images = const [
    'assets/images/map.png',
    'assets/images/independence.png',
  ];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_reduceMotion) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _images.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Deep forest base
        Positioned.fill(
          child: Container(color: const Color(0xFF031A0C)),
        ),

        // 2. Rotating flag/swirl image — slightly dimmed so it's visible but not loud
        Positioned.fill(
          child: Opacity(
            opacity: 0.55,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Image.asset(
                _images[_currentIndex],
                key: ValueKey<String>(_images[_currentIndex]),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),

        // 3. Rich green radial bloom — centred top-right for depth
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.55, -0.6),
                radius: 1.1,
                colors: [
                  Color(0x881B7A44), // vivid green centre
                  Color(0x441A5C33), // mid
                  Color(0x00000000), // fades out
                ],
              ),
            ),
          ),
        ),

        // 4. Main top-to-bottom gradient — keeps text readable at top,
        //    and opens up to transparent at the bottom (where the card lifts)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.72, 1.0],
                colors: [
                  Color(0xCC031A0C), // dark at the very top (status bar)
                  Color(0x801A6840), // rich green mid-upper
                  Color(0x3A0D4023), // lighter green lower
                  Color(0x00000000), // fully transparent at sheet edge
                ],
              ),
            ),
          ),
        ),

        // 5. Subtle left-edge vignette for depth
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x44031A0C),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
