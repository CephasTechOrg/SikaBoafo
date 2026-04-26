import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
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
          _AuthFlowStep.entry => _EntryView(
              onSignIn: _loading ? null : _goPinSignIn,
              onCreateAccount: _loading ? null : _goOtpCreate,
            ),
          _AuthFlowStep.pinSignIn => _AuthFormScaffold(
              key: const ValueKey('pin_sign_in'),
              title: 'Welcome back',
              subtitle:
                  'Use your phone number and PIN to get into your workspace quickly.',
              badgeLabel: 'Daily sign-in',
              onBack: _loading ? null : _backToEntry,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthInput(
                    controller: _phoneCtrl,
                    label: 'Phone number',
                    hintText: '+233 24 123 4567',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_iphone_rounded,
                  ),
                  const SizedBox(height: 12),
                  _AuthInput(
                    controller: _pinCtrl,
                    label: 'PIN',
                    hintText: '4-6 digits',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.password_rounded,
                    obscure: true,
                  ),
                  _ErrorBlock(message: _error),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loading ? null : _loginWithPin,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(_loading ? 'Signing in...' : 'Sign in'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _goOtpRecovery,
                    icon: const Icon(Icons.lock_reset_rounded),
                    label: const Text('Forgot PIN?'),
                  ),
                ],
              ),
            ),
          _AuthFlowStep.otpVerify => _AuthFormScaffold(
              key: const ValueKey('otp_verify'),
              title: _otpIntent == _OtpIntent.create
                  ? 'Verify your phone'
                  : 'Reset your access',
              subtitle: _otpIntent == _OtpIntent.create
                  ? 'We will send a one-time code to confirm you control this number.'
                  : 'Confirm the phone number on the account so you can set a new PIN.',
              badgeLabel: _otpTitle,
              onBack: _loading
                  ? null
                  : (_otpIntent == _OtpIntent.recovery
                      ? _goPinSignIn
                      : _backToEntry),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthInput(
                    controller: _phoneCtrl,
                    label: 'Phone number',
                    hintText: '+233 24 123 4567',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_iphone_rounded,
                  ),
                  const SizedBox(height: 12),
                  _AuthInput(
                    controller: _codeCtrl,
                    label: 'One-time code',
                    hintText: _otpRequested
                        ? 'Enter code from SMS'
                        : 'Request code first',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.mark_chat_unread_rounded,
                    obscure: true,
                    enabled: _otpRequested,
                  ),
                  if (_otpRequested) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Code expires in $_expiryMinutes minutes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  _ErrorBlock(message: _error),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : (_otpRequested ? _verifyOtp : _requestOtp),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _otpRequested
                                ? Icons.check_circle_rounded
                                : Icons.sms_rounded,
                          ),
                    label: Text(
                      _loading
                          ? 'Working...'
                          : (_otpRequested ? 'Continue' : 'Send OTP'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : (_otpRequested
                            ? _requestOtp
                            : (_otpIntent == _OtpIntent.recovery
                                ? _goPinSignIn
                                : _backToEntry)),
                    icon: Icon(
                      _otpRequested
                          ? Icons.refresh_rounded
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(_otpRequested ? 'Resend OTP' : 'Back'),
                  ),
                  if (_otpIntent == _OtpIntent.create) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Standard SMS rates may apply. Once you set your PIN, daily sign-in will not require SMS.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final VoidCallback? onSignIn;
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('entry_view'),
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumBadge(
                label: 'Merchant control for every day',
                icon: Icons.auto_graph_rounded,
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset(
                      'assets/images/sikaboafo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  'SikaBoafo',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'A calm, professional workspace for sales, stock, expenses, debts, and daily business clarity.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFDCEAE7),
                      ),
                ),
              ),
              const Spacer(),
              PremiumPanel(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                borderColor: Colors.white.withValues(alpha: 0.10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.forestDark,
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign in'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onCreateAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthFormScaffold extends StatelessWidget {
  const _AuthFormScaffold({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.onBack,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.shell),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 24, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumBadge(label: badgeLabel),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontFamily: 'SegoeUI',
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFFD8E8E4),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PremiumSurface(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                  children: [
                    PremiumPanel(child: child),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.keyboardType,
    required this.prefixIcon,
    this.obscure = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final bool obscure;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        fillColor: enabled ? Colors.white : const Color(0xFFF0F2EE),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: PremiumPanel(
        backgroundColor: const Color(0xFFFFF0ED),
        borderColor: const Color(0xFFF4C6BE),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
