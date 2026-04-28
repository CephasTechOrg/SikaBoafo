import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env/app_config.dart';
import 'shared/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  final container = ProviderContainer();
  await container.read(secureTokenStorageProvider).clearSessionGate();
  await container.read(notificationsServiceProvider).init();
  await container.read(notificationsServiceProvider).requestPermissionsIfNeeded();
  runApp(UncontrolledProviderScope(container: container, child: const BizTrackApp()));
}
