import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../app/router.dart';
import '../utils/debt_payment_amount_validator.dart';
import '../utils/debt_payment_link_state.dart';
import '../utils/debt_payment_progress.dart';
import '../utils/debts_ui_tokens.dart';
import '../../../../core/services/notifications_service.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../../settings/providers/notification_prefs_provider.dart';
import '../../data/debts_api.dart';
import '../../data/models/local_receivable_record.dart';
import '../../providers/debt_detail_provider.dart';
import '../../providers/debts_providers.dart';
import '../utils/debts_ui_utils.dart';
import 'debt_payment_link_panel_widgets.dart';
import 'debt_payment_link_share.dart';
import 'debt_paystack_momo_sheet/debt_paystack_momo_sheet.dart';
import 'debt_paystack_qr_sheet.dart';

/// Card on the debt detail screen for generating / showing the Paystack
/// hosted payment link. Two visual states:
///   - **No link yet:** primary "Generate payment link" CTA.
///   - **Link active:** "Active link" card with Show QR + Share buttons.
class DebtPaymentLinkPanel extends ConsumerStatefulWidget {
  const DebtPaymentLinkPanel({
    super.key,
    required this.record,
    this.compact = false,
  });

  final LocalReceivableRecord record;

  /// When true (e.g. inside [ExpansionTile] on debt detail), omits the large
  /// header row and uses tighter padding so the parent sets hierarchy.
  final bool compact;

  @override
  ConsumerState<DebtPaymentLinkPanel> createState() =>
      _DebtPaymentLinkPanelState();
}

class _DebtPaymentLinkPanelState extends ConsumerState<DebtPaymentLinkPanel> {
  bool _generating = false;
  bool _openingMomo = false;
  bool _syncing = false;
  bool _statusWatchInFlight = false;
  String? _lastStatusToastKey;
  late final TextEditingController _amountCtrl;

