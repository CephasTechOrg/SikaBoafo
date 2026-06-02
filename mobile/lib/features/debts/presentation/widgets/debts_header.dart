import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';
import 'hero_stat_row.dart';

/// Hero block at the top of the Debts list.
///
/// Visual reference: `debts UI mockup` → `.debts-header`. Uses the mockup's
/// green gradient with two soft "orb" highlights, a serif outstanding total,
/// and a single-line stat-pill row.
class DebtsHeader extends StatelessWidget {
  const DebtsHeader({
    super.key,
    required this.leadingContentInset,
    required this.outstandingMinor,
    required this.owingCount,
    required this.overdueCount,
    required this.collectedFormatted,
  });

  final double leadingContentInset;
  final int outstandingMinor;
  final int owingCount;
  final int overdueCount;
  final String collectedFormatted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: DebtsUi.heroGradient),
        ),
        const Positioned(
          top: -40,
          right: -40,
          width: 200,
          height: 200,
          child: _HeroOrb(opacity: 0.04),
        ),
        const Positioned(
          bottom: -60,
          left: 40,
          width: 140,
          height: 140,
          child: _HeroOrb(opacity: 0.03),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // FlexibleSpaceBar shrinks while scrolling; fixed padding caused
            // bottom overflow in widget tests and on short expanded heights.
            final compact =
                constraints.hasBoundedHeight && constraints.maxHeight < 175;
            final topPad = compact ? 36.0 : 44.0;
            final bottomPad = compact ? 8.0 : 14.0;
            final sectionGap = compact ? 8.0 : 12.0;
            final statsGap = compact ? 6.0 : 8.0;
            final amountSize = compact ? 30.0 : 36.0;

            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debts',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Text(
                          'Receivables · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xB3FFFFFF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        DataFreshnessLabel(
                          kvKey: KvCacheRepository.kDebtsTs,
                          color: Color(0xB3FFFFFF),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: sectionGap),
                const _OutstandingLabel(),
                const SizedBox(height: 4),
                Text(
                  DebtsUiUtils.formatMinor(outstandingMinor),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: amountSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: statsGap),
                HeroStatRow(
                  items: [
                    HeroStatItem(
                      icon: LucideIcons.users,
                      value: '$owingCount',
                      label: 'Owing',
                    ),
                    HeroStatItem(
                      icon: LucideIcons.alertTriangle,
                      value: '$overdueCount',
                      label: 'Overdue',
                      accentColor: overdueCount > 0
                          ? const Color(0xFFFFD4A8)
                          : null,
                    ),
                    HeroStatItem(
                      icon: LucideIcons.trendingUp,
                      value: collectedFormatted,
                      label: 'Collected',
                    ),
                  ],
                ),
              ],
            );

            final padded = Padding(
              padding: EdgeInsets.fromLTRB(
                leadingContentInset,
                topPad,
                20,
                bottomPad,
              ),
              child: content,
            );

            if (!compact) {
              return padded;
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(leadingContentInset, topPad, 20, bottomPad),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth - leadingContentInset - 20,
                  child: content,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HeroOrb extends StatelessWidget {
  const _HeroOrb({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _OutstandingLabel extends StatelessWidget {
  const _OutstandingLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'TOTAL OUTSTANDING',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.white.withValues(alpha: 0.55),
      ),
    );
  }
}
