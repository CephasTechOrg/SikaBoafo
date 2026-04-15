import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

/// Phone + OTP shell for section 6 auth.
class AuthShellScreen extends ConsumerStatefulWidget {
  const AuthShellScreen({super.key});

  @override
  ConsumerState<AuthShellScreen> createState() => _AuthShellScreenState();
}

class _AuthShellScreenState extends ConsumerState<AuthShellScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _otpRequested = false;
  bool _loading = false;
  int _expiryMinutes = 5;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expires = await ref.read(authApiProvider).requestOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _otpRequested = true;
        _expiryMinutes = expires;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref.read(authApiProvider).verifyOtp(
        phoneNumber: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
      final secureStore = ref.read(secureTokenStorageProvider);
      await secureStore.writeAccessToken(session.accessToken);
      await secureStore.writeRefreshToken(session.refreshToken);
      if (!mounted) return;
      final route = session.onboardingRequired
          ? AppRoute.onboarding.path
          : AppRoute.home.path;
      context.go(route);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '0244XXXXXX or 23324XXXXXX',
              ),
            ),
            const SizedBox(height: 12),
            if (_otpRequested)
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'OTP code',
                  helperText: 'Code expires in $_expiryMinutes minutes',
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : (_otpRequested ? _verifyOtp : _requestOtp),
              child: Text(_otpRequested ? 'Verify and continue' : 'Send OTP'),
            ),
            if (_otpRequested)
              TextButton(
                onPressed: _loading ? null : _requestOtp,
                child: const Text('Resend OTP'),
              ),
          ],
        ),
      ),
    );
  }
}
