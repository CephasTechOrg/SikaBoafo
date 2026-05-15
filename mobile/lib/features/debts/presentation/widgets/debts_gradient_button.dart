import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

/// Brand gradient primary CTA, matching the mockup's "Receive payment" /
/// "Set reminder" / FAB action style. Used by the various sheets and
/// inline form buttons across the debts feature so all primary actions
/// share the same visual language.
class DebtsGradientButton extends StatelessWidget {
  const DebtsGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 50,
    this.loadingLabel = 'Saving…',
  });

  final String label;
  final String loadingLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isInteractive = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onPressed : null,
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              gradient: isInteractive ? DebtsUi.ctaGradient : null,
              color: isInteractive ? null : DebtsUi.surface2,
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              border: Border.all(
                color: isInteractive ? Colors.transparent : DebtsUi.border,
                width: 1.5,
              ),
              boxShadow: isInteractive
                  ? const [
                      BoxShadow(
                        color: Color(0x4D166B42),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    size: 18,
                    color: isInteractive ? Colors.white : DebtsUi.textMuted,
                  ),
                if (loading || icon != null) const SizedBox(width: 10),
                Text(
                  loading ? loadingLabel : label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: isInteractive ? Colors.white : DebtsUi.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
