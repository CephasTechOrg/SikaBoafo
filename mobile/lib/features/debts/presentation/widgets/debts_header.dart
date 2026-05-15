import 'package:flutter/material.dart';

import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/debts_ui_tokens.dart';
import '../utils/debts_ui_utils.dart';

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
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatPill(
                      icon: Icons.receipt_long_outlined,
                      value: '$totalDebtsCount',
                      label: 'total',
                    ),
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.schedule_rounded,
                      value: '$openCount',
                      label: 'open',
                    ),
                    const SizedBox(width: 8),
                    _StatPill(
                      icon: Icons.warning_amber_rounded,
                      value: '$overdueCount',
                      label: 'overdue',
                      highlight: overdueCount > 0,
                    ),
                  ],
                ),
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight
        ? const Color(0xFFFCC8C8)
        : Colors.white.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $label',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
