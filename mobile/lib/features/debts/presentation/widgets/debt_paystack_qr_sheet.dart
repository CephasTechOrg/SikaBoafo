import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/providers/sync_providers.dart';

/// QR code + payment link sheet for debt/receivable collections via Paystack.
///
/// Auto-polls [receivableId] every 3 s. When the receivable transitions to
/// `settled` or `partially_paid`, [onPaymentConfirmed] fires and the timer
/// stops. The user can also trigger a manual check or close without waiting.
class DebtPaystackQrSheet extends ConsumerStatefulWidget {
  const DebtPaystackQrSheet({
    super.key,
    required this.checkoutUrl,
    required this.receivableId,
    required this.onPaymentConfirmed,
  });

  final String checkoutUrl;
  final String receivableId;
  final VoidCallback onPaymentConfirmed;

  @override
  ConsumerState<DebtPaystackQrSheet> createState() =>
      _DebtPaystackQrSheetState();
}

class _DebtPaystackQrSheetState extends ConsumerState<DebtPaystackQrSheet> {
  Timer? _timer;
  int _pollCount = 0;
  bool _checking = false;
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
    if (_checking) return;
    if (auto && _pollCount >= _maxPolls) {
      _timer?.cancel();
      return;
    }
    if (auto) _pollCount++;
    setState(() => _checking = true);
    try {
      final latest = await ref
          .read(debtsApiProvider)
          .fetchReceivableById(widget.receivableId);
      if (!mounted) return;
      if (latest.status == 'settled' || latest.status == 'partially_paid') {
        _timer?.cancel();
        widget.onPaymentConfirmed();
        return;
      }
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Still waiting for payment…'),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not check status. Try again.'),
        ));
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
    await Share.share(
      widget.checkoutUrl,
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
              const Text(
                'Show this QR to the customer. Payment confirms automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
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
                constraints: const BoxConstraints(maxHeight: 80),
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
                      : const Icon(Icons.wifi_rounded,
                          size: 12, color: AppColors.success),
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
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
