import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

/// Phone + PIN for daily sign-in; SMS OTP for create account and recovery.
class AuthShellScreen extends ConsumerStatefulWidget {
  const AuthShellScreen({super.key});

  @override
  ConsumerState<AuthShellScreen> createState() => _AuthShellScreenState();
}

enum _AuthFlowStep { entry, pinSignIn, otpVerify }

enum _OtpIntent { create, recovery }

class _AuthShellScreenState extends ConsumerState<AuthShellScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  _AuthFlowStep _step = _AuthFlowStep.entry;
  _OtpIntent _otpIntent = _OtpIntent.create;

  bool _otpRequested = false;
  bool _loading = false;
  int _expiryMinutes = 5;
  String? _error;
  bool _pinObscured = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _applySession(AuthSession session,
      {required bool forceSetPin}) async {
    await ref.read(sessionServiceProvider).applyAuthenticatedSession(
          userId: session.userId,
          merchantId: session.merchantId,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
    if (!mounted) return;
    if (session.onboardingRequired) {
      context.go(AppRoute.onboarding.path);
    } else if (forceSetPin || !session.pinSet) {
      context.go(AppRoute.setPin.path);
    } else {
      context.go(AppRoute.home.path);
    }
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expires =
          await ref.read(authApiProvider).requestOtp(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _otpRequested = true;
        _expiryMinutes = expires;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      await _applySession(
        session,
        forceSetPin: _otpIntent == _OtpIntent.recovery,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithPin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref.read(authApiProvider).loginWithPin(
            phoneNumber: _phoneCtrl.text.trim(),
            pin: _pinCtrl.text.trim(),
          );
      await _applySession(session, forceSetPin: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goPinSignIn() {
    setState(() {
      _step = _AuthFlowStep.pinSignIn;
      _error = null;
      _pinCtrl.clear();
    });
  }

  void _goOtpCreate() {
    setState(() {
      _step = _AuthFlowStep.otpVerify;
      _otpIntent = _OtpIntent.create;
      _otpRequested = false;
      _error = null;
      _codeCtrl.clear();
    });
  }

  void _goOtpRecovery() {
    setState(() {
      _step = _AuthFlowStep.otpVerify;
      _otpIntent = _OtpIntent.recovery;
      _otpRequested = false;
      _error = null;
      _codeCtrl.clear();
    });
  }

  void _backToEntry() {
    setState(() {
      _step = _AuthFlowStep.entry;
      _otpRequested = false;
      _loading = false;
      _error = null;
      _codeCtrl.clear();
      _pinCtrl.clear();
    });
  }

  String get _otpTitle =>
      _otpIntent == _OtpIntent.create ? 'Create account' : 'Recover access';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOut,
        child: switch (_step) {
          _AuthFlowStep.entry => _EntryViewMockup(
              onSignIn: _loading ? null : _goPinSignIn,
              onCreateAccount: _loading ? null : _goOtpCreate,
            ),
          _AuthFlowStep.pinSignIn => _PinSignInView(
              phoneCtrl: _phoneCtrl,
              pinCtrl: _pinCtrl,
              pinObscured: _pinObscured,
              loading: _loading,
              error: _error,
              onBack: _loading ? null : _backToEntry,
              onForgotPin: _loading ? null : _goOtpRecovery,
              onTogglePin: () => setState(() => _pinObscured = !_pinObscured),
              onSubmit: _loading ? null : _loginWithPin,
              onCreateAccount: _loading ? null : _goOtpCreate,
            ),
          _AuthFlowStep.otpVerify => _OtpVerifyView(
              phoneCtrl: _phoneCtrl,
              codeCtrl: _codeCtrl,
              otpRequested: _otpRequested,
              expiryMinutes: _expiryMinutes,
              loading: _loading,
              error: _error,
              intent: _otpIntent,
              onBack: _loading
                  ? null
                  : (_otpIntent == _OtpIntent.recovery
                      ? _goPinSignIn
                      : _backToEntry),
              onRequestOrResend: _loading ? null : _requestOtp,
              onVerify: _loading ? null : _verifyOtp,
            ),
        },
      ),
    );
  }
}

class _EntryViewMockup extends StatelessWidget {
  const _EntryViewMockup({
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final VoidCallback? onSignIn;
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('entry_view'),
      color: AppColors.canvas,
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: MockupHeroHeader(
              waveHeight: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(height: 8),
                  MockupAppMark(size: 92),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Your business,\nsimplified.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The modern financial workspace\ndesigned for professionals who demand\nclarity and efficiency.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 18),
                    MockupCtaButton.primary(
                      label: 'Sign In',
                      onPressed: onSignIn,
                    ),
                    const SizedBox(height: 12),
                    MockupCtaButton.secondary(
                      label: 'Create account',
                      onPressed: onCreateAccount,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle,
                            size: 6, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'ENTERPRISE WORKSPACE V2.4',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinSignInView extends StatelessWidget {
  const _PinSignInView({
    required this.phoneCtrl,
    required this.pinCtrl,
    required this.pinObscured,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onForgotPin,
    required this.onTogglePin,
    required this.onSubmit,
    required this.onCreateAccount,
  });

  final TextEditingController phoneCtrl;
  final TextEditingController pinCtrl;
  final bool pinObscured;
  final bool loading;
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onForgotPin;
  final VoidCallback onTogglePin;
  final VoidCallback? onSubmit;
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('pin_sign_in'),
      color: AppColors.canvas,
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: MockupHeroHeader(
              waveHeight: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const MockupAppMark(size: 66),
                  const SizedBox(height: 14),
                  Text(
                    'SikaBoafo',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: phoneCtrl,
                          label: 'Phone Number',
                          hint: '+233 55 123 4567',
                          keyboardType: TextInputType.phone,
                          prefixIcon:
                              const Icon(Icons.phone_iphone_rounded, size: 18),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Security PIN',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: AppColors.inkSoft),
                              ),
                            ),
                            TextButton(
                              onPressed: onForgotPin,
                              child: const Text('Forgot PIN?'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: pinCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: pinObscured,
                          enabled: !loading,
                          decoration: InputDecoration(
                            hintText: '••••',
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              onPressed: onTogglePin,
                              icon: Icon(pinObscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        if (error != null && error!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InlineError(message: error!),
                        ],
                        const SizedBox(height: 16),
                        MockupCtaButton.primary(
                          label: loading ? 'Signing In' : 'Sign In',
                          onPressed: onSubmit,
                          loading: loading,
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'NEW TO SIKABOAFO?',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        MockupCtaButton.secondary(
                          label: 'Create account',
                          onPressed: onCreateAccount,
                        ),
                      ],
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

class _OtpVerifyView extends StatelessWidget {
  const _OtpVerifyView({
    required this.phoneCtrl,
    required this.codeCtrl,
    required this.otpRequested,
    required this.expiryMinutes,
    required this.loading,
    required this.error,
    required this.intent,
    required this.onBack,
    required this.onRequestOrResend,
    required this.onVerify,
  });

  final TextEditingController phoneCtrl;
  final TextEditingController codeCtrl;
  final bool otpRequested;
  final int expiryMinutes;
  final bool loading;
  final String? error;
  final _OtpIntent intent;
  final VoidCallback? onBack;
  final VoidCallback? onRequestOrResend;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final title =
        intent == _OtpIntent.create ? 'Create your account' : 'Recover access';

    return ColoredBox(
      key: const ValueKey('otp_verify'),
      color: AppColors.canvas,
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: MockupHeroHeader(
              waveHeight: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const MockupAppMark(size: 72),
                  const SizedBox(height: 14),
                  Text(
                    'SikaBoafo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: phoneCtrl,
                          label: 'Phone Number',
                          hint: '+233 55 123 4567',
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.call_rounded, size: 18),
                        ),
                        const SizedBox(height: 14),
                        MockupCtaButton.primary(
                          label: 'Send Verification Code',
                          onPressed: onRequestOrResend,
                          loading: loading && !otpRequested,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Enter the 6-digit code sent to your phone',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkSoft,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 12),
                        OtpCodeInputRow(
                          controller: codeCtrl,
                          enabled: otpRequested && !loading,
                          onChanged: (_) {},
                        ),
                        if (otpRequested) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Code expires in $expiryMinutes minutes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: otpRequested ? onRequestOrResend : null,
                            child: const Text('Didn’t receive code? Resend OTP'),
                          ),
                        ),
                        if (error != null && error!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _InlineError(message: error!),
                        ],
                        const SizedBox(height: 14),
                        AnimatedBuilder(
                          animation: codeCtrl,
                          builder: (context, _) {
                            final codeComplete =
                                codeCtrl.text.trim().length >= 6;
                            return AppButton(
                              label: loading ? 'Verifying…' : 'Verify & Continue',
                              onPressed: (!otpRequested || !codeComplete)
                                  ? null
                                  : onVerify,
                              variant: AppButtonVariant.primary,
                              size: AppButtonSize.lg,
                              loading: loading && otpRequested,
                              fullWidth: true,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: AppButton.tertiary(
                            label: 'Sign In',
                            onPressed: onBack,
                            icon: Icons.arrow_forward_rounded,
                          ),
                        ),
                      ],
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF4C6BE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
