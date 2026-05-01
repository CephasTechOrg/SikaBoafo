import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/mockup_ui.dart';

/// Chooses initial route from locally stored auth session.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _minSplashDuration = Duration(milliseconds: 3000);
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(_minSplashDuration, _goNext);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  Future<void> _goNext() async {
    // Keep splash visible long enough to read + avoid a “flash” on fast devices.
    if (!mounted) return;
    final router = GoRouter.of(context);
    final storage = ref.read(secureTokenStorageProvider);
    final returnTo = sanitizeReturnTo(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
    );
    final lastProtected = sanitizeReturnTo(await storage.readLastProtectedRoute());
    // We ignore lastProtected for now to ensure a fresh start at the dashboard
    // and avoid "stuck" loops if a deep-level page has issues.
    final preferredReturnTo = returnTo;
    final hasSession = await storage.hasPersistedSession();
    if (hasSession) {
      final biometricEnabled = await storage.isBiometricEnabled();
      if (biometricEnabled) {
        final bio = ref.read(biometricServiceProvider);
        final supported = await bio.isSupported();
        if (!mounted) return;
        if (!supported) {
          await storage.clearSessionGate();
          router.go(buildRouteLocation(AppRoute.auth, returnTo: preferredReturnTo));
          return;
        }
        await storage.clearSessionGate();
        router.go(buildRouteLocation(AppRoute.lock, returnTo: preferredReturnTo));
        return;
      }
      await storage.markSessionGateComplete(DateTime.now());
    }
    if (!hasSession) {
      router.go(buildRouteLocation(AppRoute.auth, returnTo: preferredReturnTo));
      return;
    }
    // A session exists but onboarding may be incomplete (tokens written before
    // the business profile is saved). Route to onboarding if no merchant yet.
    final merchantId =
        await ref.read(appDatabaseProvider).getActiveMerchantId();
    if (!mounted) return;
    if (merchantId == null) {
      router.go(AppRoute.onboarding.path);
    } else {
      router.go(resolveReturnToOrHome(preferredReturnTo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: Column(
            children: [
              // ── Centred brand mark ──────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.82, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, child) =>
                            Transform.scale(scale: value, child: child),
                        child: const MockupAppMark(
                          size: 88,
                          assetPath: 'assets/images/logo.png',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'SikaBoafo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFamily: 'Constantia',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Business made simple',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom: loading dots + lock badge ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingDots(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.40),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'End-to-end encrypted',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final start = i / 3;
        final end = (i + 1) / 3;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0);
              final opacity = (0.35 + 0.65 * (1 - (t * 2 - 1).abs()))
                  .clamp(0.35, 1.0);
              return Opacity(
                opacity: opacity,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
