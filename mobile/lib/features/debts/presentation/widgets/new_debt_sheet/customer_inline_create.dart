import 'package:flutter/material.dart';

import '../../utils/debts_ui_tokens.dart';
import '../debts_gradient_button.dart';

/// Tiny inline form to create a new customer from inside the new-debt sheet.
/// Only collects name + optional phone — full edit happens elsewhere. Uses
/// the shared mockup design language.
class CustomerInlineCreate extends StatefulWidget {
  const CustomerInlineCreate({
    super.key,
    required this.onCancel,
    required this.onSubmit,
  });

  final VoidCallback onCancel;

  /// Called when the form is valid. Caller is responsible for awaiting the
  /// repository write and dismissing this view.
  final Future<void> Function({
    required String name,
    String? phoneNumber,
  }) onSubmit;

  @override
  State<CustomerInlineCreate> createState() => _CustomerInlineCreateState();
}

class _CustomerInlineCreateState extends State<CustomerInlineCreate> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Customer name must be at least 2 characters.');
      return;
    }
    final phoneRaw = _phoneCtrl.text.trim();
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSubmit(
        name: name,
        phoneNumber: phoneRaw.isEmpty ? null : phoneRaw,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _saving ? null : widget.onCancel,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DebtsUi.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: DebtsUi.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: DebtsUi.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Add a customer',
                style: TextStyle(
                  fontFamily: 'Constantia',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DebtsUi.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 46),
          child: Text(
            'You can fill in more details later.',
            style: TextStyle(
              fontSize: 12.5,
              color: DebtsUi.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Field(
          controller: _nameCtrl,
          label: 'Customer name',
          icon: Icons.person_outline_rounded,
          autofocus: true,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: _phoneCtrl,
          label: 'Phone (optional)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: DebtsUi.dangerSoft,
              borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              border: Border.all(color: DebtsUi.dangerBorder, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: DebtsUi.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: DebtsUi.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        DebtsGradientButton(
          label: 'Save customer',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      cursorColor: DebtsUi.greenMid,
      style: const TextStyle(fontSize: 14, color: DebtsUi.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12.5,
          color: DebtsUi.greenMid,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        prefixIcon: Icon(icon, color: DebtsUi.textSecondary, size: 20),
        filled: true,
        fillColor: DebtsUi.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          borderSide: const BorderSide(color: DebtsUi.greenMid, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
