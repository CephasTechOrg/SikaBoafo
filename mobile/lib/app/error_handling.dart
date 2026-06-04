import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralised crash-safety wiring.
///
/// Production builds must never surface Flutter's red/grey error box to a
/// merchant. [installErrorHandlers] routes framework errors, replaces the
/// default error widget with a calm fallback, and [runGuarded] catches
/// otherwise-unhandled async errors so the app degrades instead of crashing.
void installErrorHandlers() {
  // Framework (build/layout/paint) errors. In debug we keep Flutter's verbose
  // console dump; in release we log compactly and swallow the red screen.
  final FlutterExceptionHandler? previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      previousOnError?.call(details);
    } else {
      FlutterError.dumpErrorToConsole(details, forceReport: false);
    }
    // TODO(observability): forward to Crashlytics/Sentry when wired up.
  };

  // Replace the default (red in debug / grey in release) error box that shows
  // when a widget's build throws. A merchant should see a neutral placeholder,
  // never a stack trace.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // Keep the informative red box while developing.
      return ErrorWidget(details.exception);
    }
    return const _FriendlyErrorBox();
  };
}

/// Runs [body] inside a guarded zone so uncaught async errors are logged
/// rather than crashing the isolate. Use this to wrap `runApp`.
void runGuarded(FutureOr<void> Function() body) {
  runZonedGuarded<Future<void>>(
    () async => body(),
    (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[uncaught] $error');
        debugPrintStack(stackTrace: stack);
      }
      // TODO(observability): forward to Crashlytics/Sentry when wired up.
    },
  );
}

/// Neutral fallback shown in release when a widget fails to build. Sized to fit
/// whatever slot the broken widget occupied (it self-constrains).
class _FriendlyErrorBox extends StatelessWidget {
  const _FriendlyErrorBox();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFF9AA5B1), size: 28),
            SizedBox(height: 8),
            Text(
              'Something went wrong here.\nTry again in a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
