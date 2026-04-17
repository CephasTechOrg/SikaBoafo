import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_shell_screen.dart';
import '../features/auth/presentation/set_pin_screen.dart';
import '../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../features/onboarding/presentation/business_onboarding_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';

enum AppRoute {
  splash('/'),
  auth('/auth'),
  onboarding('/onboarding'),
  setPin('/set-pin'),
  home('/home');

  const AppRoute(this.path);
  final String path;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.auth.path,
        builder: (context, state) => const AuthShellScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding.path,
        builder: (context, state) => const BusinessOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.setPin.path,
        builder: (context, state) => const SetPinScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        builder: (context, state) => const DashboardShellScreen(),
      ),
    ],
  );
}
