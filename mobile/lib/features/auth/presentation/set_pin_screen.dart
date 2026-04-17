import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../data/auth_api.dart';
import '../providers/auth_providers.dart';

/// After onboarding or OTP recovery, merchant sets a 4–6 digit PIN (see `docs/auth/pin-and-otp-flow.md`).
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
      setState(() => _error = 'PIN must be 4–6 digits.');
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 720;
    final horizontalPadding = size.width < 360 ? 18.0 : 24.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create PIN',
                style: TextStyle(
                  fontSize: compact ? 26 : 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B6B63),
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                'Use 4–6 digits. You will use this with your phone number to sign in '
                'without SMS.',
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  color: const Color(0xFF475569),
                  height: 1.35,
                ),
              ),
              SizedBox(height: compact ? 20 : 24),
              Text(
                'New PIN',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 17 : 18),
              ),
              SizedBox(height: compact ? 8 : 10),
              _PinField(controller: _pinCtrl, compact: compact, hintText: '4–6 digits'),
              SizedBox(height: compact ? 16 : 18),
              Text(
                'Confirm PIN',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 17 : 18),
              ),
              SizedBox(height: compact ? 8 : 10),
              _PinField(controller: _confirmCtrl, compact: compact, hintText: 'Repeat PIN'),
              if (_error != null) ...[
                SizedBox(height: compact ? 10 : 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              SizedBox(height: compact ? 22 : 28),
              SizedBox(
                height: compact ? 50 : 54,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6B63),
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save PIN'),
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
    required this.compact,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool compact;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 6,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      style: TextStyle(
        fontSize: compact ? 16 : 17,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0xFF9AA5B1),
          fontSize: compact ? 15 : 16,
        ),
        prefixIcon: Icon(Icons.password_rounded, size: compact ? 19 : 20, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 14 : 16),
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
