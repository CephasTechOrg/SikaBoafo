import 'package:flutter/material.dart';

import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/utils/debts_ui_utils.dart';
import '../../../debts/presentation/widgets/hero_stat_row.dart';

class CustomersHeader extends StatelessWidget {
  const CustomersHeader({
    super.key,
    required this.leadingContentInset,
    required this.outstandingMinor,
    required this.customerCount,
    required this.clearedCount,
    required this.withDebtCount,
  });

  final double leadingContentInset;
  final int outstandingMinor;
  final int customerCount;
  final int clearedCount;
  final int withDebtCount;

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
          padding: EdgeInsets.fromLTRB(leadingContentInset, 50, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Customers',
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
              const SizedBox(height: 14),
              const Text(
                'TOTAL OUTSTANDING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0x8CFFFFFF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DebtsUiUtils.formatMinor(outstandingMinor),
                style: const TextStyle(
                  fontFamily: 'Constantia',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              HeroStatRow(
                items: [
                  HeroStatItem(
                    icon: Icons.groups_rounded,
                    value: '$customerCount',
                    label: 'Customers',
                  ),
                  HeroStatItem(
                    icon: Icons.check_circle_outline_rounded,
                    value: '$clearedCount',
                    label: 'Cleared',
                  ),
                  HeroStatItem(
                    icon: Icons.account_balance_wallet_outlined,
                    value: '$withDebtCount',
                    label: 'Owing',
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
