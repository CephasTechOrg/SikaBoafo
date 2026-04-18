import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/providers/core_providers.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

/// Phone + PIN for daily sign-in; SMS OTP for create account and Forgot PIN.
/// See `docs/auth/pin-and-otp-flow.md`.
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
    final secureStore = ref.read(secureTokenStorageProvider);
    await secureStore.writeAccessToken(session.accessToken);
    await secureStore.writeRefreshToken(session.refreshToken);
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
      final forceSetPin = _otpIntent == _OtpIntent.recovery;
      await _applySession(session, forceSetPin: forceSetPin);
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
      _otpIntent == _OtpIntent.create ? 'Create Account' : 'Reset PIN';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_step) {
            _AuthFlowStep.entry => _buildEntry(size),
            _AuthFlowStep.pinSignIn => _buildPinSignIn(size),
            _AuthFlowStep.otpVerify => _buildOtpVerification(size),
          },
        ),
      ),
    );
  }

  Widget _buildEntry(Size size) {
    final compact = size.height < 720;
    final logoSize = compact ? 86.0 : 96.0;
    final titleSize = compact ? 30.0 : 34.0;
    return Padding(
      key: const ValueKey('entry'),
      padding: EdgeInsets.symmetric(
          horizontal: size.width < 360 ? 18 : 24, vertical: 16),
      child: Column(
        children: [
          Spacer(flex: compact ? 1 : 2),
          Container(
            width: logoSize,
            height: logoSize,
            decoration: const BoxDecoration(
              color: Color(0xFF0B6B63),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: compact ? 46 : 52),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            'SikaBoafo',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B6B63),
              letterSpacing: 0.2,
            ),
          ),
          Spacer(flex: compact ? 2 : 3),
          _PrimaryActionButton(
            label: 'Sign In',
            icon: Icons.login_rounded,
            compact: compact,
            onPressed: _loading ? null : _goPinSignIn,
          ),
          SizedBox(height: compact ? 10 : 12),
          _SecondaryActionButton(
            label: 'Create Account',
            icon: Icons.person_add_alt_1_rounded,
            compact: compact,
            onPressed: _loading ? null : _goOtpCreate,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPinSignIn(Size size) {
    final compact = size.height < 720;
    final titleSize = compact ? 24.0 : 28.0;
    final sectionTitleSize = compact ? 21.0 : 24.0;
    final horizontalPadding = size.width < 360 ? 18.0 : 24.0;
    return SingleChildScrollView(
      key: const ValueKey('pin'),
      padding: EdgeInsets.only(bottom: compact ? 12 : 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0B6B63),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding:
                EdgeInsets.fromLTRB(6, compact ? 4 : 8, 14, compact ? 8 : 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: _loading ? null : _backToEntry,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    'Login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, compact ? 16 : 20, horizontalPadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Phone Number',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: sectionTitleSize),
                ),
                SizedBox(height: compact ? 8 : 10),
                _CleanInput(
                  controller: _phoneCtrl,
                  hintText: '+233 24 123 4567',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_iphone_rounded,
                  compact: compact,
                ),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  'PIN',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: sectionTitleSize),
                ),
                SizedBox(height: compact ? 8 : 10),
                _CleanInput(
                  controller: _pinCtrl,
                  hintText: '4–6 digits',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.password_rounded,
                  compact: compact,
                  obscure: true,
                ),
                if (_error != null) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                SizedBox(height: compact ? 18 : 24),
                _PrimaryActionButton(
                  label: 'Sign In',
                  icon: Icons.check_circle_rounded,
                  compact: compact,
                  onPressed: _loading ? null : _loginWithPin,
                ),
                SizedBox(height: compact ? 10 : 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _goOtpRecovery,
                    child: Text(
                      'Forgot PIN?',
                      style: TextStyle(
                        color: const Color(0xFF0B6B63),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerification(Size size) {
    final compact = size.height < 720;
    final titleSize = compact ? 24.0 : 28.0;
    final sectionTitleSize = compact ? 21.0 : 24.0;
    final horizontalPadding = size.width < 360 ? 18.0 : 24.0;
    return SingleChildScrollView(
      key: const ValueKey('otp'),
      padding: EdgeInsets.only(bottom: compact ? 12 : 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0B6B63),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding:
                EdgeInsets.fromLTRB(6, compact ? 4 : 8, 14, compact ? 8 : 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: _loading
                      ? null
                      : (_otpIntent == _OtpIntent.recovery
                          ? _goPinSignIn
                          : _backToEntry),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    _otpTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, compact ? 16 : 20, horizontalPadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Phone Number',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: sectionTitleSize),
                ),
                SizedBox(height: compact ? 8 : 10),
                _CleanInput(
                  controller: _phoneCtrl,
                  hintText: '+233 24 123 4567',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_iphone_rounded,
                  compact: compact,
                ),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  'Enter OTP',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: sectionTitleSize),
                ),
                SizedBox(height: compact ? 8 : 10),
                _CleanInput(
                  controller: _codeCtrl,
                  hintText: 'Code from SMS',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscure: true,
                  enabled: _otpRequested,
                  compact: compact,
                ),
                if (_otpRequested) ...[
                  SizedBox(height: compact ? 6 : 8),
                  Text(
                    'Code expires in $_expiryMinutes minutes',
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                SizedBox(height: compact ? 18 : 24),
                _PrimaryActionButton(
                  label: _otpRequested ? 'Continue' : 'Send OTP',
                  icon: _otpRequested
                      ? Icons.check_circle_rounded
                      : Icons.sms_rounded,
                  compact: compact,
                  onPressed: _loading
                      ? null
                      : (_otpRequested ? _verifyOtp : _requestOtp),
                ),
                SizedBox(height: compact ? 10 : 12),
                _SecondaryActionButton(
                  label: _otpRequested ? 'Resend OTP' : 'Back',
                  icon: _otpRequested
                      ? Icons.refresh_rounded
                      : Icons.arrow_back_rounded,
                  compact: compact,
                  onPressed: _loading
                      ? null
                      : (_otpRequested
                          ? _requestOtp
                          : (_otpIntent == _OtpIntent.recovery
                              ? _goPinSignIn
                              : _backToEntry)),
                ),
                if (_otpIntent == _OtpIntent.create) ...[
                  SizedBox(height: compact ? 8 : 10),
                  Center(
                    child: Text(
                      'We will text you a code. Standard SMS rates may apply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 50 : 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0B6B63),
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 18 : 20),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 50 : 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF334155),
          side: const BorderSide(color: Color(0xFFCFD8E3)),
          textStyle: TextStyle(
            fontSize: compact ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 18 : 20),
        label: Text(label),
      ),
    );
  }
}

class _CleanInput extends StatelessWidget {
  const _CleanInput({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.prefixIcon,
    required this.compact,
    this.obscure = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final bool compact;
  final bool obscure;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      enabled: enabled,
      style: TextStyle(
        fontSize: compact ? 16 : 17,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0xFF9AA5B1),
          fontSize: compact ? 15 : 16,
        ),
        prefixIcon: Icon(prefixIcon,
            size: compact ? 19 : 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 14 : 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B6B63), width: 1.3),
        ),
      ),
    );
  }
}
