import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/debts_ui_tokens.dart';

/// Collapsing hero for [DebtsScreen].
class DebtsHeader extends StatelessWidget {
  const DebtsHeader({
    super.key,
    required this.leadingContentInset,
    required this.outstandingMinor,
    required this.overdueMinor,
    required this.paidThisMonthStr,
    required this.customerCount,
  });

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
    return Stack(
      children: [
        // Base gradient — simplified to 3 clean tones
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: DebtTokens.heroGradient),
          ),
        ),
        // Subtle radial highlight — top-right corner only
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.72, -0.65),
                radius: 0.75,
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Top separator line
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 1,
          child: ColoredBox(color: Color(0x14FFFFFF)),
        ),
        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(leadingContentInset, 46, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Screen title + freshness
              Row(
                children: [
                  Text(
                    'Debts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: const DataFreshnessLabel(
                      kvKey: KvCacheRepository.kDebtsTs,
                      color: AppColors.heroSubtitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Outstanding label
              Text(
                'OUTSTANDING',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              // Big amount
              Text(
                _fmtMoney(outstandingMinor),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Constantia',
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              // Three metric pills — horizontal row
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: DebtTokens.danger,
                      value: _fmtMoney(overdueMinor),
                      label: 'Overdue',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.savings_outlined,
                      iconColor: const Color(0xFF6EE7B7),
                      value: '₵$paidThisMonthStr',
                      label: 'Collected (mo)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.group_rounded,
                      iconColor: const Color(0xFF93C5FD),
                      value: '$customerCount',
                      label: 'Customers',
                    ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
