import 'package:flutter/material.dart';

import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';
import 'hero_stat_row.dart';

/// Hero block at the top of the Debts list.
///
/// Visual reference: `index (2).html` → `.debts-header`. Uses the mockup's
/// green gradient with two soft "orb" highlights, a serif outstanding total,
/// and a single-line stat-pill row.
class DebtsHeader extends StatelessWidget {
  const DebtsHeader({
    super.key,
    required this.leadingContentInset,
    required this.outstandingMinor,
    required this.totalDebtsCount,
    required this.openCount,
    required this.overdueCount,
  });

  final double leadingContentInset;
  final int outstandingMinor;
  final int totalDebtsCount;
  final int openCount;
  final int overdueCount;

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
        Padding(
          padding: EdgeInsets.fromLTRB(leadingContentInset, 50, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Debts',
                    style: TextStyle(
                      fontFamily: 'Constantia',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(width: 10),
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: DataFreshnessLabel(
                      kvKey: KvCacheRepository.kDebtsTs,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _OutstandingLabel(),
              const SizedBox(height: 4),
              Text(
                DebtsUiUtils.formatMinor(outstandingMinor),
                style: const TextStyle(
                  fontFamily: 'Constantia',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              HeroStatRow(
                items: [
                  HeroStatItem(
                    icon: Icons.receipt_long_outlined,
                    value: '$totalDebtsCount',
                    label: 'Total',
                  ),
                  HeroStatItem(
                    icon: Icons.schedule_rounded,
                    value: '$openCount',
                    label: 'Open',
                  ),
                  HeroStatItem(
                    icon: Icons.warning_amber_rounded,
                    value: '$overdueCount',
                    label: 'Overdue',
                    accentColor: overdueCount > 0
                        ? const Color(0xFFFFD4A8)
                        : null,
                  ),
                ],
              ),
            ],
          ),
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