  /// Ticks once a minute so the countdown badge stays fresh without rebuilding
  /// the entire debt detail tree. Cancelled in `dispose`.
  Timer? _expiryTicker;
  Timer? _statusWatchTicker;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.record.outstandingAmount,
    );
    _expiryTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    _syncStatusWatcher();
  }

  @override
  void didUpdateWidget(covariant DebtPaymentLinkPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = '${oldWidget.record.receivableId}:${oldWidget.record.paymentId}:${oldWidget.record.paymentLink}';
    final newKey = '${widget.record.receivableId}:${widget.record.paymentId}:${widget.record.paymentLink}';
    if (oldKey != newKey || oldWidget.record.status != widget.record.status) {
      _syncStatusWatcher();
    }
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    _statusWatchTicker?.cancel();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _isSynced => widget.record.syncStatus == 'applied';

  DebtPaymentLinkState get _linkState => DebtPaymentLinkState(
        paymentLink: widget.record.paymentLink,
        paymentLinkExpiresAtIso: widget.record.paymentLinkExpiresAtIso,
      );

  bool get _hasLink => _linkState.hasLink;

  bool get _isWatchableStatus =>
      DebtPaymentLinkState.shouldWatchPassiveStatus(
        hasLink: _hasLink,
        receivableStatus: widget.record.status,
      );

  void _syncStatusWatcher() {
    _statusWatchTicker?.cancel();
    if (!_hasLink || !_isWatchableStatus) return;
    _statusWatchTicker = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _watchServerPaymentProgress(),
    );
  }

  Future<void> _watchServerPaymentProgress() async {
    if (!mounted || _statusWatchInFlight || !_isWatchableStatus || !_hasLink) {
      return;
    }
    _statusWatchInFlight = true;
    try {
      ReceivableDto server = await ref
          .read(debtsApiProvider)
          .fetchReceivable(widget.record.receivableId);
      if (!mounted) return;
      final localOutstanding = widget.record.outstandingAmount;
      final localStatus = widget.record.status;
      bool progressed = DebtPaymentProgress.hasReceivableProgressed(
        server: server,
        localOutstandingAmount: localOutstanding,
        localStatus: localStatus,
      );

      // Verify fallback: webhook may have been missed or delayed. If
      // fetchReceivable shows no progress and we have a known paymentId,
      // nudge Paystack via verifyPayment and re-fetch. The QR sheet does
      // this while open; the passive watcher needs the same nudge for
      // links shared out-of-band (e.g. WhatsApp).
      final paymentId = widget.record.paymentId;
      if (!progressed && paymentId != null && paymentId.isNotEmpty) {
        try {
          await ref.read(debtsPaymentsApiProvider).verifyPayment(paymentId);
          if (!mounted) return;
          server = await ref
              .read(debtsApiProvider)
              .fetchReceivable(widget.record.receivableId);
          if (!mounted) return;
          progressed = DebtPaymentProgress.hasReceivableProgressed(
            server: server,
            localOutstandingAmount: localOutstanding,
            localStatus: localStatus,
          );
        } catch (_) {
          // Verify is best-effort here; rely on next tick / webhook.
        }
      }

      if (!progressed) return;

      final toastKey = '${server.status}:${server.outstandingAmount}';
      if (_lastStatusToastKey == toastKey) return;
      _lastStatusToastKey = toastKey;

      await ref.read(debtsControllerProvider.notifier).applyServerReceivable(server);
      ref.invalidate(receivableDetailProvider(widget.record.receivableId));
      await ref.read(debtsControllerProvider.notifier).refreshFromServer();
      if (!mounted) return;
      final settled = DebtPaymentProgress.isReceivableFullySettled(server);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            DebtPaymentProgress.watcherProgressMessage(
              server: server,
              settled: settled,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      // Fire a local notification too, so the merchant gets a buzz even
      // when they've navigated away from the debt detail screen (this
      // watcher only runs while the panel is mounted, but the user can
      // be on a child screen of the detail route).
      unawaited(
        _maybeFirePaymentNotification(server: server, settled: settled),
      );
      if (settled || server.status == 'cancelled') {
        _statusWatchTicker?.cancel();
      }
    } catch (_) {
      // Passive watcher only; avoid noisy banners for transient network errors.
    } finally {
      _statusWatchInFlight = false;
    }
  }

  /// Pushes a local payment notification when the watcher detects settlement
  /// or partial progress while the user is on this screen. Gated by the
  /// `paymentEventsEnabled` preference so users who opt out aren't pinged.
  Future<void> _maybeFirePaymentNotification({
    required ReceivableDto server,
    required bool settled,
  }) async {
    final prefs = ref.read(notificationPrefsProvider).valueOrNull;
    if (prefs?.paymentEventsEnabled != true) return;
    final customer = widget.record.customerName ?? 'Customer';
    final title = settled
        ? 'Debt settled: $customer'
        : 'Payment received: $customer';
    final body = settled
        ? 'Outstanding cleared (${DebtsUiUtils.formatAmount(server.originalAmount)}).'
        : 'Remaining balance: ${DebtsUiUtils.formatAmount(server.outstandingAmount)}.';
    const android = AndroidNotificationDetails(
      'payment_events',
      'Payment events',
      channelDescription: 'Payment confirmation and failure alerts',
      importance: Importance.high,
      priority: Priority.high,
      color: DebtsUi.greenMid,
    );
    final route =
        AppRoute.debtDetail.path.replaceFirst(':id', widget.record.receivableId);
    try {
      await ref.read(notificationsServiceProvider).showNow(
            type: AppNotificationType.paystack,
            title: title,
            body: body,
            android: android,
            route: route,
            entityId: widget.record.receivableId,
          );
    } catch (_) {
      // Notifications are best-effort; never let them break the watcher.
    }
  }

  bool _validateAmountInput() {
    final validation = DebtPaymentAmountValidation.validate(
      amountRaw: _amountCtrl.text,
      outstandingAmount: widget.record.outstandingAmount,
    );
    if (validation.isValid) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          validation.validationSnackMessage(
            DebtsUiUtils.formatAmount(widget.record.outstandingAmount),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    return false;
  }

  /// Explicit "Sync now" action shown when a debt has not yet reached the
  /// server. Online Paystack collection needs a server-side receivable id, so
  /// we block the pay buttons (DEBT-09) until the local row is `applied`. This
  /// nudges the global queue, then confirms the receivable create synced and
  /// refreshes so the panel rebuilds with the pay buttons enabled.
  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(syncStatusControllerProvider.notifier).syncNow();
      if (!mounted) return;
      final ok = await _ensureSyncedForOnlinePayment();
      if (!mounted || !ok) return;
      ref.invalidate(receivableDetailProvider(widget.record.receivableId));
      await ref.read(debtsControllerProvider.notifier).refreshFromServer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debt synced. You can now collect online.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<bool> _ensureSyncedForOnlinePayment() async {
    if (_isSynced) return true;
    try {
      await ref
          .read(debtsControllerProvider.notifier)
          .ensureReceivableCreateSyncedToBackend(widget.record.receivableId);
      final refreshed = await ref
          .read(debtsControllerProvider.notifier)
          .getReceivableById(widget.record.receivableId);
      final nowSynced = refreshed?.syncStatus == 'applied';
      if (nowSynced) return true;
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This debt has not synced yet. Check your internet connection and try again.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      return false;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(error)),
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }
  }

  Future<void> _generate({required bool openQrAfter}) async {
    if (!_validateAmountInput()) return;
    setState(() => _generating = true);
    final synced = await _ensureSyncedForOnlinePayment();
    if (!mounted) return;
    if (!synced) {
      setState(() => _generating = false);
      return;
    }

    try {
      final initiation =
          await ref.read(debtsControllerProvider.notifier).initiatePaymentLink(
                receivableId: widget.record.receivableId,
                amount: _amountCtrl.text.trim(),
              );
      if (!mounted) return;
      if (openQrAfter) {
        await showDebtPaystackQrSheet(
          context,
          receivableId: widget.record.receivableId,
          checkoutUrl: initiation.checkoutUrl,
          paymentId: initiation.paymentId,
          amountDisplay: DebtsUiUtils.formatAmount(
            _amountCtrl.text.trim(),
          ),
          customerName: widget.record.customerName ?? 'Customer',
          onPaymentConfirmed: _onSheetPaymentConfirmed,
        );
      } else {
        await showDebtPaymentLinkShare(
          context,
          checkoutUrl: initiation.checkoutUrl,
          amountDisplay: DebtsUiUtils.formatAmount(
            _amountCtrl.text.trim(),
          ),
          customerName: widget.record.customerName ?? 'Customer',
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyError(error)),
          backgroundColor: DebtsUi.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// The amount baked into the existing link no longer matches what the
  /// merchant typed — they edited the field, so the active link is stale and
  /// the QR/share would collect the wrong amount.
  bool get _amountChangedFromLink {
    final entered = DebtsUiUtils.amountToMinor(_amountCtrl.text.trim());
    if (entered <= 0) return false;
    final linkAmount = widget.record.paymentAmount;
    if (linkAmount == null || linkAmount.isEmpty) return false;
    return entered != DebtsUiUtils.amountToMinor(linkAmount);
  }

  Future<void> _openExistingQr() async {
    // Regenerate first if the merchant changed the amount, so the QR reflects
    // what they typed instead of the stale link's baked amount.
    if (_amountChangedFromLink) {
      await _generate(openQrAfter: true);
      return;
    }
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    if (_linkState.isExpired) {
      _showExpiredSnack();
      return;
    }
    await showDebtPaystackQrSheet(
      context,
      receivableId: widget.record.receivableId,
      checkoutUrl: link,
      paymentId: widget.record.paymentId,
      amountDisplay: DebtsUiUtils.formatAmount(
        widget.record.paymentAmount ?? widget.record.outstandingAmount,
      ),
      customerName: widget.record.customerName ?? 'Customer',
      onPaymentConfirmed: _onSheetPaymentConfirmed,
    );
  }

  Future<void> _openExistingShare() async {
    if (_amountChangedFromLink) {
      await _generate(openQrAfter: false);
      return;
    }
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    if (_linkState.isExpired) {
      _showExpiredSnack();
      return;
    }
    await showDebtPaymentLinkShare(
      context,
      checkoutUrl: link,
      amountDisplay: DebtsUiUtils.formatAmount(
        widget.record.paymentAmount ?? widget.record.outstandingAmount,
      ),
      customerName: widget.record.customerName ?? 'Customer',
    );
  }

  /// Resolves the snackbar message after a sheet reports payment landed.
  /// Prefers the authoritative [serverRow], then falls back to the latest
  /// local snapshot, then the previous "settled" assumption. Without this,
  /// partial payments were misleadingly reported as fully settled.
  String _paymentConfirmedMessage(ReceivableDto? serverRow) {
    String? fallbackStatus;
    String? fallbackOutstanding;
    if (serverRow == null) {
      final localRecord = ref
          .read(debtsControllerProvider)
          .valueOrNull
          ?.receivables
          .where((r) => r.receivableId == widget.record.receivableId)
          .cast<LocalReceivableRecord?>()
          .firstOrNull;
      fallbackStatus = localRecord?.status;
      fallbackOutstanding = localRecord?.outstandingAmount;
    }
    return DebtPaymentProgress.paymentConfirmedMessage(
      serverRow: serverRow,
      fallbackStatus: fallbackStatus,
      fallbackOutstanding: fallbackOutstanding,
    );
  }

  void _onSheetPaymentConfirmed(ReceivableDto? serverRow) {
    if (!mounted) return;

    // Hard-invalidate the detail provider so the screen below re-reads
    // local state once the sheet pops. The QR sheet's background reconcile
    // already does this, but MoMo / future entry points may not, and a
    // double-invalidate is cheap.
    ref.invalidate(receivableDetailProvider(widget.record.receivableId));

    // Local-first: apply the authoritative server row so the panel rebuilds
    // with the right balance even before the snapshot pull lands.
    if (serverRow != null) {
      unawaited(
        ref
            .read(debtsControllerProvider.notifier)
            .applyServerReceivable(serverRow),
      );
    }

    // Reconcile against server in the background so we don't block pop().
    unawaited(
      ref.read(debtsControllerProvider.notifier).refreshFromServer(),
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_paymentConfirmedMessage(serverRow))),
    );
  }

  void _showExpiredSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This payment link expired. Regenerate it to share or scan again.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openMomoPush() async {
    if (_openingMomo || _generating) return;
    if (!_validateAmountInput()) return;
    setState(() => _openingMomo = true);
    try {
      final synced = await _ensureSyncedForOnlinePayment();
      if (!mounted || !synced) return;
      await showDebtPaystackMomoSheet(
        context,
        receivableId: widget.record.receivableId,
        amountDisplay: DebtsUiUtils.formatAmount(_amountCtrl.text.trim()),
        chargeAmount: _amountCtrl.text.trim(),
        customerName: widget.record.customerName ?? 'Customer',
        onPaymentConfirmed: _onSheetPaymentConfirmed,
      );
    } finally {
      if (mounted) setState(() => _openingMomo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _hasLink ? _activeLinkBody() : _generateBody();
    if (widget.compact) {
      return body;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DebtsUi.surface,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.border, width: 1.5),
        boxShadow: DebtsUi.shadowSm,
      ),
      child: body,
    );
  }

  Widget _generateBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: DebtsUi.ctaGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collect online',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: DebtsUi.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'QR, link, or card.',
                      style: TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _AmountToCollectField(controller: _amountCtrl),
        const SizedBox(height: 14),
        if (!_isSynced)
          DebtPaymentPendingSyncNotice(
            onSyncNow: _syncing ? null : _syncNow,
            busy: _syncing,
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _generating ? null : () => _generate(openQrAfter: false),
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed:
                      _generating ? null : () => _generate(openQrAfter: true),
                  icon: _generating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: Text(_generating ? 'Generating…' : 'Show QR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DebtsUi.greenDark,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DebtPaymentMomoPushButton(
            onTap: (_generating || _openingMomo) ? null : _openMomoPush,
            busy: _openingMomo,
          ),
        ],
      ],
    );
  }

  Widget _activeLinkBody() {
    final link = widget.record.paymentLink!;
    final expired = _linkState.isExpired;
    final countdownLabel = _linkState.expiryCountdownLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: expired ? DebtsUi.dangerSoft : DebtsUi.greenPale,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  expired ? Icons.link_off_rounded : Icons.link_rounded,
                  color: expired ? DebtsUi.danger : DebtsUi.greenBright,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expired ? 'Payment link expired' : 'Payment link active',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: DebtsUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expired
                          ? 'Regenerate to share or scan again.'
                          : 'Share or show QR. Settles when paid.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _AmountToCollectField(controller: _amountCtrl),
        const SizedBox(height: 12),
        if (expired || countdownLabel != null) ...[
          DebtPaymentExpiryBadge(expired: expired, label: countdownLabel),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: DebtsUi.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DebtsUi.border),
          ),
          child: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: expired ? DebtsUi.textMuted : DebtsUi.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
              decoration:
                  expired ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (expired)
          FilledButton.icon(
            onPressed:
                _generating ? null : () => _generate(openQrAfter: true),
            icon: _generating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label:
                Text(_generating ? 'Regenerating…' : 'Regenerate payment link'),
            style: FilledButton.styleFrom(
              backgroundColor: DebtsUi.greenDark,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openExistingShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _openExistingQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Show QR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DebtsUi.greenDark,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DebtPaymentMomoPushButton(
            onTap: (_generating || _openingMomo) ? null : _openMomoPush,
            busy: _openingMomo,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed:
                  _generating ? null : () => _generate(openQrAfter: true),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: _generating
                  ? const Text('Regenerating…')
                  : const Text('Regenerate link'),
              style: TextButton.styleFrom(
                foregroundColor: DebtsUi.textSecondary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared "amount to collect" input used in both the generate and active-link
/// states of the pay-online panel, so the merchant can always set a partial
/// amount before pushing a prompt, showing the QR, or sharing the link.
class _AmountToCollectField extends StatelessWidget {
  const _AmountToCollectField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount to collect',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DebtsUi.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: DebtsUi.greenDark,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: 'GHS ',
            prefixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DebtsUi.textMuted,
            ),
            hintText: '0.00',
            filled: true,
            fillColor: DebtsUi.greenMid.withValues(alpha: 0.07),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
