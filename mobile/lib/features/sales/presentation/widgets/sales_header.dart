import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../data/local/kv_cache_repository.dart';
import '../../../../shared/widgets/data_freshness_label.dart';
import '../utils/sales_ui_utils.dart';
import 'hero_stat_chip.dart';

class SalesHeader extends StatelessWidget {
  const SalesHeader({
    super.key,
    required this.todayRevenueMinor,
    required this.todayTxnsCount,
    required this.cashTotalMinor,
    required this.momoTotalMinor,
  });

  final int todayRevenueMinor;
  final int todayTxnsCount;
  final int cashTotalMinor;
  final int momoTotalMinor;

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
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.68, -0.72),
                      radius: 0.92,
                      colors: [
                        const Color(0xFF27A84E).withValues(alpha: 0.56),
                        const Color(0xFF1A7A38).withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.10, 0.0),
                      radius: 1.2,
                      colors: [
                        const Color(0xFF0D6030).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF010A04).withValues(alpha: 0.36),
                        Colors.transparent,
                        const Color(0xFF010A04).withValues(alpha: 0.12),
                      ],
                      stops: const [0.0, 0.50, 1.0],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 1.5,
                  child: ColoredBox(color: Color(0x22FFFFFF)),
                ),
              ],
            ),
          ),
          Positioned(
            right: -10,
            bottom: -8,
            child: Opacity(
              opacity: 0.42,
              child: Image.asset(
                'assets/images/sales.png',
                width: 185,
                height: 185,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.point_of_sale_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sales',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          DataFreshnessLabel(
                            kvKey: KvCacheRepository.kSalesTs,
                            color: AppColors.heroSubtitle,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "TODAY'S REVENUE",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          SalesUiUtils.formatMinor(todayRevenueMinor, symbol: '₵'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Constantia',
                            letterSpacing: -0.8,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HeroStatChip(
                        icon: Icons.receipt_long_rounded,
                        value: '$todayTxnsCount',
                        label: 'txns today',
                      ),
                      const SizedBox(width: 8),
                      HeroStatChip(
                        icon: Icons.payments_rounded,
                        value: SalesUiUtils.formatMinor(cashTotalMinor, symbol: '₵'),
                        label: 'Cash',
                      ),
                      const SizedBox(width: 8),
                      HeroStatChip(
                        icon: Icons.phone_android_rounded,
                        value: SalesUiUtils.formatMinor(momoTotalMinor, symbol: '₵'),
                        label: 'MoMo',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
