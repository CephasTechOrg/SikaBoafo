import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
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
      GoRouterState.of(context).uri.queryParameters['returnTo'],
    );
    final hasSession = await storage.hasPersistedSession();
    if (hasSession) {
      final biometricEnabled = await storage.isBiometricEnabled();
      if (biometricEnabled) {
        final bio = ref.read(biometricServiceProvider);
        final supported = await bio.isSupported();
        if (!mounted) return;
        if (supported) {
          final ok = await bio.authenticate(
            reason: 'Unlock SikaBoafo to continue.',
          );
          if (!mounted) return;
          if (ok) {
            await storage.writeLastBiometricAt(DateTime.now());
            await storage.markSessionGateComplete(DateTime.now());
          } else {
            if (!mounted) return;
            await storage.clearSessionGate();
            router.go(buildRouteLocation(AppRoute.auth, returnTo: returnTo));
            return;
          }
        } else {
          await storage.clearSessionGate();
          router.go(buildRouteLocation(AppRoute.auth, returnTo: returnTo));
          return;
        }
      }
      await storage.markSessionGateComplete(DateTime.now());
    }
    if (!hasSession) {
      router.go(buildRouteLocation(AppRoute.auth, returnTo: returnTo));
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
      router.go(resolveReturnToOrHome(returnTo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: MockupHeroHeader(
              waveHeight: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.88, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: const MockupAppMark(
                      size: 96,
                      assetPath: 'assets/images/logo.png',
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SikaBoafo',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontFamily: 'Constantia',
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: Column(
                  children: [
                    Text(
                      'Preparing your workspace…',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Synchronizing your merchant ledger and\ninsights.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.45,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(AppColors.forest),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SECURE CONNECTION ESTABLISHED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Text(
                          'End-to-end Encrypted',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
