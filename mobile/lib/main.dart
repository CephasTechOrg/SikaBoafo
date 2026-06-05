import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env/app_config.dart';
import 'app/error_handling.dart';
import 'shared/providers/core_providers.dart';

Future<void> main() async {
  runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers();

    // Use only the bundled Plus Jakarta Sans (assets/google_fonts/) — never
    // fetch the font over the network. Keeps the offline-first app fast and
    // correct on first launch with no connection.
    GoogleFonts.config.allowRuntimeFetching = false;

    await _initSupabase();

    final container = ProviderContainer();
    await _safeInit(
      'session gate',
      () => container.read(secureTokenStorageProvider).clearSessionGate(),
    );
    await _safeInit(
      'notifications',
      () async {
        final svc = container.read(notificationsServiceProvider);
        await svc.init();
        await svc.requestPermissionsIfNeeded();
      },
    );

    runApp(
      UncontrolledProviderScope(container: container, child: const BizTrackApp()),
    );
  });
}

Future<void> _initSupabase() async {
  // Supabase init failure must not block startup — the app is offline-first and
  // can run on cached/local data. Log and continue.
  await _safeInit(
    'supabase',
    () => Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    ),
  );
}

/// Runs a startup step, swallowing (and logging) failures so one flaky
/// dependency can't leave the user staring at a black screen.
Future<void> _safeInit(String label, Future<void> Function() step) async {
  try {
    await step();
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint('[startup:$label] failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
}
