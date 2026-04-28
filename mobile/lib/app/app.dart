import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/providers/core_providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter(ref));

bool _isProtectedPath(String path) {
  return path == AppRoute.home.path ||
      path == AppRoute.debts.path ||
      path.startsWith('${AppRoute.debts.path}/') ||
      path == AppRoute.reports.path ||
      path == AppRoute.settings.path ||
      path.startsWith('${AppRoute.settings.path}/') ||
      path == AppRoute.customers.path ||
      path.startsWith('${AppRoute.customers.path}/');
}

class BizTrackApp extends ConsumerStatefulWidget {
  const BizTrackApp({super.key});

  @override
  ConsumerState<BizTrackApp> createState() => _BizTrackAppState();
}

class _BizTrackAppState extends ConsumerState<BizTrackApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Security: require biometric gate on every resume when enabled.
    switch (state) {
      case AppLifecycleState.inactive:
        // Don't clear the gate here: the biometric prompt can temporarily
        // transition the app to inactive, which would cause an immediate re-lock.
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleBackgrounded();
        break;
      case AppLifecycleState.resumed:
        _handleResumed();
        break;
    }
  }

  void _handleBackgrounded() {
    // Clear the session gate so protected routes redirect to splash.
    final router = ref.read(appRouterProvider);
    final currentUri = router.routeInformationProvider.value.uri;
    if (_isProtectedPath(currentUri.path)) {
      unawaited(
        ref.read(secureTokenStorageProvider).writeLastProtectedRoute(
              currentUri.toString(),
            ),
      );
    }
    unawaited(ref.read(secureTokenStorageProvider).clearSessionGate());
  }

  void _handleResumed() async {
    final storage = ref.read(secureTokenStorageProvider);
    final hasSession = await storage.hasPersistedSession();
    if (!hasSession) return;
    final biometricEnabled = await storage.isBiometricEnabled();
    if (!biometricEnabled) return;
    final gateComplete = await storage.hasCompletedSessionGate();
    if (gateComplete) return;

    final router = ref.read(appRouterProvider);
    final currentUri = router.routeInformationProvider.value.uri;
    final loc = currentUri.toString();
    final path = currentUri.path;
    if (path == AppRoute.splash.path) return;
    if (path == AppRoute.lock.path) return;

    // If we're on a protected page, force lock to run biometric gate.
    if (_isProtectedPath(path)) {
      await storage.clearSessionGate();
      router.go(buildRouteLocation(AppRoute.lock, returnTo: loc));
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SikaBoafo',
      theme: buildAppTheme(),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
