import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../../shared/providers/sync_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/streak_hero_header.dart';
import '../data/debts_repository.dart';
import '../providers/debts_providers.dart';
import '../providers/debt_reminders_provider.dart';
import 'utils/debts_ui_tokens.dart';
import 'utils/debts_ui_utils.dart';
import 'widgets/debt_balance_hero.dart';
import 'widgets/debt_payment_card.dart';
import 'widgets/debt_payment_link_panel.dart';
import 'widgets/debt_payment_sheet.dart';
import 'widgets/debt_reminder_row.dart';

class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({
    required this.receivableId,
    super.key,
  });

  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(receivableDetailProvider(receivableId));
    final detail = detailAsync.valueOrNull;

    const kLeadingGutter = 56.0;
    final title = detail?.record.customerName ?? 'Debt Detail';
    final subtitle = detail == null
        ? 'Review balance, repayment history, and debt status'
        : DebtsUiUtils.statusLabel(detail.record.status);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 320,
            child: ColoredBox(color: Color(0xFF041C0B)),
          ),
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 210,
                pinned: true,
                stretch: true,
                leadingWidth: kLeadingGutter,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
                backgroundColor: const Color(0xFF041C0B),
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: StreakHeroHeader(
                    leadingContentInset: kLeadingGutter,
                    title: title,
                    subtitle: subtitle,
                    gradient: DebtTokens.heroGradient,
                    badge: const PremiumBadge(
                      label: 'Receivable',
                      icon: Icons.receipt_long_rounded,
                      foreground: Colors.white,
                      background: Color(0x24FFFFFF),
                    ),
                  ),
                  title: innerBoxIsScrolled
                      ? Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        )
                      : null,
                  centerTitle: false,
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: kLeadingGutter,
                    bottom: 16,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 18),
              ),
            ],
            body: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: AppRadii.heroRadius,
                ),
                child: Container(
                  color: AppColors.surface,
                  child: detailAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    error: (error, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                      children: [
                        _DetailErrorView(
                          message: userFriendlyError(error),
                          onRetry: () => ref.invalidate(
                            receivableDetailProvider(receivableId),
                          ),
                        ),
                      ],
                    ),
                    data: (detail) {
                      if (detail == null) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                          children: const [
                            PremiumEmptyState(
                              title: 'Debt record not found',
                              message:
                                  'This receivable is no longer available in the active debt list.',
                              icon: Icons.search_off_rounded,
                            ),
                          ],
                        );
                      }
                      return _DetailBody(
                        detail: detail,
                        receivableId: receivableId,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({
    required this.detail,
    required this.receivableId,
  });

  final LocalReceivableDetail detail;
  final String receivableId;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {

  @override
  Widget build(BuildContext context) {
    final row = widget.detail.record;
    final outstanding = '\u20B5${row.outstandingAmount}';
    final original = '\u20B5${row.originalAmount}';
    final paymentTotal = DebtsUiUtils.fmtAmount(
      ((double.tryParse(row.originalAmount) ?? 0) -
              (double.tryParse(row.outstandingAmount) ?? 0))
          .toStringAsFixed(2),
    );
    final canCollect = row.status == 'open' || row.status == 'partially_paid';
    final hasPaymentLink =
        row.paymentLink != null && row.paymentLink!.isNotEmpty;
    final remindersAsync =
        ref.watch(debtRemindersProvider(widget.receivableId));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(debtsControllerProvider.notifier).refresh();
        ref.invalidate(receivableDetailProvider(widget.receivableId));
        await ref.read(receivableDetailProvider(widget.receivableId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          DebtBalanceHero(
            outstanding: outstanding,
            original: original,
            paid: '\u20B5$paymentTotal',
            dueDate: DebtsUiUtils.fmtDueDate(row.dueDateIso, fallback: 'Not set'),
            invoiceNumber: row.invoiceNumber,
            status: row.status,
          ),
          const SizedBox(height: 16),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSectionHeading(title: 'Reminders'),
                const SizedBox(height: 14),
                remindersAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Loading remindersâ€¦',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  error: (e, _) => Text(
                    e.toString(),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                  data: (times) {
                    if (times.isEmpty) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No reminders set',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _addReminder(context),
                            icon: const Icon(Icons.add_alarm_rounded, size: 16),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.forest),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < times.length; i++) ...[
                          DebtReminderRow(
                            when: times[i],
                            onRemove: () => ref
                                .read(
                                  debtRemindersProvider(widget.receivableId)
                                      .notifier,
                                )
                                .removeReminderAt(i),
                          ),
                          if (i != times.length - 1) const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _addReminder(context),
                            icon: const Icon(Icons.add_alarm_rounded, size: 18),
                            label: const Text('Add another reminder'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (canCollect) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openPaymentSheet(context),
                icon: const Icon(Icons.payments_outlined),
                label: const Text(
                  'Receive Payment',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DebtTokens.buttonRadius),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.danger,
                ),
                label: const Text(
                  'Cancel Debt',
                  style: TextStyle(color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DebtTokens.buttonRadius),
                  ),
                ),
              ),
            ),
          ],
          if (hasPaymentLink) ...[
            const SizedBox(height: 12),
            DebtPaymentLinkPanel(
              paymentLink: row.paymentLink!,
              receivableId: widget.receivableId,
              onPaymentConfirmed: _onPaymentConfirmed,
            ),
          ],
          const SizedBox(height: 20),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumSectionHeading(title: 'Customer'),
                const SizedBox(height: 16),
                _InfoRow(label: 'Name', value: row.customerName),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFEEF1EE)),
                ),
                _InfoRow(
                  label: 'Phone',
                  value: widget.detail.customerPhoneNumber ?? 'Not provided',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFEEF1EE)),
                ),
                _InfoRow(
                  label: 'Created',
                  value: DateFormat('d MMM yyyy').format(
                    DateTime.fromMillisecondsSinceEpoch(row.createdAtMillis),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSectionHeading(
                  title: 'Repayment History',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${widget.detail.paymentCount}',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (widget.detail.payments.isEmpty)
                  const PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No repayments recorded yet',
                    message:
                        'Recorded collections will appear here in chronological order.',
                  )
                else
                  Column(
                    children: [
                      for (var i = 0;
                          i < widget.detail.payments.length;
                          i++) ...[
                        DebtPaymentCard(payment: widget.detail.payments[i]),
                        if (i != widget.detail.payments.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addReminder(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;
    final when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await ref
        .read(debtRemindersProvider(widget.receivableId).notifier)
        .addReminder(whenLocal: when);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder scheduled.')),
    );
  }

  Future<void> _openPaymentSheet(BuildContext context) async {
    final row = widget.detail.record;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DebtPaymentSheet(
        receivableId: widget.receivableId,
        customerName: row.customerName,
        outstandingAmount: row.outstandingAmount,
        syncStatus: row.syncStatus,
        existingPaymentLink: row.paymentLink,
        onRepaymentSaved: () {
          ref.invalidate(receivableDetailProvider(widget.receivableId));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repayment saved.')),
          );
        },
        onPaymentConfirmed: _onPaymentConfirmed,
      ),
    );
  }

  void _onPaymentConfirmed() {
    ref.read(debtsControllerProvider.notifier).refresh();
    ref.invalidate(receivableDetailProvider(widget.receivableId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment confirmed!')),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Debt?'),
        content: const Text(
          'This will mark the debt as cancelled and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Debt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      // If this debt was created offline and hasn't reached the backend yet,
      // cancel will return "not found". Sync first to ensure it exists server-side.
      if (widget.detail.record.syncStatus != 'applied') {
        await ref.read(debtsRepositoryProvider).syncPendingQueue();
      }
      await ref.read(debtsApiProvider).cancelReceivable(widget.receivableId);
      if (!context.mounted) return;
      ref.invalidate(receivableDetailProvider(widget.receivableId));
      await ref.read(debtsControllerProvider.notifier).refresh();
      if (!context.mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt cancelled.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final msg = userFriendlyError(error);
      final hint = widget.detail.record.syncStatus != 'applied'
          ? ' (Try syncing first)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg$hint')),
      );
    }
  }

}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}


class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      backgroundColor: AppColors.dangerSoft,
      borderColor: const Color(0xFFF2C9C0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
