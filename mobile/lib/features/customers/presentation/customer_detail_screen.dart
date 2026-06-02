import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../debts/presentation/utils/debts_ui_utils.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../debts/presentation/widgets/debt_customer_summary.dart';

import '../../debts/presentation/widgets/new_debt_sheet/new_debt_sheet.dart';
import '../../debts/providers/debts_providers.dart';
import 'widgets/customer_balance_hero.dart';

final _customerDetailProvider =
    FutureProvider.family<_CustomerDetailViewData, String>(
  (ref, customerId) async {
    ref.watch(debtsControllerProvider);
    final repo = ref.read(debtsRepositoryProvider);
    final customer = await repo.getCustomerById(customerId);
    final receivables = await repo.listReceivablesForCustomer(customerId);
    return _CustomerDetailViewData(
      customer: customer,
      receivables: receivables,
    );
  },
);

class _CustomerDetailViewData {
  const _CustomerDetailViewData({
    required this.customer,
    required this.receivables,
  });

  final LocalDebtCustomer? customer;
  final List<LocalReceivableRecord> receivables;
}

const double _kHeaderCardOverlap = 18;

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_customerDetailProvider(customerId));

    return Scaffold(
      backgroundColor: DebtsUi.pageBackground,
      body: detailAsync.when(
        loading: () => const _LoadingShell(),
        error: (error, _) => _ErrorShell(
          message: userFriendlyError(error),
          onRetry: () => ref.invalidate(_customerDetailProvider(customerId)),
        ),
        data: (data) {
          final customer = data.customer;
          if (customer == null) {
            return const _MissingShell();
          }
          return _LoadedShell(
            customer: customer,
            receivables: data.receivables,
            customerId: customerId,
          );
        },
      ),
    );
  }
}

class _LoadedShell extends ConsumerWidget {
  const _LoadedShell({
    required this.customer,
    required this.receivables,
    required this.customerId,
  });

