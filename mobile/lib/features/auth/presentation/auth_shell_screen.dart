import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/mockup_ui.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';
import 'widgets/auth_mockup_ui.dart';

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
    final returnTo = sanitizeReturnTo(
      GoRouterState.of(context).uri.queryParameters['returnTo'],
    );
    await ref.read(sessionServiceProvider).applyAuthenticatedSession(
          userId: session.userId,
          merchantId: session.merchantId,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          role: session.role,
        );
    if (!mounted) return;
    // Backend may not reliably send `onboarding_required` for brand new accounts.
    // Treat “new user” or “no merchant yet” as needing onboarding.
    if (session.onboardingRequired ||
        session.isNewUser ||
        session.merchantId == null) {
      context.go(buildRouteLocation(AppRoute.onboarding, returnTo: returnTo));
    } else if (forceSetPin || !session.pinSet) {
      context.go(buildRouteLocation(AppRoute.setPin, returnTo: returnTo));
    } else {
      context.go(resolveReturnToOrHome(returnTo));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _step == _AuthFlowStep.pinSignIn
          ? AuthMockup.bg
          : AppColors.surface,
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
    final screenH = MediaQuery.sizeOf(context).height;
    final heroH = (screenH * (446 / 830)).clamp(400.0, 480.0);

    return ColoredBox(
      key: const ValueKey('entry_view'),
      color: AppColors.surface,
      child: Column(
        children: [
          SizedBox(
            height: heroH,
            width: double.infinity,
            child: const AuthWelcomeHero(),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -AuthMockup.sheetOverlap),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AuthMockup.welcomeSheetRadius),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AuthMockup.gutter,
                      34,
                      AuthMockup.gutter,
                      24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your business,\nsimplified.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            letterSpacing: -0.96,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Track sales, stock, customers and debts — all in one calm, trustworthy workspace built for Ghanaian shops.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AuthMockup.ink2,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 30),
                        AuthMockupPrimaryButton(
                          label: 'Sign In',
                          onPressed: onSignIn,
                        ),
                        const SizedBox(height: 12),
                        AuthMockupGhostButton(
                          label: 'Create account',
                          onPressed: onCreateAccount,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AuthMockup.green600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Secure workspace · v2.4'.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                color: AuthMockup.ink3,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.92,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinSignInView extends StatefulWidget {
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
  State<_PinSignInView> createState() => _PinSignInViewState();
}

class _PinSignInViewState extends State<_PinSignInView> {
  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();

  @override
  void dispose() {
    _phoneFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('pin_sign_in'),
      color: AuthMockup.bg,
      child: Column(
        children: [
          AuthLoginHero(onBack: widget.onBack),
          Expanded(
            child: ColoredBox(
              color: AuthMockup.bg,
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AuthMockup.gutter,
                    16,
                    AuthMockup.gutter,
                    24,
                  ),
                    children: [
                      const AuthSecLabel('Phone Number'),
                      const SizedBox(height: 9),
                      AuthMockupField(
                        icon: Icons.phone_iphone_rounded,
                        focusNode: _phoneFocus,
                        child: TextField(
                          controller: widget.phoneCtrl,
                          focusNode: _phoneFocus,
                          enabled: !widget.loading,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          style: authPhoneFieldStyle,
                          decoration: const InputDecoration(
                            hintText: '+233 55 123 4567',
                            hintStyle: TextStyle(
                              color: AuthMockup.ink3,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) =>
                              FocusScope.of(context).requestFocus(_pinFocus),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: AuthSecLabel('Security PIN')),
                          GestureDetector(
                            onTap: widget.onForgotPin,
                            child: Text(
                              'Forgot PIN?',
                              style: GoogleFonts.plusJakartaSans(
                                color: AuthMockup.green700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      AuthMockupField(
                        icon: Icons.lock_rounded,
                        focusNode: _pinFocus,
                        trailing: IconButton(
                          onPressed: widget.onTogglePin,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            widget.pinObscured
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                            color: AuthMockup.ink3,
                          ),
                        ),
                        child: TextField(
                          controller: widget.pinCtrl,
                          focusNode: _pinFocus,
                          enabled: !widget.loading,
                          keyboardType: TextInputType.number,
                          obscureText: widget.pinObscured,
                          maxLength: 4,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: authPinFieldStyle,
                          decoration: authPinInputDecoration(
                            obscured: widget.pinObscured,
                          ),
                        ),
                      ),
                      if (widget.error != null && widget.error!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: widget.error!),
                      ],
                      const SizedBox(height: 24),
                      AuthMockupPrimaryButton(
                        label: widget.loading ? 'Signing In' : 'Sign In',
                        onPressed: widget.onSubmit,
                        loading: widget.loading,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(height: 1, color: AuthMockup.line),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'NEW TO SIKABOAFO?',
                              style: GoogleFonts.plusJakartaSans(
                                color: AuthMockup.ink3,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.88,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(height: 1, color: AuthMockup.line),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AuthMockupGhostButton(
                        label: 'Create account',
                        onPressed: widget.onCreateAccount,
                        height: 52,
                      ),
                      const SizedBox(height: 22),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: AuthMockup.green600,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Bank-grade security · your data stays private',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AuthMockup.ink3,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
            child: _AuthSettingsHeroHeader(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                            child:
                                const Text('Didn’t receive code? Resend OTP'),
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
                              label:
                                  loading ? 'Verifying…' : 'Verify & Continue',
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

class _AuthSettingsHeroHeader extends StatelessWidget {
  const _AuthSettingsHeroHeader({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _AuthWaveClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF041C0B),
                  Color(0xFF083A1A),
                  Color(0xFF0F5A30),
                  Color(0xFF196E3D),
                ],
                stops: [0.0, 0.28, 0.62, 1.0],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
          ),
          // Radial highlight
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.68, -0.72),
                radius: 0.92,
                colors: [
                  const Color(0xFF27A84E).withValues(alpha: 0.40),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          // Darken bottom edge
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF010A04).withValues(alpha: 0.28),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          const Positioned(
            left: -42,
            top: -38,
            child: _AuthSoftCircle(size: 120, opacity: 0.14),
          ),
          const Positioned(
            right: -54,
            top: 24,
            child: _AuthSoftCircle(size: 160, opacity: 0.10),
          ),
          const Positioned(
            right: 22,
            bottom: -48,
            child: _AuthSoftCircle(size: 140, opacity: 0.12),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24 + 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const h = 56.0;
    final path = Path()..lineTo(0, size.height - h);
    path.quadraticBezierTo(
      size.width * 0.22,
      size.height - h * 1.4,
      size.width * 0.5,
      size.height - h * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.78,
      size.height - h * 0.35,
      size.width,
      size.height - h * 0.85,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSoftCircle extends StatelessWidget {
  const _AuthSoftCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mint.withValues(alpha: opacity),
      ),
    );
  }
}
