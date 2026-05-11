import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

class DebtBalanceHero extends StatelessWidget {
  const DebtBalanceHero({
    super.key,
    required this.outstanding,
    required this.original,
    required this.paid,
    required this.dueDate,
    required this.invoiceNumber,
    required this.status,
  });

  final String outstanding;
  final String original;
  final String paid;
  final String dueDate;
  final String? invoiceNumber;
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusColor = DebtsUiUtils.statusColor(status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
        boxShadow: DebtTokens.receipt,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
        child: CustomPaint(
          foregroundPainter: const _ReceiptEdgePainter(),
          child: Container(
            decoration: BoxDecoration(
              color: DebtTokens.paper,
              border: Border.all(color: DebtTokens.paperEdge),
              borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.forest.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.forest,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receivable Statement',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Current outstanding balance',
                              style: TextStyle(
                                color: DebtTokens.paperMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          DebtsUiUtils.statusLabel(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _ReceiptDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OUTSTANDING',
                        style: TextStyle(
                          color: DebtTokens.paperMuted.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          outstanding,
                          style: const TextStyle(
                            color: DebtTokens.hero800,
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _ReceiptDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  child: Column(
                    children: [
                      _ReceiptRow(label: 'Original Amount', value: original),
                      const SizedBox(height: 12),
                      _ReceiptRow(label: 'Amount Paid', value: paid),
                      const SizedBox(height: 12),
                      _ReceiptRow(label: 'Due Date', value: dueDate),
                      if (invoiceNumber != null && invoiceNumber!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReceiptRow(
                          label: 'Invoice Number',
                          value: invoiceNumber!,
                        ),
                      ],
                    ],
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

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: DebtTokens.paperMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _DashedLinePainter(color: Color(0xFFE6DCC5)),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ReceiptEdgePainter extends CustomPainter {
  const _ReceiptEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF7ECD4);
    const notch = 7.0;
    var y = 18.0;
    while (y < size.height - 12) {
      canvas.drawCircle(Offset(0, y), notch, paint);
      canvas.drawCircle(Offset(size.width, y), notch, paint);
      y += 24;
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptEdgePainter oldDelegate) => false;
}
