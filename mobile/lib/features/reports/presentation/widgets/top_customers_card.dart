import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../shared/widgets/app_components.dart';
import '../../../debts/data/debts_repository.dart';
class TopCustomersCard extends StatelessWidget {
  const TopCustomersCard({super.key, required this.receivables});
  final List<LocalReceivableRecord> receivables;

  @override
  Widget build(BuildContext context) {
    if (receivables.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        radius: 20,
        borderColor: Color(0xFFEEF1F0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle2, color: Color(0xFF0F7A4A), size: 28),
            SizedBox(height: 10),
            Text(
              'No open debts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      radius: 20,
      borderColor: const Color(0xFFEEF1F0),
      child: Column(
        children: receivables.asMap().entries.map((entry) {
          final idx = entry.key;
          final r = entry.value;
          final name = r.customerName ?? '';
          final initials = name.trim().isEmpty
              ? '?'
              : name
                  .trim()
                  .split(' ')
                  .take(2)
                  .map((w) => w[0])
                  .join()
                  .toUpperCase();

          // Format outstanding amount
          final amountVal = double.tryParse(r.outstandingAmount) ?? 0;
          final amountStr = '₵${amountVal.toStringAsFixed(2)}';

          return Column(
            children: [
              if (idx > 0)
                const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F0)),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    // Avatar — always warn-tint bg, warn fg
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF3E1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFFBE8A2C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Unknown' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Amount in warn color
                    Text(
                      amountStr,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFBE8A2C),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(growable: false),
      ),
    );
  }
}
