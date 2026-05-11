import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../data/models/local_debt_customer.dart';
import '../../utils/debts_ui_utils.dart';

/// Step 1 of the new-debt flow: pick an existing customer or trigger the
/// inline create form.
class CustomerPickerStep extends StatefulWidget {
  const CustomerPickerStep({
    super.key,
    required this.customers,
    required this.onPick,
    required this.onCreateNew,
  });

  final List<LocalDebtCustomer> customers;
  final ValueChanged<LocalDebtCustomer> onPick;
  final VoidCallback onCreateNew;

  @override
  State<CustomerPickerStep> createState() => _CustomerPickerStepState();
}

class _CustomerPickerStepState extends State<CustomerPickerStep> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LocalDebtCustomer> get _filtered {
    if (_query.trim().isEmpty) return widget.customers;
    final lower = _query.trim().toLowerCase();
    return widget.customers.where((c) {
      if (c.name.toLowerCase().contains(lower)) return true;
      final phone = c.phoneNumber;
      if (phone != null && phone.toLowerCase().contains(lower)) return true;
      return false;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pick a customer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose who owes you. You can add a new one if they aren\'t saved yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          autofocus: false,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'Search by name or phone',
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.muted,
            ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              borderSide: const BorderSide(color: AppColors.forest, width: 1.4),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.muted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _AddNewCustomerCta(onTap: widget.onCreateNew),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _NoMatchCard(query: _query)
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.36,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              padding: EdgeInsets.zero,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final customer = filtered[index];
                return _CustomerRow(
                  customer: customer,
                  onTap: () => widget.onPick(customer),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AddNewCustomerCta extends StatelessWidget {
  const _AddNewCustomerCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: AppColors.forest.withValues(alpha: 0.30),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_alt_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a new customer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Quick — just name and phone.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final LocalDebtCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outstanding = DebtsUiUtils.amountToMinor(customer.totalOutstanding);
    final hasBalance = outstanding > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.phoneNumber ?? 'No phone on file',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasBalance
                    ? AppColors.dangerSoft
                    : AppColors.successSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                hasBalance
                    ? DebtsUiUtils.formatMinor(outstanding)
                    : 'Cleared',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: hasBalance ? AppColors.danger : AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  const _NoMatchCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off_rounded,
              size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasQuery
                  ? 'No matches for "$query". Try a different name, or add a new customer above.'
                  : 'You don\'t have any customers saved yet. Tap "Add a new customer" above.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
