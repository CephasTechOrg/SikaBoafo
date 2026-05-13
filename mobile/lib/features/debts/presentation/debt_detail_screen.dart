import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../data/models/local_receivable_detail.dart';
import '../data/models/local_receivable_record.dart';
import '../providers/debt_detail_provider.dart';
import '../providers/debts_providers.dart';
import 'widgets/debt_balance_hero.dart';
import 'widgets/debt_customer_summary.dart';
import 'widgets/debt_meta_row.dart';
import 'widgets/debt_payment_link_panel.dart';
import 'widgets/debt_payments_history.dart';
import 'widgets/debt_reminders_section.dart';
import 'widgets/receive_payment_sheet/receive_payment_sheet.dart';

Future<void> _confirmAndCancelReceivableDebt(
  BuildContext context,
  WidgetRef ref,
  LocalReceivableRecord record,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel this debt?'),
      content: const Text(
        'The debt will be marked cancelled. You can\'t undo this — '
        'create a new debt if you change your mind.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep debt'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
          ),
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

  static const double _kLeadingGutter = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(receivableDetailProvider(receivableId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            stretch: true,
            leadingWidth: _kLeadingGutter,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                onPressed: () async {
                  await ref
                      .read(debtsControllerProvider.notifier)
                      .refreshFromServer();
                  ref.invalidate(receivableDetailProvider(receivableId));
                },
              ),
              if (detailAsync.valueOrNull != null &&
                  !detailAsync.valueOrNull!.receivable.isTerminal)
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  color: AppColors.surface,
                  onSelected: (value) {
                    if (value == 'cancel') {
                      _confirmAndCancelReceivableDebt(
                        context,
                        ref,
                        detailAsync.valueOrNull!.receivable,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'cancel',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.block_rounded,
                          color: AppColors.danger,
                          size: 22,
                        ),
                        title: Text(
                          'Cancel debt',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            backgroundColor: const Color(0xFF041C0B),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _DetailHeaderBackground(
                title: detailAsync.valueOrNull?.customer.name ?? 'Debt',
                invoiceNumber:
                    detailAsync.valueOrNull?.receivable.invoiceNumber,
              ),
              title: innerBoxIsScrolled
                  ? Text(
                      detailAsync.valueOrNull?.customer.name ?? 'Debt',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    )
                  : null,
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: _kLeadingGutter,
                bottom: 16,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: ColoredBox(
              color: Color(0xFF041C0B),
              child: SizedBox(height: 16),
            ),
          ),
        ],
        body: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: detailAsync.when(
            loading: () => const _LoadingBody(),
            error: (error, _) => _ErrorBody(
              message: userFriendlyError(error),
              onRetry: () =>
                  ref.invalidate(receivableDetailProvider(receivableId)),
            ),
            data: (detail) {
              if (detail == null) {
                return const _MissingBody();
              }
              return _LoadedBody(detail: detail);
            },
          ),
        ),
      ),
    );
  }
}

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.detail});

  final LocalReceivableDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = detail.receivable;
    final isTerminal = record.isTerminal;
    return ColoredBox(
      color: const Color(0xFF041C0B),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.surface),
          child: RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () async {
              await ref.read(debtsControllerProvider.notifier).refreshFromServer();
              ref.invalidate(receivableDetailProvider(record.receivableId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                DebtBalanceHero(record: record),
                const SizedBox(height: 14),
                DebtCustomerSummary(customer: detail.customer),
                const SizedBox(height: 14),
                DebtMetaRow(record: record),
                const SizedBox(height: 22),
                if (!isTerminal) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _handleReceivePayment(context, record),
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text('Receive payment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestDark,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        collapsedShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        title: const Text(
                          'Collect online',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: const Text(
                          'Link, QR, or MoMo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          8,
                          0,
                          8,
                          10,
                        ),
                        children: [
                          DebtPaymentLinkPanel(
                            record: record,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                DebtRemindersSection(
                  record: record,
                  customerName: detail.customer.name,
                ),
                const SizedBox(height: 22),
                DebtPaymentsHistory(payments: detail.payments),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReceivePayment(
    BuildContext context,
    LocalReceivableRecord record,
  ) async {
    await showReceivePaymentSheet(context, record: record);
  }
}

class _DetailHeaderBackground extends StatelessWidget {
  const _DetailHeaderBackground({required this.title, this.invoiceNumber});

  final String title;
  final String? invoiceNumber;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF041C0B),
                  Color(0xFF083A1A),
                  Color(0xFF0F5A30),
                ],
                stops: [0.0, 0.45, 1.0],
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
                center: const Alignment(0.78, -0.6),
                radius: 0.85,
                colors: [
                  const Color(0xFF27A84E).withValues(alpha: 0.36),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -10,
          bottom: -10,
          child: Opacity(
            opacity: 0.12,
            child: Icon(
              Icons.receipt_long_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DebtDetailScreen._kLeadingGutter,
            46,
            20,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                invoiceNumber != null && invoiceNumber!.isNotEmpty
                    ? 'Invoice $invoiceNumber'
                    : 'Customer debt ledger',
                style: const TextStyle(
                  color: AppColors.heroSubtitle,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF041C0B),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: AppRadii.heroRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.surface),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF041C0B),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.surface),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
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
    );
  }
}

class _MissingBody extends StatelessWidget {
  const _MissingBody();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF041C0B),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: AppRadii.heroRadius),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.surface),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 42,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'This debt is no longer available. It may have been '
                      'removed from another device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkSoft),
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
