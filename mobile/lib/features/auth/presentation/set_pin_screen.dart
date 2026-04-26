import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

/// After onboarding or OTP recovery, merchant sets a 4-6 digit PIN.
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pin.length < 4 || pin.length > 6 || !RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be 4-6 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).setPin(pin);
      if (!mounted) return;
      context.go(AppRoute.home.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeDioError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PremiumBadge(
                      label: 'Step 3 of 3',
                      icon: Icons.lock_person_rounded,
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Create your daily PIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use this with your phone number to get back into your workspace quickly without SMS every time.',
                      style: TextStyle(
                        color: Color(0xFFD8E8E4),
                        fontSize: 14,
                        height: 1.4,
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
                      const PremiumPanel(
                        backgroundColor: Color(0xFFF7F3EA),
                        child: Row(
                          children: [
                            Icon(Icons.shield_moon_rounded,
                                color: AppColors.gold),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Choose a 4-6 digit PIN you can remember quickly during business hours.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.38,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PremiumPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security setup',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            _PinField(
                              controller: _pinCtrl,
                              hintText: 'New PIN',
                              label: 'New PIN',
                            ),
                            const SizedBox(height: 12),
                            _PinField(
                              controller: _confirmCtrl,
                              hintText: 'Repeat PIN',
                              label: 'Confirm PIN',
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        PremiumPanel(
                          backgroundColor: const Color(0xFFFFF0ED),
                          borderColor: const Color(0xFFF4C6BE),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(_busy ? 'Saving PIN...' : 'Save PIN'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.hintText,
    required this.label,
  });

  final TextEditingController controller;
  final String hintText;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 6,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      style:
          Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: const Icon(Icons.password_rounded),
      ),
    );
  }
}
