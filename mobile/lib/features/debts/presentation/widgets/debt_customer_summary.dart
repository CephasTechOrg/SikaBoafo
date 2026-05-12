import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/models/local_debt_customer.dart';

/// Customer card under the balance hero. Surfaces call / WhatsApp shortcuts
/// when contact info is available.
class DebtCustomerSummary extends StatelessWidget {
  const DebtCustomerSummary({super.key, required this.customer});

  final LocalDebtCustomer customer;

  Future<void> _callPhone(BuildContext context) async {
    final phone = customer.phoneNumber;
    if (phone == null || phone.trim().isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot start a call from this device.')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final raw = (customer.whatsappNumber ?? customer.phoneNumber);
    if (raw == null || raw.trim().isEmpty) return;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp is not installed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        customer.phoneNumber != null && customer.phoneNumber!.trim().isNotEmpty;
    final hasWhatsapp = hasPhone ||
        (customer.whatsappNumber != null &&
            customer.whatsappNumber!.trim().isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasPhone ? customer.phoneNumber! : 'No phone on file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (hasPhone)
            _ContactIconButton(
              icon: Icons.call_rounded,
              tooltip: 'Call ${customer.name}',
              onTap: () => _callPhone(context),
            ),
          if (hasWhatsapp) ...[
            const SizedBox(width: 8),
            _ContactIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'WhatsApp ${customer.name}',
              tone: AppColors.success,
              onTap: () => _openWhatsApp(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.forestDark;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
      ),
    );
  }
}