  final LocalDebtCustomer customer;
  final List<LocalReceivableRecord> receivables;
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstandingMinor = DebtsUiUtils.customerOutstandingMinor(
      customerId,
      receivables,
    );
    final openCount = receivables
        .where((r) => r.status == 'open' || r.status == 'partially_paid')
        .length;
    final activeReceivables = receivables
        .where((r) => r.status != 'cancelled')
        .toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            clipBehavior: Clip.none,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DetailHeroWithSummaryCard(
                  customer: customer,
                  outstandingMinor: outstandingMinor,
                  openDebtCount: openCount,
                  totalDebtCount: activeReceivables.length,
                  onBack: () => context.pop(),
                  onRefresh: () async {
                    await ref
                        .read(debtsControllerProvider.notifier)
                        .refreshFromServer(userInitiated: true);
                    ref.invalidate(_customerDetailProvider(customerId));
                    if (!context.mounted) return;
                    final err = ref
                        .read(debtsControllerProvider)
                        .valueOrNull
                        ?.lastSyncError;
                    if (err != null && err.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Sync paused: $err'),
                        duration: const Duration(seconds: 4),
                      ));
                    }
                  },
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: DebtsUi.pageBackground,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DebtCustomerSummary(customer: customer),
                        const SizedBox(height: 20),
                        // ── Debt history section header (mockup .sec-head) ──
                        Row(
                          children: [
                            const Icon(LucideIcons.history,
                                size: 16, color: DebtsUi.greenMid),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'Debt history',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: DebtsUi.textPrimary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (activeReceivables.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${activeReceivables.length}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (activeReceivables.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No debts yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: DebtsUi.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0;
                                  i < activeReceivables.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _HistoryTile(
                                  record: activeReceivables[i],
                                  customerInitials: _initials(customer.name),
                                  onTap: () {
                                    final path = AppRoute.debtDetail.path
                                        .replaceFirst(
                                      ':id',
                                      activeReceivables[i].receivableId,
                                    );
                                    context.push(path);
                                  },
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _PinnedNewDebtBar(onTap: () => _openNewDebt(context, ref)),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<void> _openNewDebt(BuildContext context, WidgetRef ref) async {
    final view = ref.read(debtsControllerProvider).valueOrNull;
    final customers = view?.customers ?? [customer];
    await showNewDebtSheet(
      context,
      customers: customers,
      preselectedCustomer: customer,
    );
    ref.invalidate(_customerDetailProvider(customerId));
  }
}

/// Debt history card on the customer detail screen.
/// Matches the mockup's compact `.card` with a rounded-square avatar,
/// invoice + date left, amount + status badge right, and a chevron.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.customerInitials,
    required this.onTap,
  });

  final LocalReceivableRecord record;
  final String customerInitials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSettled = record.status == 'settled';
    final isOverdue = !isSettled &&
        record.status != 'cancelled' &&
        DebtsUiUtils.isOverdue(record.dueDateIso);
    final isPartial = record.status == 'partially_paid';

    // Avatar colors — rounded square, status-tinted
    final Color avatarBg;
    final Color avatarFg;
    if (isOverdue) {
      avatarBg = const Color(0xFFFBECEC);
      avatarFg = const Color(0xFFD23B3B);
    } else if (isSettled) {
      avatarBg = const Color(0xFFEBF4EF);
      avatarFg = const Color(0xFF2F7D58);
    } else if (isPartial) {
      avatarBg = const Color(0xFFFAF3E1);
      avatarFg = const Color(0xFFBE8A2C);
    } else {
      avatarBg = const Color(0xFFF1F3F5);
      avatarFg = const Color(0xFF6B7280);
    }

    // Badge
    final String badgeLabel;
    final Color badgeBg;
    final Color badgeFg;
    if (isOverdue) {
      badgeLabel = 'Overdue';
      badgeBg = const Color(0xFFFBECEC);
      badgeFg = const Color(0xFFD23B3B);
    } else if (isSettled) {
      badgeLabel = 'Paid';
      badgeBg = const Color(0xFFEBF4EF);
      badgeFg = const Color(0xFF2F7D58);
    } else if (isPartial) {
      badgeLabel = 'Partial';
      badgeBg = const Color(0xFFFAF3E1);
      badgeFg = const Color(0xFFBE8A2C);
    } else {
      badgeLabel = 'Unpaid';
      badgeBg = const Color(0xFFF1F3F5);
      badgeFg = const Color(0xFF6B7280);
    }

    final invoice = (record.invoiceNumber?.isNotEmpty ?? false)
        ? record.invoiceNumber!
        : '—';
    final date = record.dueDateIso != null && record.dueDateIso!.isNotEmpty
        ? DebtsUiUtils.formatDueLabel(record.dueDateIso!)
        : DebtsUiUtils.formatDueLabel(
            DateTime.fromMillisecondsSinceEpoch(record.createdAtMillis)
                .toIso8601String()
                .substring(0, 10),
          );
    final amount = DebtsUiUtils.formatAmount(record.outstandingAmount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEEF1F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x0A101828),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rounded-square avatar (matches mockup history card)
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  customerInitials,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: avatarFg,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              // Invoice + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      invoice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Amount + badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: isSettled
                          ? const Color(0xFF9AA3AF)
                          : const Color(0xFF111827),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: Color(0xFF9AA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeroWithSummaryCard extends StatelessWidget {
  const _DetailHeroWithSummaryCard({
    required this.customer,
    required this.outstandingMinor,
    required this.openDebtCount,
    required this.totalDebtCount,
    required this.onBack,
    required this.onRefresh,
  });

  final LocalDebtCustomer customer;
  final int outstandingMinor;
  final int openDebtCount;
  final int totalDebtCount;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CustomerDetailHeader(
          customer: customer,
          onBack: onBack,
          onRefresh: onRefresh,
        ),
        Transform.translate(
          offset: const Offset(0, -_kHeaderCardOverlap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: const Color(0x330D3D2B),
              borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
              child: CustomerBalanceHero(
                outstandingMinor: outstandingMinor,
                openDebtCount: openDebtCount,
                totalDebtCount: totalDebtCount,
                bridgesIntoHeader: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerDetailHeader extends StatelessWidget {
  const _CustomerDetailHeader({
    required this.customer,
    required this.onBack,
    required this.onRefresh,
  });

  final LocalDebtCustomer customer;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasPhone = customer.phoneNumber != null &&
        customer.phoneNumber!.trim().isNotEmpty;
    final parts   = customer.name.trim().split(RegExp(r'\s+'));
    final initial = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : customer.name.isNotEmpty
            ? customer.name[0].toUpperCase()
            : '?';
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: DebtsUi.heroGradient),
          ),
        ),
        const Positioned(
          top: -40,
          right: -30,
          width: 160,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x0AFFFFFF),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BackButton(onTap: onBack),
                  const Spacer(),
                  _GlassIconButton(
                    icon: LucideIcons.refreshCw,
                    tooltip: 'Refresh',
                    onTap: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name.isNotEmpty
                              ? customer.name
                              : 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                        ),
                        if (hasPhone) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                LucideIcons.phone,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                customer.phoneNumber!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowLeft,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 6),
            Text(
              'Customers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Pinned "Record new debt" bar at the bottom — always visible, no scroll needed.
/// Mirrors the mockup's fixed `.bottom-bar` on the customer detail screen.
class _PinnedNewDebtBar extends StatelessWidget {
  const _PinnedNewDebtBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DebtsUi.surface,
        border: Border(top: BorderSide(color: DebtsUi.borderNeutral)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: DebtsUi.ctaGradient,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40166B42),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Record new debt',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          height: topInset + 130,
          decoration: const BoxDecoration(gradient: DebtsUi.heroGradient),
        ),
        const Expanded(
          child: ColoredBox(
            color: DebtsUi.pageBackground,
            child: Center(
              child: CircularProgressIndicator(color: DebtsUi.greenMid),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorShell extends StatelessWidget {
  const _ErrorShell({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          height: topInset + 130,
          decoration: const BoxDecoration(gradient: DebtsUi.heroGradient),
        ),
        Expanded(
          child: ColoredBox(
            color: DebtsUi.pageBackground,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: DebtsUi.surface,
                    borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
                    border:
                        Border.all(color: DebtsUi.borderNeutral, width: 1.5),
                    boxShadow: DebtsUi.shadowNeutralSm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 42,
                        color: DebtsUi.danger,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: DebtsUi.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DebtsUi.greenMid,
                        ),
                        onPressed: onRetry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingShell extends StatelessWidget {
  const _MissingShell();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          height: topInset + 130,
          decoration: const BoxDecoration(gradient: DebtsUi.heroGradient),
        ),
        const Expanded(
          child: ColoredBox(
            color: DebtsUi.pageBackground,
            child: Center(
              child: Text(
                'Customer not found.',
                style: TextStyle(color: DebtsUi.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
