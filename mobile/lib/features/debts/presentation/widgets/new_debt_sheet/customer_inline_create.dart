import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';

/// Tiny inline form to create a new customer from inside the new-debt sheet.
/// Only collects name + optional phone — full edit happens elsewhere.
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
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: _saving ? null : widget.onCancel,
              color: AppColors.inkSoft,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 6),
            const Text(
              'Add a customer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 38),
          child: Text(
            'You can fill in more details later.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
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
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? 'Saving…' : 'Save customer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forestDark,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
