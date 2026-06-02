import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../shared/widgets/product_image_catalog.dart';

const _sheetCapH = 10.0;
const _sheetBg   = Color(0xFFF6F8F7);

/// Static green hero that replaces the old 3-slide carousel.
/// Shows "Sales / Record today's sales" + a top-seller banner.
class SalesMockupHero extends StatelessWidget {
  const SalesMockupHero({
    super.key,
    this.topSellingItemName,
    this.topSellingQty,
    this.topSellingImageUrl,
  });

  final String? topSellingItemName;
  final int?    topSellingQty;
  final String? topSellingImageUrl;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Dark-green gradient ─────────────────────────────────────────────
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF041509), Color(0xFF083420), Color(0xFF0F5A30)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // ── Radial glow (top-right) ─────────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.78, -0.70),
              radius: 0.80,
              colors: [
                const Color(0xFF49D17B).withValues(alpha: 0.26),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // ── Content ────────────────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Record today\'s sales',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TopSellerBanner(
                    itemName: topSellingItemName,
                    qty:      topSellingQty,
                    imageUrl: topSellingImageUrl,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // ── White rounded cap baked-in so it is never viewport-clipped ──
            const SizedBox(
              height: _sheetCapH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _sheetBg,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_sheetCapH),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Top-seller frosted banner ─────────────────────────────────────────────────

class _TopSellerBanner extends StatelessWidget {
  const _TopSellerBanner({this.itemName, this.qty, this.imageUrl});

  final String? itemName;
  final int?    qty;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasData = itemName != null && (qty ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Product thumbnail in white pill
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasData && imageUrl != null
                ? ItemImage(
                    imageUrl: imageUrl,
                    size: 38,
                    fallbackIcon: LucideIcons.trophy,
                  )
                : const Icon(
                    LucideIcons.trophy,
                    size: 24,
                    color: Color(0xFF0F7A4A),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOP SELLER THIS MONTH',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasData
                      ? '${itemName!} · $qty units'
                      : 'Start selling to unlock',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            LucideIcons.trendingUp,
            color: Color(0xFF7CE0B0),
            size: 20,
          ),
        ],
      ),
    );
  }
}
