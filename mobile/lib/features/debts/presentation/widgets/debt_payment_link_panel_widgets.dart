import 'package:flutter/material.dart';

import '../utils/debts_ui_tokens.dart';

class DebtPaymentExpiryBadge extends StatelessWidget {
  const DebtPaymentExpiryBadge({
    super.key,
    required this.expired,
    required this.label,
  });

  final bool expired;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bg = expired ? DebtsUi.dangerSoft : DebtsUi.accentGoldSoft;
    final fg = expired ? DebtsUi.danger : DebtsUi.accentGoldInk;
    final text = expired ? 'Expired' : (label ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expired ? Icons.lock_clock_rounded : Icons.schedule_rounded,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of online-pay buttons while a debt has not yet synced (DEBT-09).
class DebtPaymentPendingSyncNotice extends StatelessWidget {
  const DebtPaymentPendingSyncNotice({
    super.key,
    required this.onSyncNow,
    required this.busy,
  });

  final VoidCallback? onSyncNow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DebtsUi.accentGoldSoft,
        borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        border: Border.all(
          color: DebtsUi.accentGoldInk.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: DebtsUi.accentGoldInk,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sync this debt before collecting online',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DebtsUi.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This debt was saved offline. QR, payment link, and MoMo prompts '
            'need it on the server first. Connect to the internet and sync to '
            'unlock online payment.',
            style: TextStyle(
              fontSize: 12,
              color: DebtsUi.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onSyncNow,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(busy ? 'Syncing…' : 'Sync now'),
            style: FilledButton.styleFrom(
              backgroundColor: DebtsUi.greenDark,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DebtPaymentMomoPushButton extends StatelessWidget {
  const DebtPaymentMomoPushButton({
    super.key,
    required this.onTap,
    required this.busy,
  });

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.phone_android_rounded, size: 16),
      label: Text(busy ? 'Preparing…' : 'Push MoMo prompt'),
      style: OutlinedButton.styleFrom(
        foregroundColor: DebtsUi.accentGold,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        ),
        side: BorderSide(color: DebtsUi.accentGold.withValues(alpha: 0.45)),
      ),
    );
  }
}
