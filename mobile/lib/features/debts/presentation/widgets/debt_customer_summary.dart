import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/local_debt_customer.dart';
import '../utils/debts_ui_tokens.dart';

/// Contact row under the meta strip on a debt detail screen.
///
/// Visual reference: `index (2).html` `.contact-row` — Call (primary green
/// pale) + Message (neutral surface) buttons sharing a row. Hidden when the
/// customer has no phone on file.
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
    final raw = customer.whatsappNumber ?? customer.phoneNumber;
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
    final hasPhone = customer.phoneNumber != null &&
        customer.phoneNumber!.trim().isNotEmpty;
    final hasWhatsapp = hasPhone ||
        (customer.whatsappNumber != null &&
            customer.whatsappNumber!.trim().isNotEmpty);

    if (!hasPhone && !hasWhatsapp) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (hasPhone)
          Expanded(
            child: _ContactButton(
              icon: Icons.call_rounded,
              label: 'Call',
              primary: true,
              onTap: () => _callPhone(context),
            ),
          ),
        if (hasPhone && hasWhatsapp) const SizedBox(width: 10),
        if (hasWhatsapp)
          Expanded(
            child: _ContactButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              onTap: () => _openWhatsApp(context),
            ),
          ),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? DebtsUi.surface : DebtsUi.avatarNeutralBg;
    final border =
        primary ? DebtsUi.greenMid : DebtsUi.borderNeutral;
    final fg = primary ? DebtsUi.greenMid : DebtsUi.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
