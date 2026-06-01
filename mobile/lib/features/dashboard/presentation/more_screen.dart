import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../presentation/utils/dashboard_ui_utils.dart';
import '../providers/dashboard_providers.dart';
import 'widgets/dashboard_mockup_ui.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mc = ref.watch(merchantContextProvider).valueOrNull;

    return ColoredBox(
      color: DashboardMockup.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Title section ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DashboardMockup.gutter, 14, DashboardMockup.gutter, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: DashboardMockup.ink,
                      letterSpacing: -0.64,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your business operations and settings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: DashboardMockup.ink2,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DashboardMockup.gutter, 24, DashboardMockup.gutter, 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Business profile card ──────────────────────────────
                  _BusinessCard(mc: mc),
                  const SizedBox(height: 26),

                  // ── Operations ─────────────────────────────────────────
                  const _SectionLabel('Operations'),
                  const SizedBox(height: 12),
                  _MoreRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Expenses',
                    sub: 'Track costs and daily spending',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ExpensesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _MoreRow(
                    icon: Icons.handshake_outlined,
                    title: 'Debts',
                    sub: 'Manage receivables and repayments',
                    onTap: () => context.push(AppRoute.debts.path),
                  ),
                  const SizedBox(height: 11),
                  _MoreRow(
                    icon: Icons.people_alt_outlined,
                    title: 'Customers',
                    sub: 'Client directory and history',
                    onTap: () => context.push(AppRoute.customers.path),
                  ),

                  const SizedBox(height: 26),

                  // ── Business Management ────────────────────────────────
                  const _SectionLabel('Business Management'),
                  const SizedBox(height: 12),
                  _MoreRow(
                    icon: Icons.bar_chart_rounded,
                    title: 'Reports',
                    sub: 'Deep insights into performance',
                    onTap: () => context.push(AppRoute.reports.path),
                  ),
                  const SizedBox(height: 11),
                  _MoreRow(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    sub: 'Profile, staff, and preferences',
                    onTap: () => context.push(AppRoute.settings.path),
                  ),
                ],
              ),
            ),

            // Bottom safe-area padding
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ── Business profile card ─────────────────────────────────────────────────────

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.mc});

  final dynamic mc; // MerchantContext | null

  @override
  Widget build(BuildContext context) {
    final name     = mc?.businessName as String? ?? 'My Business';
    final location = mc?.storeLocation as String?;
    final initials = DashboardUiUtils.initials(name);
    final subtitle = location != null && location.isNotEmpty
        ? '$location · Owner account'
        : 'Owner account';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F7A4A), Color(0xFF073B2A)],
        ),
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x380B4A2E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Edit button
          GestureDetector(
            onTap: () => context.push(AppRoute.settings.path),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: DashboardMockup.ink3,
      ),
    );
  }
}

// ── More row tile ─────────────────────────────────────────────────────────────

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const iconColor = DashboardMockup.green700;
    const iconBg    = DashboardMockup.greenTint;

    return Material(
      color: DashboardMockup.card,
      borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
            border: Border.all(color: DashboardMockup.lineSoft),
            boxShadow: DashboardMockup.cardShadow,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: DashboardMockup.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DashboardMockup.ink2,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DashboardMockup.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
