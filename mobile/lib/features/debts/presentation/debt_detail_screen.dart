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

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.when, required this.onRemove});

  final DateTime when;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(when);
    final time = DateFormat.jm().format(when);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.alarm_rounded,
                color: AppColors.navy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove reminder',
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.outstanding,
    required this.original,
    required this.paid,
    required this.dueDate,
    required this.invoiceNumber,
    required this.status,
  });

  final String outstanding;
  final String original;
  final String paid;
  final String dueDate;
  final String? invoiceNumber;
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
        boxShadow: DebtTokens.receipt,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
        child: CustomPaint(
          foregroundPainter: const _ReceiptEdgePainter(),
          child: Container(
            decoration: BoxDecoration(
              color: DebtTokens.paper,
              border: Border.all(color: DebtTokens.paperEdge),
              borderRadius: BorderRadius.circular(DebtTokens.receiptRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.forest.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.forest,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receivable Statement',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Current outstanding balance',
                              style: TextStyle(
                                color: DebtTokens.paperMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _ReceiptDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OUTSTANDING',
                        style: TextStyle(
                          color: DebtTokens.paperMuted.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          outstanding,
                          style: const TextStyle(
                            color: DebtTokens.hero800,
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _ReceiptDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  child: Column(
                    children: [
                      _ReceiptRow(label: 'Original Amount', value: original),
                      const SizedBox(height: 12),
                      _ReceiptRow(label: 'Amount Paid', value: paid),
                      const SizedBox(height: 12),
                      _ReceiptRow(label: 'Due Date', value: dueDate),
                      if (invoiceNumber != null && invoiceNumber!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ReceiptRow(label: 'Invoice Number', value: invoiceNumber!),
                      ],
                    ],
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

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: DebtTokens.paperMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _DashedLinePainter(color: Color(0xFFE6DCC5)),
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ReceiptEdgePainter extends CustomPainter {
  const _ReceiptEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFF7ECD4);
    const notch = 7.0;
    var y = 18.0;
    while (y < size.height - 12) {
      canvas.drawCircle(Offset(0, y), notch, paint);
      canvas.drawCircle(Offset(size.width, y), notch, paint);
      y += 24;
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptEdgePainter oldDelegate) => false;
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final LocalReceivablePaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final syncColor = _syncColor(payment.syncStatus);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u20B5${payment.amount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelizePaymentMethod(payment.paymentMethodLabel),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(
                      payment.createdAtMillis,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PremiumStatusPill(
            label: _humanizeSyncStatus(payment.syncStatus),
            foreground: syncColor,
            background: syncColor.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
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

class _PaymentLinkPanel extends StatelessWidget {
  const _PaymentLinkPanel({
    required this.paymentLink,
    required this.receivableId,
    required this.onPaymentConfirmed,
  });

  final String paymentLink;
  final String receivableId;
  final VoidCallback onPaymentConfirmed;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PremiumSectionHeading(title: 'Payment link ready'),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            paymentLink,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _viewQr(context),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                  label: const Text('View QR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: paymentLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment link copied.')),
    );
  }

  void _viewQr(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DebtPaystackQrSheet(
        checkoutUrl: paymentLink,
        receivableId: receivableId,
        onPaymentConfirmed: onPaymentConfirmed,
      ),
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

String _humanizeError(Object error) => userFriendlyError(error);

String _labelizePaymentMethod(String value) {
  return switch (value) {
    'mobile_money' => 'Mobile Money',
    'bank_transfer' => 'Bank Transfer',
    _ => 'Cash',
  };
}

String _formatDateTime(DateTime value) =>
    DateFormat('d MMM yyyy, h:mm a').format(value);

String _formatDueDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Not set';
  try {
    return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _humanizeSyncStatus(String s) => switch (s) {
      'applied' || 'duplicate' => 'Synced',
      'sending' => 'Syncingâ€¦',
      'failed' => 'Failed',
      'conflict' => 'Conflict',
      _ => 'Pending',
    };

String _formatMoney(String value) {
  final parsed = double.tryParse(value) ?? 0;
  return parsed.toStringAsFixed(2);
}

String _statusLabel(String status) {
  return switch (status) {
    'settled' => 'Settled',
    'cancelled' => 'Cancelled',
    'partially_paid' => 'Partial',
    _ => 'Open',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'settled' => AppColors.success,
    'cancelled' => AppColors.muted,
    'partially_paid' => AppColors.warning,
    _ => AppColors.gold,
  };
}

Color _syncColor(String status) {
  return switch (status) {
    'applied' || 'duplicate' => AppColors.success,
    'failed' => AppColors.danger,
    'conflict' => AppColors.warning,
    'sending' => AppColors.sky,
    _ => AppColors.warning,
  };
}

