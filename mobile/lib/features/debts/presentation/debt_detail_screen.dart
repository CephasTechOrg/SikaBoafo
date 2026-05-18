import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/widgets/stale_banner.dart';
import '../data/models/local_debt_customer.dart';
import '../data/models/local_receivable_detail.dart';
import '../data/models/local_receivable_record.dart';
import '../providers/debt_detail_provider.dart';
import '../providers/debts_providers.dart';
import 'utils/debts_ui_tokens.dart';
import 'widgets/debt_balance_hero.dart';
import 'widgets/debt_customer_summary.dart';
import 'widgets/debt_meta_row.dart';
import 'widgets/debt_payments_history.dart';
import 'widgets/debt_reminders_section.dart';
import 'widgets/receive_payment_sheet/receive_payment_sheet.dart';

/// Pulls the latest debts snapshot from the server, invalidates the detail
/// provider, then surfaces any sync error via a SnackBar — mirroring the
/// behavior of `DebtsScreen._refresh` so failures aren't silent on detail.
Future<void> _refreshDetailFromServer(
  BuildContext context,
  WidgetRef ref,
  String receivableId,
) async {
  await ref.read(debtsControllerProvider.notifier).refreshFromServer();
  ref.invalidate(receivableDetailProvider(receivableId));
  if (!context.mounted) return;
  final err = ref.read(debtsControllerProvider).valueOrNull?.lastSyncError;
  if (err != null && err.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync paused: $err'),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

Future<void> _confirmAndCancelReceivableDebt(
  BuildContext context,
  WidgetRef ref,
  LocalReceivableRecord record,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      surfaceTintColor: Colors.transparent,
      backgroundColor: DebtsUi.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
        side: const BorderSide(color: DebtsUi.border, width: 1.5),
      ),
      title: const Text(
        'Cancel this debt?',
        style: TextStyle(
          fontFamily: 'Constantia',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: DebtsUi.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      content: const Text(
        'The debt will be marked cancelled. You can\'t undo this — '
        'create a new debt if you change your mind.',
        style: TextStyle(
          fontSize: 14,
          color: DebtsUi.textSecondary,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: DebtsUi.textSecondary),
          child: const Text('Keep debt'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DebtsUi.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Cancel debt'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(debtsControllerProvider.notifier).cancelReceivable(
          receivableId: record.receivableId,
        );
    ref.invalidate(receivableDetailProvider(record.receivableId));
    messenger.showSnackBar(
      const SnackBar(content: Text('Debt cancelled.')),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(userFriendlyError(error))),
    );
  }
}

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({required this.receivableId, super.key});

  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(receivableDetailProvider(receivableId));

    return Scaffold(
      backgroundColor: DebtsUi.pageBackground,
      body: detailAsync.when(
        loading: () => const _LoadingShell(),
        error: (error, _) => _ErrorShell(
          message: userFriendlyError(error),
          onRetry: () => ref.invalidate(receivableDetailProvider(receivableId)),
        ),
        data: (detail) {
          if (detail == null) {
            return const _MissingShell();
          }
          return _LoadedShell(detail: detail, receivableId: receivableId);
        },
      ),
    );
  }
}

/// Top-of-screen header matching `index (2).html` `.detail-header`. Renders
/// a green gradient with the back button + refresh icon and an avatar /
/// name / phone block underneath.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.customer,
    required this.onBack,
    required this.onRefresh,
    required this.canCancel,
    required this.onCancel,
  });

  final LocalDebtCustomer customer;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        customer.phoneNumber != null && customer.phoneNumber!.trim().isNotEmpty;
    final initial =
        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
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
                  if (canCancel)
                    _GlassIconButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: 'More options',
                      onTap: onCancel,
                    ),
                  if (canCancel) const SizedBox(width: 8),
                  _GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onTap: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontFamily: 'Constantia',
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          customer.name.isNotEmpty ? customer.name : 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Constantia',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                                Icons.call_rounded,
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
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 6),
            Text(
              'Debts',
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

/// Negative margin on mockup `.status-card` — card overlaps the green header
/// and must paint *above* it (`z-index: 5` in HTML).
const double _kDetailHeaderCardOverlap = 18;

/// Green hero + floating outstanding card in one sliver so scroll-body paint
/// never covers the card (mockup: card on top of header, not under it).
class _DetailHeroWithStatusCard extends StatelessWidget {
  const _DetailHeroWithStatusCard({
    required this.customer,
    required this.record,
    required this.onBack,
    required this.onRefresh,
    required this.canCancel,
    required this.onCancel,
  });

  final LocalDebtCustomer customer;
  final LocalReceivableRecord record;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailHeader(
          customer: customer,
          onBack: onBack,
          onRefresh: onRefresh,
          canCancel: canCancel,
          onCancel: onCancel,
        ),
        Transform.translate(
          offset: const Offset(0, -_kDetailHeaderCardOverlap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: const Color(0x330D3D2B),
              borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
              child: DebtBalanceHero(
                record: record,
                bridgesIntoHeader: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadedShell extends ConsumerWidget {
  const _LoadedShell({required this.detail, required this.receivableId});

  final LocalReceivableDetail detail;
  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = detail.receivable;
    final isTerminal = record.isTerminal;
    final canCancelDebt = (ref.watch(isMerchantOwnerProvider).valueOrNull ?? true) && !isTerminal;

    return CustomScrollView(
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _DetailHeroWithStatusCard(
            customer: detail.customer,
            record: record,
            onBack: () => context.pop(),
            onRefresh: () =>
                _refreshDetailFromServer(context, ref, receivableId),
            canCancel: canCancelDebt,
            onCancel: () =>
                _confirmAndCancelReceivableDebt(context, ref, record),
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
                  const StaleBanner(
                    screenKey: 'debt_detail',
                    kvKey: KvCacheRepository.kDebtsTs,
                  ),
                  const SizedBox(height: 12),
                  DebtMetaRow(record: record),
                  const SizedBox(height: 12),
                  DebtCustomerSummary(customer: detail.customer),
                  const SizedBox(height: 12),
                  DebtRemindersSection(
                    record: record,
                    customerName: detail.customer.name,
                  ),
                  const SizedBox(height: 12),
                  DebtPaymentsHistory(payments: detail.payments),
                  if (!isTerminal) ...[
                    const SizedBox(height: 18),
                    _ReceivePaymentCta(
                      onTap: () => _handleReceivePayment(context, record),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleReceivePayment(
    BuildContext context,
    LocalReceivableRecord record,
  ) async {
    await showReceivePaymentSheet(context, record: record);
  }
}

class _ReceivePaymentCta extends StatelessWidget {
  const _ReceivePaymentCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: DebtsUi.ctaGradient,
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59166B42),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Receive Payment',
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
                    border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
                    boxShadow: DebtsUi.shadowNeutralSm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
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
        Expanded(
          child: ColoredBox(
            color: DebtsUi.pageBackground,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: DebtsUi.surface,
                    borderRadius: BorderRadius.circular(DebtsUi.radiusLg),
                    border: Border.all(color: DebtsUi.borderNeutral, width: 1.5),
                    boxShadow: DebtsUi.shadowNeutralSm,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 42,
                        color: DebtsUi.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'This debt is no longer available. It may have been '
                        'removed from another device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DebtsUi.textSecondary),
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
