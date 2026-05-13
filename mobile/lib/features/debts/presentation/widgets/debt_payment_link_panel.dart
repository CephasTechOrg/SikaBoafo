import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/debts_api.dart';
import '../../data/models/local_receivable_record.dart';
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
  bool _statusWatchInFlight = false;
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
      final server = await ref
          .read(debtsApiProvider)
          .fetchReceivable(widget.record.receivableId);
      if (!mounted) return;
      final localMinor = DebtsUiUtils.amountToMinor(widget.record.outstandingAmount);
      final serverMinor = DebtsUiUtils.amountToMinor(server.outstandingAmount);
      final settled = server.status == 'settled' || serverMinor == 0;
      final progressed =
          settled || serverMinor < localMinor || server.status != widget.record.status;
      if (!progressed) return;

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
      if (settled || server.status == 'cancelled') {
        _statusWatchTicker?.cancel();
      }
    } catch (_) {
      // Passive watcher only; avoid noisy banners for transient network errors.
    } finally {
      _statusWatchInFlight = false;
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
          onPaymentConfirmed: () {
            if (!mounted) return;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment received. Debt settled.')),
            );
          },
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
          backgroundColor: AppColors.danger,
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
      onPaymentConfirmed: () {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received. Debt settled.')),
        );
      },
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
        onPaymentConfirmed: () {
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment received. Debt settled.')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _openingMomo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compact ? 10 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 18),
        border: Border.all(color: AppColors.border),
        boxShadow: widget.compact ? const <BoxShadow>[] : AppShadows.subtle,
      ),
      child: _hasLink ? _activeLinkBody() : _generateBody(),
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
                  gradient: AppGradients.primaryCta,
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
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'QR, link, or card.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
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
            color: AppColors.forestDark,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            prefixText: 'GHS ',
            prefixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
            hintText: '0.00',
            filled: true,
            fillColor: AppColors.forest.withValues(alpha: 0.07),
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
                    borderRadius: BorderRadius.circular(AppRadii.sm),
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
                  backgroundColor: AppColors.forestDark,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
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
                  color: expired ? AppColors.dangerSoft : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  expired ? Icons.link_off_rounded : Icons.link_rounded,
                  color: expired ? AppColors.danger : AppColors.success,
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
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expired
                          ? 'Regenerate to share or scan again.'
                          : 'Share or show QR. Settles when paid.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
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
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            link,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: expired ? AppColors.muted : AppColors.inkSoft,
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
              backgroundColor: AppColors.forestDark,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
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
                      borderRadius: BorderRadius.circular(AppRadii.sm),
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
                    backgroundColor: AppColors.forestDark,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
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
                foregroundColor: AppColors.inkSoft,
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
    final bg = expired ? AppColors.dangerSoft : AppColors.warningSoft;
    final fg = expired ? AppColors.danger : AppColors.warning;
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
        foregroundColor: AppColors.gold,
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
    );
  }
}
