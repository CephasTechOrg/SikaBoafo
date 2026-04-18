import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';

/// Chooses initial route from locally stored auth session.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final token = await ref.read(secureTokenStorageProvider).readAccessToken();
    if (!mounted) return;
    final route = (token != null && token.isNotEmpty)
        ? AppRoute.home.path
        : AppRoute.auth.path;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlutterLogo(size: 72),
            SizedBox(height: 16),
            Text('SikaBoafo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
