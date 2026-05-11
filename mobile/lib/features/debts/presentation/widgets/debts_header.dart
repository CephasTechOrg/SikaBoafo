import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/debts_ui_utils.dart';

/// Hero header for [DebtsScreen]. Matches CustomersHeader visual style —
/// forest gradient with radial highlight and a soft icon watermark.
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
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF041C0B),
                    Color(0xFF083A1A),
                    Color(0xFF0F5A30),
                    Color(0xFF196E3D),
                  ],
                  stops: [0.0, 0.28, 0.62, 1.0],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.68, -0.72),
                  radius: 0.92,
                  colors: [
                    const Color(0xFF27A84E).withValues(alpha: 0.40),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF010A04).withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.0,
            child: ColoredBox(color: Color(0x18FFFFFF)),
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Opacity(
              opacity: 0.14,
              child: Icon(
                Icons.handshake_rounded,
                size: 120,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(leadingContentInset, 46, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Debts',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: DataFreshnessLabel(
                        kvKey: KvCacheRepository.kDebtsTs,
                        color: AppColors.heroSubtitle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'TOTAL OUTSTANDING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DebtsUiUtils.formatMinor(outstandingMinor),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Constantia',
                    letterSpacing: -0.8,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatPill(
                        icon: Icons.receipt_long_rounded,
                        value: '$totalDebtsCount',
                        label: 'total',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.schedule_rounded,
                        value: '$openCount',
                        label: 'open',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.warning_amber_rounded,
                        value: '$overdueCount',
                        label: 'overdue',
                        accent: overdueCount > 0
                            ? const Color(0xFFF6A6A6)
                            : null,
                      ),
                    ],
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final valueColor = accent ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.55), size: 13),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
