import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/product_image_catalog.dart';
import '../../data/inventory_repository.dart';

class InventoryItemCard extends StatelessWidget {
  const InventoryItemCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final LocalInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasThreshold = item.lowStockThreshold != null;
    final bool isLow = hasThreshold && item.quantityOnHand <= item.lowStockThreshold!;
    final bool isOut = item.quantityOnHand <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF1F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0A101828), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Thumbnail ─────────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFF6F8F7),
                    child: ItemImage(
                      imageUrl: item.imageUrl,
                      size: 52,
                      fallbackIcon: Icons.inventory_2_outlined,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 13),

                // ── Name + category + SKU ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row + badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!item.isActive) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              label: 'Archived',
                              bg: Color(0xFFFBECEC),
                              fg: Color(0xFFD23B3B),
                            ),
                          ] else if (isOut) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              label: 'Out',
                              bg: Color(0xFFFBECEC),
                              fg: Color(0xFFD23B3B),
                              dot: true,
                            ),
                          ] else if (isLow) ...[
                            const SizedBox(width: 6),
                            const _Badge(
                              label: 'Low',
                              bg: Color(0xFFFAF3E1),
                              fg: Color(0xFFBE8A2C),
                              dot: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Category badge + SKU
                      Row(
                        children: [
                          if (item.category != null) ...[
                            _CatBadge(label: item.category!),
                            const SizedBox(width: 7),
                          ],
                          if (item.sku != null)
                            Text(
                              item.sku!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF9AA3AF),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Price + stock pill ────────────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₵${item.defaultPrice}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F7A4A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
                      decoration: BoxDecoration(
                        color: isOut
                            ? const Color(0xFFFBECEC)
                            : isLow
                                ? const Color(0xFFFAF3E1)
                                : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${item.quantityOnHand} units',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOut
                              ? const Color(0xFFD23B3B)
                              : isLow
                                  ? const Color(0xFFBE8A2C)
                                  : const Color(0xFF6B7280),
                          fontFeatures: const [FontFeature.tabularFigures()],
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
}

// ── Inline badge ──────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
    this.dot = false,
  });
  final String label;
  final Color bg;
  final Color fg;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 7, 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category badge ────────────────────────────────────────────────────────────

class _CatBadge extends StatelessWidget {
  const _CatBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F7A4A),
        ),
      ),
    );
  }
}
