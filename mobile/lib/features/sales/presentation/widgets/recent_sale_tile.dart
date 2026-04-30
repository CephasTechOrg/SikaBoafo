import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/sales_repository.dart';
import 'sale_status_pill.dart';

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

    final fmt = DateFormat('MMM d, HH:mm');
    final subtitle = sale.isVoided
        ? 'Voided${sale.voidReason == null ? '' : ' | ${sale.voidReason}'} '
            '| ${fmt.format((voidedAt ?? dt).toLocal())}'
        : '${_paymentLabel(sale.paymentMethodLabel)} | ${fmt.format(dt.toLocal())}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sale.isVoided
                    ? AppColors.dangerSoft
                    : AppColors.forest.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                sale.isVoided
                    ? Icons.block_rounded
                    : Icons.receipt_long_rounded,
                color: sale.isVoided ? AppColors.danger : AppColors.forest,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '₵${sale.totalAmount}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            decoration: sale.isVoided
                                ? TextDecoration.lineThrough
                                : null,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SaleStatusPill(
                        label: sale.isVoided ? 'Voided' : sale.syncStatus,
                        color: sale.isVoided ? AppColors.danger : syncColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!sale.isVoided) ...[
              const SizedBox(width: 4),
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
          ],
        ),
      ),
    );
  }

  String _paymentLabel(String raw) {
    return switch (raw) {
      'mobile_money' => 'Mobile Money',
      'bank_transfer' => 'Bank Transfer',
      _ => 'Cash',
    };
  }
}
