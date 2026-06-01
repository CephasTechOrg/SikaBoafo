import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router.dart';
import '../../../expenses/presentation/expenses_screen.dart';
import 'dashboard_mockup_ui.dart';

/// 4-button quick-action row rendered inside the hero on dark green.
class DashboardHeroQuickActions extends StatelessWidget {
  const DashboardHeroQuickActions({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_rounded,
            label: 'New Sale',
            primary: true,
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickAction(
            icon: Icons.handshake_outlined,
            label: 'Debts',
            onTap: () => context.push(AppRoute.debts.path),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'Restock',
            onTap: () => onNavigate(2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'Expenses',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primary
                      ? DashboardMockup.green600
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                  border: primary
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                  boxShadow: primary
                      ? const [
                          BoxShadow(
                            color: Color(0x73168A55),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: Colors.white, size: 23),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
