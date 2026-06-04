import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/providers/core_providers.dart';
import 'navigation_keys.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter(ref));

/// Require biometric / lock screen only after the app has been in the
/// background at least this long. Shorter pauses (notification shade, quick
/// app switches, brief inactive phases) keep the existing session gate.
const Duration _kMinBackgroundForLock = Duration(seconds: 180);

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
  /// First moment we left the foreground this stint; reset after [didChangeAppLifecycleState] handles `resumed`.
  DateTime? _backgroundStartedAt;

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
        _handleBackgrounded();
        break;
      // Omit `hidden`: on newer Android it can fire in situations where the
      // user has not really left the app; `paused` + `detached` cover real backgrounding.
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.resumed:
        _handleResumed();
        break;
    }
  }

  void _handleBackgrounded() {
    _backgroundStartedAt ??= DateTime.now();
    final router = ref.read(appRouterProvider);
    final currentUri = router.routeInformationProvider.value.uri;
    if (_isProtectedPath(currentUri.path)) {
      unawaited(
        ref.read(secureTokenStorageProvider).writeLastProtectedRoute(
              currentUri.toString(),
            ),
      );
    }
    // Do not clear the session gate here — brief backgrounds should not force
    // biometric again. See [_handleResumed] after [_kMinBackgroundForLock].
  }

  void _handleResumed() async {
    final started = _backgroundStartedAt;
    _backgroundStartedAt = null;

    final storage = ref.read(secureTokenStorageProvider);
    final hasSession = await storage.hasPersistedSession();
    if (!hasSession) return;

    final biometricEnabled = await storage.isBiometricEnabled();
    if (!biometricEnabled) return;

    // No measurable background stint (e.g. only `inactive` during system UI).
    if (started == null) return;

    final awayFor = DateTime.now().difference(started);
    if (awayFor < _kMinBackgroundForLock) {
      return;
    }

    final router = ref.read(appRouterProvider);
    final currentUri = router.routeInformationProvider.value.uri;
    final loc = currentUri.toString();
    final path = currentUri.path;
    if (path == AppRoute.splash.path) return;
    if (path == AppRoute.lock.path) return;

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
      scrollBehavior: const _AppScrollBehavior(),
      builder: (context, child) {
        // Clamp system font scaling so large-text accessibility settings
        // don't overflow fixed-height rows and chips across all screens.
        final clamped = MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.of(context).textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.15,
          ),
        );
        return MediaQuery(data: clamped, child: child!);
      },
    );
  }
}

/// App-wide scroll behavior: removes the Android overscroll glow so brand
/// surfaces (green heroes, gray sheets) never show a coloured glow on pull.
/// Keeps every scrollable screen consistent with the mockup look.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
