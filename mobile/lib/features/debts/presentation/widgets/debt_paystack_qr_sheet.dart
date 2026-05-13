import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../data/debts_api.dart';
import '../../data/debts_payments_api.dart';
import '../../providers/debt_detail_provider.dart';
import '../../providers/debts_providers.dart';
import '../utils/debts_ui_utils.dart';

/// Paystack QR + share-link sheet for a single debt.
///
/// **Verification (parity with sales [PaystackQrSheet]):** poll
/// [DebtsApi.fetchReceivable] for server truth (webhook may settle first),
/// then [DebtsPaymentsApi.verifyPayment] to nudge Paystack when still open.
/// Without [paymentId], only fetch-receivable polling is used.
class DebtPaystackQrSheet extends ConsumerStatefulWidget {
  const DebtPaystackQrSheet({
    super.key,
    required this.receivableId,
    required this.checkoutUrl,
    this.paymentId,
    required this.amountDisplay,
    required this.customerName,
    required this.onPaymentConfirmed,
  });

  final String receivableId;
  final String checkoutUrl;
  final String? paymentId;
  final String amountDisplay;
  final String customerName;

  /// Called when the sheet detects (verify or direct fetch) that payment has
  /// landed. The latest authoritative [ReceivableDto] is forwarded when known
  /// so the parent can show truthful copy ("Debt settled" vs "Partial: …").
  /// May be `null` if the network call after success failed; parents should
  /// fall back to their local snapshot in that case.
  final void Function(ReceivableDto? serverRow) onPaymentConfirmed;

  @override
  ConsumerState<DebtPaystackQrSheet> createState() =>
      _DebtPaystackQrSheetState();
}

