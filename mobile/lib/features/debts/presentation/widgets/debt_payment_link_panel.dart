import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../app/router.dart';
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

  bool get _hasLink {
    final link = widget.record.paymentLink;
    return link != null && link.trim().isNotEmpty;
  }

  bool get _isWatchableStatus =>
      widget.record.status == 'open' || widget.record.status == 'partially_paid';

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
      final localMinor = DebtsUiUtils.amountToMinor(widget.record.outstandingAmount);
      int serverMinor = DebtsUiUtils.amountToMinor(server.outstandingAmount);
      bool settled = server.status == 'settled' || serverMinor == 0;
      bool progressed =
          settled || serverMinor < localMinor || server.status != widget.record.status;

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
          serverMinor = DebtsUiUtils.amountToMinor(server.outstandingAmount);
          settled = server.status == 'settled' || serverMinor == 0;
          progressed = settled ||
              serverMinor < localMinor ||
              server.status != widget.record.status;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settled
                ? 'Payment received. Debt settled.'
                : 'Payment received. Remaining balance: ${DebtsUiUtils.formatAmount(server.outstandingAmount)}.',
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

  /// Parsed UTC expiry instant for the active payment link, or `null` if the
  /// server has not yet attached one (e.g. legacy local row before refresh).
  /// Treated as "active, no countdown" when null.
  DateTime? get _linkExpiresAt {
    final iso = widget.record.paymentLinkExpiresAtIso;
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  bool get _linkExpired {
    final at = _linkExpiresAt;
    if (at == null) return false;
    return !DateTime.now().isBefore(at);
  }

  /// Compact "Expires in 23h 12m" / "Expires in 4m" copy. Returns `null` when
  /// expiry is unknown so callers can hide the badge entirely.
  String? _expiryCountdownLabel() {
    final at = _linkExpiresAt;
    if (at == null) return null;
    final remaining = at.difference(DateTime.now());
    if (!remaining.isNegative && remaining.inSeconds <= 60) {
      return 'Expires in <1m';
    }
    if (remaining.isNegative) return null;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours <= 0) return 'Expires in ${minutes}m';
    return 'Expires in ${hours}h ${minutes}m';
  }

  int _minorFromAmount(String raw) {
    final value = raw.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(value);
    if (match == null) return -1;
    final parts = value.split('.');
    final major = int.tryParse(parts.first) ?? -1;
    if (major < 0) return -1;
    final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    final cents = int.tryParse(decimal) ?? -1;
    if (cents < 0) return -1;
    return (major * 100) + cents;
  }

  bool _validateAmountInput() {
    final amountRaw = _amountCtrl.text.trim();
    final amountMinor = _minorFromAmount(amountRaw);
    final outstandingMinor = _minorFromAmount(widget.record.outstandingAmount);
    if (amountMinor <= 0 ||
        outstandingMinor <= 0 ||
        amountMinor > outstandingMinor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enter an amount between GHS 0.01 and ${DebtsUiUtils.formatAmount(widget.record.outstandingAmount)}.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    return true;
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

  Future<void> _openExistingQr() async {
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    if (_linkExpired) {
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
    final link = widget.record.paymentLink;
    if (link == null || link.isEmpty) return;
    if (_linkExpired) {
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
    String? status = serverRow?.status;
    String? outstandingAmount = serverRow?.outstandingAmount;

    if (serverRow == null) {
      final localRecord = ref
          .read(debtsControllerProvider)
          .valueOrNull
          ?.receivables
          .where((r) => r.receivableId == widget.record.receivableId)
          .cast<LocalReceivableRecord?>()
          .firstOrNull;
      status = localRecord?.status;
      outstandingAmount = localRecord?.outstandingAmount;
    }

    final outstandingMinor = outstandingAmount == null
        ? 0
        : DebtsUiUtils.amountToMinor(outstandingAmount);

    final settled = status == 'settled' || outstandingMinor == 0;
    if (settled) return 'Payment received. Debt settled.';
    if (outstandingAmount != null) {
      return 'Partial payment received. Remaining: '
          '${DebtsUiUtils.formatAmount(outstandingAmount)}.';
    }
    return 'Payment received.';
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
        TextField(
          controller: _amountCtrl,
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
        const SizedBox(height: 14),
        if (!_isSynced)
          _PendingSyncNotice(
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
          _MomoPushButton(
            onTap: (_generating || _openingMomo) ? null : _openMomoPush,
            busy: _openingMomo,
          ),
        ],
      ],
    );
  }

  Widget _activeLinkBody() {
    final link = widget.record.paymentLink!;
    final expired = _linkExpired;
    final countdownLabel = _expiryCountdownLabel();
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
        if (expired || countdownLabel != null) ...[
          _ExpiryBadge(expired: expired, label: countdownLabel),
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

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.expired, required this.label});

  final bool expired;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final bg = expired ? DebtsUi.dangerSoft : DebtsUi.accentGoldSoft;
    final fg = expired ? DebtsUi.danger : DebtsUi.accentGoldInk;
    final text = expired ? 'Expired' : (label ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expired
                ? Icons.lock_clock_rounded
                : Icons.schedule_rounded,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the online-pay buttons while a debt has not yet synced to
/// the server (DEBT-09). Online Paystack collection (QR / link / MoMo) all need
/// a server-side receivable id, so we explain the block in plain language and
/// offer a single "Sync now" action instead of letting the merchant tap a pay
/// button that would only fail.
class _PendingSyncNotice extends StatelessWidget {
  const _PendingSyncNotice({required this.onSyncNow, required this.busy});

  final VoidCallback? onSyncNow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DebtsUi.accentGoldSoft,
        borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        border: Border.all(
          color: DebtsUi.accentGoldInk.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: DebtsUi.accentGoldInk,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sync this debt before collecting online',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DebtsUi.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This debt was saved offline. QR, payment link, and MoMo prompts '
            'need it on the server first. Connect to the internet and sync to '
            'unlock online payment.',
            style: TextStyle(
              fontSize: 12,
              color: DebtsUi.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onSyncNow,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(busy ? 'Syncing…' : 'Sync now'),
            style: FilledButton.styleFrom(
              backgroundColor: DebtsUi.greenDark,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomoPushButton extends StatelessWidget {
  const _MomoPushButton({required this.onTap, required this.busy});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.phone_android_rounded, size: 16),
      label: Text(busy ? 'Preparing…' : 'Push MoMo prompt'),
      style: OutlinedButton.styleFrom(
        foregroundColor: DebtsUi.accentGold,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        ),
        side: BorderSide(color: DebtsUi.accentGold.withValues(alpha: 0.45)),
      ),
    );
  }
}
