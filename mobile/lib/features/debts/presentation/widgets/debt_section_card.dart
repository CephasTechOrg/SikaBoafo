import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

/// Bordered card with a titled header and divider, matching `.section-card`
/// in `index (2).html`. Used for Reminders and Repayments groups on the
/// debt detail screen.
class DebtSectionCard extends StatelessWidget {
  const DebtSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.countBadge,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;

  /// Optional integer count rendered as a small neutral pill in the header.
  final int? countBadge;

  /// Optional widget rendered at the far end of the header (e.g. an action
  /// like "Set reminder"). Mutually compatible with [countBadge] but the
  /// badge usually wins visual priority.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
        boxShadow: DebtsUi.shadowNeutralSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: DebtsUi.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DebtsUi.textPrimary,
                    ),
                  ),
                ),
                if (countBadge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: DebtsUi.avatarNeutralBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DebtsUi.avatarNeutralBorder),
                    ),
                    child: Text(
                      '$countBadge',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DebtsUi.textSecondary,
                      ),
                    ),
                  )
                else if (trailing != null)
                  trailing!,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1.5, color: DebtsUi.borderNeutral),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Centered "no data yet" cell for use inside [DebtSectionCard].
/// Mirrors `.empty-state` in the mockup.
class DebtSectionEmptyState extends StatelessWidget {
  const DebtSectionEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DebtsUi.avatarNeutralBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DebtsUi.avatarNeutralBorder, width: 1.5),
            ),
            child: Icon(icon, size: 18, color: DebtsUi.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DebtsUi.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: DebtsUi.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
