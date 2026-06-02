import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';

const _sheetCapH = 10.0;
const _sheetBg   = Color(0xFFF6F8F7);

/// Static green hero for the Inventory screen — replaces the old carousel.
/// Shows "Inventory" + freshness label + refresh button + two stat tiles.
class InventoryMockupHero extends ConsumerWidget {
  const InventoryMockupHero({
    super.key,
    required this.activeItemsCount,
    required this.lowStockCount,
    required this.onRefresh,
  });

  final int activeItemsCount;
  final int lowStockCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        // ── Radial glow ─────────────────────────────────────────────────────
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.80, -0.65),
              radius: 0.82,
              colors: [
                const Color(0xFF49D17B).withValues(alpha: 0.24),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // ── Content ─────────────────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row ───────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            DataFreshnessLabel(
                              kvKey: KvCacheRepository.kInventoryTs,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      _HeroBtn(
                        icon: LucideIcons.refreshCw,
                        onTap: onRefresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // ── Stat tiles ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          icon: LucideIcons.package,
                          value: '$activeItemsCount',
                          label: 'Active items',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroStat(
                          icon: LucideIcons.alertTriangle,
                          value: '$lowStockCount',
                          label: 'Low stock',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            // ── White rounded cap ───────────────────────────────────────────
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

// ── Hero icon button ──────────────────────────────────────────────────────────

class _HeroBtn extends StatelessWidget {
  const _HeroBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
