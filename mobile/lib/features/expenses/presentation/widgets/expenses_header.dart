import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../../debts/presentation/widgets/hero_stat_row.dart';

/// Hero block at the top of the Expenses screen.
///
/// Matches the mockup's TitleHero pattern used by Debts/Customers/Reports.
class ExpensesHeader extends StatelessWidget {
  const ExpensesHeader({
    super.key,
    required this.monthMinor,
    required this.todayMinor,
    required this.todayEntryCount,
    required this.monthCategoryCount,
    required this.canPop,
    required this.onBack,
    required this.onRefresh,
  });

  final int monthMinor;
  final int todayMinor;
  final int todayEntryCount;
  final int monthCategoryCount;
  final bool canPop;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  String _fmtMoney(int minor) {
    final major = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '₵$major.$cents';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Background gradient
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: DebtsUi.heroGradient),
          ),
        ),
        // Glow orb top-right
        Positioned(
          top: -20,
          right: -20,
          width: 160,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        // Content
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: back button + spacer + refresh button
              Row(
                children: [
                  if (canPop)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.arrowLeft,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onRefresh,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.refreshCw,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Title
              Text(
                'Expenses',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              // Subtitle
              Text(
                'Track daily spending',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Metric label
              Text(
                'SPENT THIS MONTH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.60),
                ),
              ),
              const SizedBox(height: 3),
              // Metric value
              Text(
                _fmtMoney(monthMinor),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.5,
                  height: 1.0,
                  textStyle: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // HeroStat row
              HeroStatRow(
                items: [
                  HeroStatItem(
                    icon: LucideIcons.receipt,
                    value: _fmtMoney(todayMinor),
                    label: 'Today',
                  ),
                  HeroStatItem(
                    icon: LucideIcons.fileText,
                    value: '$todayEntryCount',
                    label: 'Entries',
                  ),
                  HeroStatItem(
                    icon: LucideIcons.layoutGrid,
                    value: '$monthCategoryCount',
                    label: 'Categories',
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
