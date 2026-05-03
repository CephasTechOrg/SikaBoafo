import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/sales_repository.dart';
import '../utils/sales_ui_utils.dart';

enum SaleAction { edit, voidSale }

class RecentSaleTile extends ConsumerWidget {
  const RecentSaleTile({
    super.key,
    required this.sale,
    required this.onEdit,
    required this.onVoid,
  });

  final LocalSaleRecord sale;
  final VoidCallback onEdit;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAtMillis);
    final voidedAt = sale.voidedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(sale.voidedAtMillis!);
    final syncColor = switch (sale.syncStatus) {
      'applied' || 'duplicate' => AppColors.success,
      'failed' => AppColors.danger,
      'conflict' => AppColors.warning,
      _ => AppColors.muted,
    };

    final dateFmt = DateFormat('MMM d');
    final timeFmt = DateFormat('h:mm a');
    final effectiveTime = (voidedAt ?? dt).toLocal();
    final paymentLabel = SalesUiUtils.paymentLabel(sale.paymentMethodLabel);
    final statusLabel = sale.isVoided
        ? 'Voided'
        : switch (sale.syncStatus) {
            'applied' || 'duplicate' => 'Synced',
            'failed' => 'Needs attention',
            'conflict' => 'Conflict',
            _ => 'Pending sync',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: sale.isVoided
            ? const Color(0xFFF8F6F6)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: sale.isVoided
              ? AppColors.danger.withValues(alpha: 0.16)
              : AppColors.border,
        ),
        boxShadow: sale.isVoided ? AppShadows.subtle : AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sale.isVoided
                        ? AppColors.dangerSoft
                        : AppColors.forest.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    sale.isVoided
                        ? Icons.block_rounded
                        : Icons.receipt_long_rounded,
                    color: sale.isVoided ? AppColors.danger : AppColors.forest,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₵${sale.totalAmount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: sale.isVoided ? AppColors.inkSoft : AppColors.ink,
                          decoration: sale.isVoided
                              ? TextDecoration.lineThrough
                              : null,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            label: paymentLabel,
                            icon: sale.paymentMethodLabel == 'mobile_money'
                                ? Icons.phone_android_rounded
                                : Icons.payments_rounded,
                            tint: sale.isVoided
                                ? AppColors.muted
                                : AppColors.forest,
                          ),
                          _MetaPill(
                            label:
                                '${dateFmt.format(effectiveTime)} • ${timeFmt.format(effectiveTime)}',
                            icon: Icons.schedule_rounded,
                            tint: AppColors.inkSoft,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!sale.isVoided)
                  PopupMenuButton<SaleAction>(
                    tooltip: 'Sale actions',
                    onSelected: (SaleAction action) {
                      if (action == SaleAction.edit) {
                        onEdit();
                      } else {
                        onVoid();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<SaleAction>(
                        value: SaleAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit sale'),
                        ),
                      ),
                      PopupMenuItem<SaleAction>(
                        value: SaleAction.voidSale,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Void sale'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SyncBadge(
                  label: statusLabel,
                  color: sale.isVoided ? AppColors.danger : syncColor,
                ),
                const Spacer(),
                Text(
                  sale.isVoided ? 'Sale disabled' : 'Recorded sale',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            if (sale.isVoided && sale.voidReason != null && sale.voidReason!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Reason: ${sale.voidReason!.trim()}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                  height: 1.35,
                ),
              ),
            ] else if (!sale.isVoided && sale.note != null && sale.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  sale.note!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.icon,
    required this.tint,
  });

  final String label;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tint == AppColors.inkSoft ? AppColors.inkSoft : tint,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
