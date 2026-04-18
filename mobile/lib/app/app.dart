import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

class BizTrackApp extends ConsumerWidget {
  const BizTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
