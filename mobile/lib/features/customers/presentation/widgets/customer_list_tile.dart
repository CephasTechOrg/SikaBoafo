import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../debts/data/models/local_debt_customer.dart';
import '../../../debts/presentation/utils/debts_ui_utils.dart';

class CustomerListTile extends StatelessWidget {
  const CustomerListTile({
    super.key,
    required this.customer,
    required this.onTap,
  });

  final LocalDebtCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outstanding = DebtsUiUtils.amountToMinor(customer.totalOutstanding);
    final hasBalance  = outstanding > 0;

    // Initials — up to two chars
    final parts    = customer.name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : customer.name.isNotEmpty
            ? customer.name[0].toUpperCase()
            : '?';

    // Last activity display
    final activityLabel = _formatActivity(
      customer.lastActivityAtMillis ?? customer.createdAtMillis,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0A101828), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: avatar + name/phone + debt/badge + chevron ───────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF6EF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F7A4A),
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),

                    // Name + phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              height: 1.2,
                            ),
                          ),
                          if (customer.phoneNumber != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.phone,
                                  size: 14,
                                  color: Color(0xFF9AA3AF),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    customer.phoneNumber!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Amount or cleared state — no extra badge wrapper
                    if (hasBalance)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₵${customer.totalOutstanding}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFBE8A2C),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            'owing',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9AA3AF),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Regular',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F7A4A),
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: Color(0xFF9AA3AF),
                    ),
                  ],
                ),

                // ── Bottom stats row ────────────────────────────────────────
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEEF1F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: 'Total purchases',
                        value: customer.totalPurchasesFormatted != null
                            ? '₵${customer.totalPurchasesFormatted}'
                            : '₵0.00',
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFFEEF1F0)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _StatCell(
                          label: 'Last activity',
                          value: activityLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatActivity(int epochMs) {
    if (epochMs == 0) return 'Unknown';
    final dt   = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9AA3AF),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
