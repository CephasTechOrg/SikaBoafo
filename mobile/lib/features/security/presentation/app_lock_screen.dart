import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/biometric_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/mockup_ui.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storage = ref.read(secureTokenStorageProvider);
      final enabled = await storage.isBiometricEnabled();
      final hasSession = await storage.hasPersistedSession();
      if (!mounted) return;

      if (!hasSession) {
        context.go(buildRouteLocation(AppRoute.auth, returnTo: widget.returnTo));
        return;
      }
      if (!enabled) {
        await storage.markSessionGateComplete(DateTime.now());
        if (!mounted) return;
        context.go(resolveReturnToOrHome(widget.returnTo));
        return;
      }

      final bio = ref.read(biometricServiceProvider);
      final availability = await bio.availability();
      if (!mounted) return;

      if (availability != BiometricAvailability.available) {
        setState(() {
          _error = switch (availability) {
            BiometricAvailability.notSupported =>
              'Biometrics not supported on this device.',
            BiometricAvailability.notEnrolled =>
              'No Face/Fingerprint set up. Enable it in phone settings.',
            BiometricAvailability.unknown => 'Biometric status unknown.',
            _ => 'Unable to use biometrics.',
          };
        });
        return;
      }

      final ok = await bio.authenticate(reason: 'Unlock SikaBoafo to continue.');
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Biometric auth was cancelled or failed.');
        return;
      }

      await storage.writeLastBiometricAt(DateTime.now());
      await storage.markSessionGateComplete(DateTime.now());
      if (!mounted) return;
      context.go(resolveReturnToOrHome(widget.returnTo));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to unlock. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await ref.read(sessionServiceProvider).signOut();
    if (!mounted) return;
    context.go(buildRouteLocation(AppRoute.auth, returnTo: widget.returnTo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          const Positioned.fill(child: HeroBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const MockupAppMark(size: 72),
                  const SizedBox(height: 16),
                  Text(
                    'App locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unlock to continue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (_error != null && _error!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _unlock,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.fingerprint_rounded),
                      label: Text(_loading ? 'Unlocking…' : 'Unlock'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading ? null : _signOut,
                    child: const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

