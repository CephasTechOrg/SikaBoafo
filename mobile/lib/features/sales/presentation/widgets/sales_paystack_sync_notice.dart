import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Shown in checkout when cart items must sync before Paystack QR/link/MoMo pay.
class SalesPaystackPendingSyncNotice extends StatelessWidget {
  const SalesPaystackPendingSyncNotice({
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
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Items must sync before online payment',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Some products in this sale are still on this device only. '
            'Sync them first so Paystack can collect payment.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onSyncNow,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(busy ? 'Syncing…' : 'Sync now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
