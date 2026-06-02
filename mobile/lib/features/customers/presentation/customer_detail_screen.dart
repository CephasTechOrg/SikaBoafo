import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../debts/data/debts_repository.dart';
import '../../debts/presentation/utils/debts_ui_tokens.dart';
import '../../debts/presentation/utils/debts_ui_utils.dart';
import '../../debts/presentation/widgets/debt_customer_summary.dart';
import '../../debts/presentation/widgets/debt_list_tile.dart';
import '../../debts/presentation/widgets/debt_section_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../debts/presentation/widgets/debts_gradient_button.dart';
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

    return CustomScrollView(
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
              final err =
                  ref.read(debtsControllerProvider).valueOrNull?.lastSyncError;
              if (err != null && err.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sync paused: $err'),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: DebtsUi.pageBackground,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DebtCustomerSummary(customer: customer),
                  const SizedBox(height: 12),
                  if (_hasExtendedContact(customer))
                    DebtSectionCard(
                      title: 'Contact details',
                      icon: LucideIcons.contact,
                      child: _ContactDetails(customer: customer),
                    ),
                  if (_hasExtendedContact(customer))
                    const SizedBox(height: 12),
                  DebtSectionCard(
                    title: 'Debt history',
                    icon: LucideIcons.history,
                    countBadge: activeReceivables.length,
                    child: activeReceivables.isEmpty
                        ? const DebtSectionEmptyState(
                            icon: LucideIcons.receipt,
                            title: 'No debts yet',
                            message:
                                'Record a new debt for this customer to start '
                                'tracking repayments.',
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < activeReceivables.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                DebtListTile(
                                  record: activeReceivables[i],
                                  showCustomerName: false,
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
                  ),
                  const SizedBox(height: 18),
                  DebtsGradientButton(
                    label: 'Record new debt',
                    icon: LucideIcons.plus,
                    onPressed: () => _openNewDebt(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _hasExtendedContact(LocalDebtCustomer c) {
    return (c.email != null && c.email!.trim().isNotEmpty) ||
        (c.whatsappNumber != null && c.whatsappNumber!.trim().isNotEmpty) ||
        (c.notes != null && c.notes!.trim().isNotEmpty);
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

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.customer});

  final LocalDebtCustomer customer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (customer.email != null && customer.email!.trim().isNotEmpty)
          _InfoRow(
            icon: LucideIcons.mail,
            label: 'Email',
            value: customer.email!,
          ),
        if (customer.whatsappNumber != null &&
            customer.whatsappNumber!.trim().isNotEmpty)
          _InfoRow(
            icon: LucideIcons.messageCircle,
            label: 'WhatsApp',
            value: customer.whatsappNumber!,
          ),
        if (customer.notes != null && customer.notes!.trim().isNotEmpty)
          _InfoRow(
            icon: LucideIcons.fileText,
            label: 'Notes',
            value: customer.notes!,
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DebtsUi.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
            ),
            child: Icon(icon, size: 16, color: DebtsUi.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: DebtsUi.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: DebtsUi.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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
