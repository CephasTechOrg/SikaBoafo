import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/debts_ui_tokens.dart';

/// Compact share-only bottom sheet used when the merchant wants to re-send
/// an existing payment link without scanning a QR. Smaller surface than
/// [DebtPaystackQrSheet].
class DebtPaymentLinkShare extends StatelessWidget {
  const DebtPaymentLinkShare({
    super.key,
    required this.checkoutUrl,
    required this.amountDisplay,
    required this.customerName,
  });

  final String checkoutUrl;
  final String amountDisplay;
  final String customerName;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: checkoutUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment link copied.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final message = 'Hi $customerName, please pay $amountDisplay '
        'using this secure link: $checkoutUrl';
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusXl),
            border: Border.all(color: DebtsUi.border, width: 1.5),
            boxShadow: DebtsUi.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: DebtsUi.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Share payment link',
                style: TextStyle(
                  fontFamily: 'Constantia',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: DebtsUi.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Send the link to $customerName via WhatsApp, SMS, or any '
                'other app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DebtsUi.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 100),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: DebtsUi.surface2,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
                  border: Border.all(color: DebtsUi.border, width: 1.5),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      checkoutUrl,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: DebtsUi.textPrimary,
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
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DebtsUi.textPrimary,
                        side: const BorderSide(
                          color: DebtsUi.border,
                          width: 1.5,
                        ),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DebtsUi.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        backgroundColor: DebtsUi.greenMid,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(DebtsUi.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showDebtPaymentLinkShare(
  BuildContext context, {
  required String checkoutUrl,
  required String amountDisplay,
  required String customerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => DebtPaymentLinkShare(
      checkoutUrl: checkoutUrl,
      amountDisplay: amountDisplay,
      customerName: customerName,
    ),
  );
}
