import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/widgets/product_image_catalog.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../providers/sales_cart_provider.dart';

class ReviewSaleSheet extends ConsumerWidget {
  const ReviewSaleSheet({
    super.key,
    required this.items,
    required this.onProceedToCheckout,
    required this.noteController,
    required this.calculateTotal,
    required this.formatMajor,
    required this.formatMinor,
    required this.moneyToMinor,
  });

  final List<LocalInventoryItem> items;
  final VoidCallback onProceedToCheckout;
  final TextEditingController noteController;
  final String Function(List<LocalInventoryItem>) calculateTotal;
  final String Function(String value, {String symbol}) formatMajor;
  final String Function(int minor, {String symbol}) formatMinor;
  final int Function(String value) moneyToMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemById    = {for (final item in items) item.id: item};
    final cartState   = ref.watch(salesCartProvider);
    final entries     = cartState.qtyByItemId.entries
        .where((e) => e.value > 0 && itemById.containsKey(itemIdFromKey(e.key)))
        .toList();
    final currentCount = entries.fold(0, (s, e) => s + e.value);
    final currentTotal = calculateTotal(items);
    final hasItems     = currentCount > 0;
    final viewBottom   = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + viewBottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F101828),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Grip ───────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF6EF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF0F7A4A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Review',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            '$currentCount ${currentCount == 1 ? 'item' : 'items'} · ${formatMajor(currentTotal, symbol: '₵')}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF6B7280),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Scrollable body ─────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item rows
                        if (hasItems)
                          ...entries.map((entry) {
                            final item  = itemById[itemIdFromKey(entry.key)]!;
                            final qty   = entry.value;
                            final price = cartState.priceOverrideByItemId[entry.key]
                                ?? item.defaultPrice;
                            final lineTotal = moneyToMinor(price) * qty;

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFEEF1F0)),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: ItemImage(
                                      imageUrl: item.imageUrl,
                                      size: 46,
                                      fallbackIcon: Icons.inventory_2_outlined,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + stepper
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        _ReviewStepper(
                                          qty: qty,
                                          onMinus: () => ref
                                              .read(salesCartProvider.notifier)
                                              .decrementItem(entry.key),
                                          onPlus: () => ref
                                              .read(salesCartProvider.notifier)
                                              .incrementQty(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Price + remove
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatMinor(lineTotal, symbol: '₵'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () => ref
                                            .read(salesCartProvider.notifier)
                                            .removeItem(entry.key),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.close_rounded,
                                              size: 13,
                                              color: Color(0xFF9AA3AF),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Remove',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF9AA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          })
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Color(0xFF9AA3AF),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Cart is empty',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF9AA3AF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Total block ─────────────────────────────────────
                        if (hasItems) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF6EF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        '$currentCount ${currentCount == 1 ? 'item' : 'items'} · Cash payment',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatMajor(currentTotal, symbol: '₵'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F7A4A),
                                    letterSpacing: -0.3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Note field ──────────────────────────────────────
                        const SizedBox(height: 14),
                        Text(
                          'Note',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(14, 14, 0, 0),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  size: 18,
                                  color: Color(0xFF9AA3AF),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: noteController,
                                  maxLines: 3,
                                  maxLength: 500,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    color: const Color(0xFF111827),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add a note for this sale…',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      color: const Color(0xFF9AA3AF),
                                    ),
                                    contentPadding: const EdgeInsets.fromLTRB(
                                        10, 12, 14, 12),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    counterStyle:
                                        const TextStyle(fontSize: 9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),

                // ── Action buttons ──────────────────────────────────────────
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Keep editing'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: hasItems
                            ? () {
                                Navigator.of(context).pop();
                                onProceedToCheckout();
                              }
                            : null,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Proceed to checkout'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7A4A),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
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

// ── Inline stepper used inside the review sheet rows ─────────────────────────

class _ReviewStepper extends StatelessWidget {
  const _ReviewStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF073B2A),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onMinus,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text(
                  '−',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Center(
              child: Text(
                '$qty',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(Icons.add_rounded, size: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
