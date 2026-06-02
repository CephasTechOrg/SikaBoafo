import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../data/models/local_receivable_record.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

/// Single row in the debts list, modelled after `debts UI mockup` `.debt-card`.
class DebtListTile extends StatelessWidget {
  const DebtListTile({
    super.key,
    required this.record,
    required this.onTap,
    this.showCustomerName = true,
    this.onRecordPayment,
  });

  final LocalReceivableRecord record;
  final VoidCallback onTap;
  final VoidCallback? onRecordPayment;

  /// When false (e.g. on customer detail), hides the customer name row.
  final bool showCustomerName;

  @override
  Widget build(BuildContext context) {
    final outstanding = DebtsUiUtils.formatAmount(record.outstandingAmount);
    final isSettled = record.status == 'settled';
    final isCancelled = record.status == 'cancelled';
    final isPartial = record.status == 'partially_paid';
    final isOverdue = !isSettled &&
        !isCancelled &&
        DebtsUiUtils.isOverdue(record.dueDateIso);
    final unsynced =
        record.syncStatus == 'pending' || record.syncStatus == 'sending';

    final name = record.customerName ?? '';
    final parts = name.trim().split(RegExp(r'\s+'));
    final customerInitials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');

    final badge = _resolveBadge(
      isSettled: isSettled,
      isCancelled: isCancelled,
      isOverdue: isOverdue,
      isPartial: isPartial,
    );

    // Avatar bg/fg based on status
    final Color avatarBg;
    final Color avatarFg;
    if (isOverdue) {
      avatarBg = const Color(0xFFFBECEC);
      avatarFg = const Color(0xFFD23B3B);
    } else if (isSettled) {
      avatarBg = const Color(0xFFEBF4EF);
      avatarFg = const Color(0xFF2F7D58);
    } else if (isCancelled) {
      avatarBg = const Color(0xFFF1F3F5);
      avatarFg = const Color(0xFF6B7280);
    } else if (isPartial) {
      avatarBg = const Color(0xFFFAF3E1);
      avatarFg = const Color(0xFFBE8A2C);
    } else {
      avatarBg = const Color(0xFFF1F3F5);
      avatarFg = const Color(0xFF6B7280);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
            boxShadow: DebtsUi.shadowNeutralSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Avatar(
                    initials: customerInitials,
                    bg: avatarBg,
                    fg: avatarFg,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showCustomerName) ...[
                          Text(
                            record.customerName ?? 'Unknown customer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DebtsUi.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        _MetaLine(record: record, unsynced: unsynced),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        outstanding,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isSettled
                              ? DebtsUi.textMuted
                              : DebtsUi.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusBadge(badge: badge),
                    ],
                  ),
                ],
              ),
              // Bottom row with due label + action button
              const SizedBox(height: 9),
              const Divider(height: 1, color: Color(0xFFEEF1F0)),
              const SizedBox(height: 9),
              _DueActionRow(
                dueDateIso: record.dueDateIso,
                isOverdue: isOverdue,
                isSettledOrCancelled: isSettled || isCancelled,
                onAction: onRecordPayment ?? onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BadgeStyle _resolveBadge({
    required bool isSettled,
    required bool isCancelled,
    required bool isOverdue,
    required bool isPartial,
  }) {
    if (isCancelled) {
      return const _BadgeStyle(
        label: 'Cancelled',
        bg: Color(0xFFF1F3F5),
        fg: Color(0xFF6B7280),
        border: Color(0xFFE5E7EB),
      );
    }
    if (isSettled) {
      return const _BadgeStyle(
        label: 'Paid',
        bg: Color(0xFFEBF4EF),
        fg: Color(0xFF2F7D58),
        border: Color(0xFFC8E6D4),
      );
    }
    if (isOverdue) {
      return const _BadgeStyle(
        label: 'Overdue',
        bg: Color(0xFFFBECEC),
        fg: Color(0xFFD23B3B),
        border: Color(0xFFFCDCDC),
      );
    }
    if (isPartial) {
      return const _BadgeStyle(
        label: 'Partial',
        bg: Color(0xFFFAF3E1),
        fg: Color(0xFFBE8A2C),
        border: Color(0xFFFFE8B0),
      );
    }
    return const _BadgeStyle(
      label: 'Unpaid',
      bg: Color(0xFFF1F3F5),
      fg: Color(0xFF6B7280),
      border: Color(0xFFE5E7EB),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.record, required this.unsynced});

  final LocalReceivableRecord record;
  final bool unsynced;

  @override
  Widget build(BuildContext context) {
    final invoice = record.invoiceNumber;
    final dueIso = record.dueDateIso;
    final pieces = <String>[
      if (invoice != null && invoice.isNotEmpty) invoice,
      if (dueIso != null && dueIso.isNotEmpty)
        DebtsUiUtils.formatDueLabel(dueIso),
    ];
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < pieces.length; i++) ...[
                if (i > 0)
                  const SizedBox(
                    width: 3,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DebtsUi.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(
                  pieces[i],
                  style: const TextStyle(
                    fontSize: 12,
                    color: DebtsUi.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (unsynced)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: DebtsUi.accentGoldSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: DebtsUi.accentGoldBorder),
                  ),
                  child: const Text(
                    'Unsynced',
                    style: TextStyle(
                      fontSize: 10,
                      color: DebtsUi.accentGoldInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.bg,
    required this.fg,
  });

  final String initials;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

class _DueActionRow extends StatelessWidget {
  const _DueActionRow({
    required this.dueDateIso,
    required this.isOverdue,
    required this.isSettledOrCancelled,
    required this.onAction,
  });

  final String? dueDateIso;
  final bool isOverdue;
  final bool isSettledOrCancelled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final dueLabel = dueDateIso != null && dueDateIso!.isNotEmpty
        ? DebtsUiUtils.formatDueLabel(dueDateIso!)
        : null;

    return Row(
      children: [
        if (dueLabel != null) ...[
          Icon(
            LucideIcons.clock,
            size: 12,
            color: isOverdue ? const Color(0xFFD23B3B) : DebtsUi.textMuted,
          ),
          const SizedBox(width: 5),
          Text(
            dueLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOverdue ? const Color(0xFFD23B3B) : DebtsUi.textMuted,
            ),
          ),
        ],
        const Spacer(),
        if (isSettledOrCancelled)
          GestureDetector(
            onTap: onAction,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'View details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F7A4A),
                ),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: onAction,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF168A55),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.qrCode, size: 13, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Collect via QR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.badge});

  final _BadgeStyle badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badge.border),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badge.fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
