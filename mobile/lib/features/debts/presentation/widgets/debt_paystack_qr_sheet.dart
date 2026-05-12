import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/providers/sync_providers.dart';
import '../../providers/debt_detail_provider.dart';
import '../../providers/debts_providers.dart';
import '../utils/debts_ui_utils.dart';

/// Paystack QR + share-link sheet for a single debt. Mirrors
/// `paystack_qr_sheet.dart` from the sales feature, polling the receivable
/// every 3s to detect server-side settlement via webhook.
class DebtPaystackQrSheet extends ConsumerStatefulWidget {
  const DebtPaystackQrSheet({
    super.key,
    required this.receivableId,
    required this.checkoutUrl,
    required this.amountDisplay,
    required this.customerName,
    required this.onPaymentConfirmed,
  });

  final String receivableId;
  final String checkoutUrl;
  final String amountDisplay;
  final String customerName;
  final VoidCallback onPaymentConfirmed;

  @override
  ConsumerState<DebtPaystackQrSheet> createState() =>
      _DebtPaystackQrSheetState();
}

class _DebtPaystackQrSheetState extends ConsumerState<DebtPaystackQrSheet> {
  Timer? _timer;
  int _pollCount = 0;
  bool _checking = false;
  bool _confirmed = false;
  static const _maxPolls = 20;

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

  Future<void> _check({bool auto = false}) async {
    if (_checking || _confirmed) return;
    if (auto && _pollCount >= _maxPolls) {
      _timer?.cancel();
      return;
    }
    if (auto) _pollCount++;
    setState(() => _checking = true);
    try {
      final api = ref.read(debtsApiProvider);
      final dto = await api.fetchReceivable(widget.receivableId);
      if (!mounted) return;
      final outstandingMinor = DebtsUiUtils.amountToMinor(dto.outstandingAmount);
      final settled =
          dto.status == 'settled' || outstandingMinor == 0;
      if (settled) {
        _confirmed = true;
        _timer?.cancel();
        // Force the detail provider + list controller to re-read so the UI
        // reflects the new balance / status the moment the sheet closes.
        ref.invalidate(receivableDetailProvider(widget.receivableId));
        await ref.read(debtsControllerProvider.notifier).refresh();
        if (!mounted) return;
        widget.onPaymentConfirmed();
        return;
      }
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
    } catch (_) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check status. Try again.'),
          ),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppShadows.elevated,
          ),
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
                'The debt settles automatically when they pay.',
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
              const SizedBox(height: 16),
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
                  size: 210,
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
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
                    _checking ? 'Checking…' : 'Waiting for payment',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 8),
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
    );
  }
}

Future<void> showDebtPaystackQrSheet(
  BuildContext context, {
  required String receivableId,
  required String checkoutUrl,
  required String amountDisplay,
  required String customerName,
  required VoidCallback onPaymentConfirmed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DebtPaystackQrSheet(
      receivableId: receivableId,
      checkoutUrl: checkoutUrl,
      amountDisplay: amountDisplay,
      customerName: customerName,
      onPaymentConfirmed: onPaymentConfirmed,
    ),
  );
}