class _DebtPaystackQrSheetState extends ConsumerState<DebtPaystackQrSheet> {
  Timer? _timer;
  bool _checking = false;
  bool _confirmed = false;
  int _autoCheckFailures = 0;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _check(auto: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Closes the sheet immediately and lets the parent show its success
  /// snackbar; the snapshot pull / receivable upsert run as fire-and-forget
  /// behind the scenes so a slow network never strands the user on
  /// "Checking…". The local DB is still updated before pop when the caller
  /// passed a fresh [serverRow] (the panel's snackbar consults it).
  Future<void> _completeSuccess({ReceivableDto? serverRow}) async {
    if (_confirmed) return;
    _confirmed = true;
    _timer?.cancel();

    // Apply authoritative server row synchronously so the panel reads the
    // correct outstanding/status when it renders its snackbar. Wrapped in a
    // short timeout to make sure a stalled write can't park the UI.
    if (serverRow != null) {
      try {
        await ref
            .read(debtsControllerProvider.notifier)
            .applyServerReceivable(serverRow)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Local upsert is best-effort here; background refresh below repairs.
      }
    }

    if (!mounted) return;
    widget.onPaymentConfirmed(serverRow);

    // Fire-and-forget snapshot reconciliation. We've already closed the sheet
    // by this point — the merchant sees the panel update either right now
    // (from `applyServerReceivable`) or within seconds when the pull lands.
    unawaited(_reconcileSnapshotInBackground());
  }

  Future<void> _reconcileSnapshotInBackground() async {
    try {
      ref.invalidate(receivableDetailProvider(widget.receivableId));
      await ref
          .read(debtsControllerProvider.notifier)
          .refreshFromServer()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Surfaced via DebtsViewData.lastSyncError on next read; no UI here.
    }
  }

  /// Server reported the pending payment is past TTL. Stop polling, refresh
  /// the local snapshot so the panel shows "Expired - regenerate", then close.
  Future<void> _handleExpiredFromServer() async {
    _timer?.cancel();
    ref.invalidate(receivableDetailProvider(widget.receivableId));
    await ref.read(debtsControllerProvider.notifier).refreshFromServer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This payment link expired. Regenerate it from the debt screen.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pop();
  }

  bool _receivableFullySettled(ReceivableDto dto) {
    final outstandingMinor = DebtsUiUtils.amountToMinor(dto.outstandingAmount);
    return dto.status == 'settled' || outstandingMinor == 0;
  }

  /// A verify response counts as "payment landed" when **any** of these hold:
  /// - Paystack/our payment row reports success (legacy rule), OR
  /// - the receivable is already settled server-side (webhook beat us), OR
  /// - outstanding has dropped to zero (settled by another route).
  ///
  /// Without the latter two checks the sheet polls forever when the webhook
  /// settles first but Paystack verify briefly returns a non-success string
  /// for transient reasons.
  bool _verifyIndicatesSuccess(ReceivablePaymentVerifyOutDto verify) {
    if (verify.isPaymentSuccessful) return true;
    if (verify.isSettled) return true;
    return DebtsUiUtils.amountToMinor(verify.outstandingAmount) == 0;
  }

  Future<void> _check({bool auto = false}) async {
    if (_checking || _confirmed) return;
    setState(() => _checking = true);
    try {
      final debtsApi = ref.read(debtsApiProvider);

      if (widget.paymentId != null) {
        // First, ask the server for the canonical receivable row. If the
        // webhook has already settled, this is the cheapest way to find out.
        ReceivableDto? serverRow;
        Object? serverRowError;
        try {
          serverRow = await debtsApi.fetchReceivable(widget.receivableId);
        } catch (error) {
          // Don't swallow silently. Count toward auto-failure budget so the
          // status chip can surface "Could not reach backend…" instead of
          // making the user wonder why polling never finishes.
          serverRow = null;
          serverRowError = error;
        }
        if (!mounted) return;
        if (serverRow != null && _receivableFullySettled(serverRow)) {
          await _completeSuccess(serverRow: serverRow);
          return;
        }

        final paymentsApi = ref.read(debtsPaymentsApiProvider);
        final verify = await paymentsApi.verifyPayment(widget.paymentId!);
        if (!mounted) return;
        if (_verifyIndicatesSuccess(verify)) {
          // Pull the canonical receivable row right after verify so the local
          // ledger updates even when full snapshot pagination misses this debt.
          ReceivableDto? confirmedRow = serverRow;
          if (confirmedRow == null ||
              !_receivableFullySettled(confirmedRow)) {
            try {
              confirmedRow = await debtsApi.fetchReceivable(widget.receivableId);
            } catch (_) {
              // Fall through with whatever serverRow we had; the panel
              // watcher will reconcile the rest.
            }
          }
          await _completeSuccess(serverRow: confirmedRow);
          return;
        }
        if (verify.paystackTransactionStatus == 'expired') {
          await _handleExpiredFromServer();
          return;
        }
        // Partial-paid: write the authoritative row locally so the panel
        // reflects the new balance immediately, then keep polling for the
        // remainder (we deliberately don't close the sheet here).
        if (verify.receivableStatus == 'partially_paid' && serverRow != null) {
          try {
            await ref
                .read(debtsControllerProvider.notifier)
                .applyServerReceivable(serverRow);
          } catch (_) {
            // best-effort; next snapshot pull will repair
          }
        }
        if (serverRowError != null) {
          _autoCheckFailures++;
          if (_autoCheckFailures >= 2) {
            _statusError = 'Could not reach backend to verify payment status.';
          }
        } else {
          _autoCheckFailures = 0;
          _statusError = null;
        }
        if (!auto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                verify.receivableStatus == 'partially_paid'
                    ? 'Partial payment recorded — waiting for the rest.'
                    : 'Still waiting for payment…',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Fallback for older links without paymentId cached
        final dto = await debtsApi.fetchReceivable(widget.receivableId);
        if (!mounted) return;
        if (_receivableFullySettled(dto)) {
          await _completeSuccess(serverRow: dto);
          return;
        }
        _autoCheckFailures = 0;
        _statusError = null;
        if (!auto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                dto.status == 'partially_paid'
                    ? 'Partial payment recorded — waiting for the rest.'
                    : 'Still waiting for payment…',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (error) {
      if (auto) {
        _autoCheckFailures++;
        if (_autoCheckFailures >= 2) {
          _statusError = 'Could not reach backend to verify payment status.';
        }
      }
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanizeDebtsPaymentsError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.checkoutUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment link copied.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareLink() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final message =
        'Hi ${widget.customerName}, please pay ${widget.amountDisplay} '
        'using this secure link: ${widget.checkoutUrl}';
    await Share.share(
      message,
      subject: 'Payment link',
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Scan to Pay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Show this QR to ${widget.customerName}. '
                  'Payment confirms automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.amountDisplay,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.forestDark,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.card,
                  ),
                  child: QrImageView(
                    data: widget.checkoutUrl,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.forest,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payment link',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 100),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.checkoutUrl,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _shareLink,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_statusError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _checking
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(
                            Icons.wifi_rounded,
                            size: 12,
                            color: AppColors.success,
                          ),
                    const SizedBox(width: 6),
                    Text(
                      _checking ? 'Checking…' : 'Waiting for payment…',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : () => _check(),
                    icon: _checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Check payment now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.inkSoft,
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDebtPaystackQrSheet(
  BuildContext context, {
  required String receivableId,
  required String checkoutUrl,
  String? paymentId,
  required String amountDisplay,
  required String customerName,
  required void Function(ReceivableDto? serverRow) onPaymentConfirmed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DebtPaystackQrSheet(
      receivableId: receivableId,
      checkoutUrl: checkoutUrl,
      paymentId: paymentId,
      amountDisplay: amountDisplay,
      customerName: customerName,
      onPaymentConfirmed: onPaymentConfirmed,
    ),
  );
}
