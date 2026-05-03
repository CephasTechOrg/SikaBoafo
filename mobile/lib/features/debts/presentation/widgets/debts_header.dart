import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';

/// Collapsing hero for [DebtsScreen], aligned with [ExpensesHeader] / [InventoryHeader].
class DebtsHeader extends StatelessWidget {
  const DebtsHeader({
    super.key,
    required this.leadingContentInset,
    required this.outstandingMinor,
    required this.overdueMinor,
    required this.paidThisMonthStr,
    required this.customerCount,
  });

  /// Left padding so hero text clears the sliver [leading] control.
  final double leadingContentInset;
  final int outstandingMinor;
  final int overdueMinor;
  final String paidThisMonthStr;
  final int customerCount;

  String _fmtMoney(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '₵$major.$cents';
  }

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
                Icons.account_balance_wallet_rounded,
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
                  'OUTSTANDING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtMoney(outstandingMinor),
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
                        icon: Icons.warning_amber_rounded,
                        value: _fmtMoney(overdueMinor),
                        label: 'overdue',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.savings_outlined,
                        value: '₵$paidThisMonthStr',
                        label: 'collected (mo)',
                      ),
                      const SizedBox(width: 10),
                      _StatPill(
                        icon: Icons.group_rounded,
                        value: '$customerCount',
                        label: 'customers',
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
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
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
                style: const TextStyle(
                  color: Colors.white,
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
