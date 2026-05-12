import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';

/// Submit button for the receive-payment sheet. Encapsulates the disabled
/// / loading visuals so the sheet body stays focused on form state.
class ReceivePaymentConfirmButton extends StatelessWidget {
  const ReceivePaymentConfirmButton({
    super.key,
    required this.enabled,
    required this.submitting,
    required this.onTap,
    this.label = 'Confirm payment',
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (enabled && !submitting) ? onTap : null,
        icon: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_rounded, size: 18),
        label: Text(submitting ? 'Saving…' : label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestDark,
          disabledBackgroundColor: AppColors.borderStrong,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
