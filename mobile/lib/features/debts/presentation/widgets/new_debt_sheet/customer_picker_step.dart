import 'package:flutter/material.dart';

import '../../../data/models/local_debt_customer.dart';
import '../../utils/debts_ui_tokens.dart';
import '../../utils/debts_ui_utils.dart';

/// Step 1 of the new-debt flow: pick an existing customer or trigger the
/// inline create form. Uses the shared mockup design language.
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
            fontFamily: 'Constantia',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: DebtsUi.textPrimary,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose who owes you. You can add a new one if they aren\'t saved yet.',
          style: TextStyle(
            fontSize: 12.5,
            color: DebtsUi.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          autofocus: false,
          onChanged: (value) => setState(() => _query = value),
          cursorColor: DebtsUi.greenMid,
          style: const TextStyle(fontSize: 14, color: DebtsUi.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by name or phone',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: DebtsUi.textMuted,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: DebtsUi.textMuted,
            ),
            filled: true,
            fillColor: DebtsUi.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide: const BorderSide(color: DebtsUi.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
              borderSide:
                  const BorderSide(color: DebtsUi.greenMid, width: 1.8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: DebtsUi.textMuted,
                    ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: DebtsUi.greenPale,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.greenLight, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: DebtsUi.ctaGradient,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                ),
                child: const Icon(
                  Icons.person_add_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a new customer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DebtsUi.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Quick — just name and phone.',
                      style: TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: DebtsUi.greenMid,
              ),
            ],
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.border, width: 1.5),
            boxShadow: DebtsUi.shadowSm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasBalance
                      ? DebtsUi.avatarGoldBg
                      : DebtsUi.avatarGreenBg,
                  borderRadius: BorderRadius.circular(DebtsUi.radiusSm),
                  border: Border.all(
                    color: hasBalance
                        ? DebtsUi.avatarGoldBorder
                        : DebtsUi.avatarGreenBorder,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: hasBalance
                        ? DebtsUi.avatarGoldFg
                        : DebtsUi.avatarGreenFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
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
                        fontSize: 14,
                        color: DebtsUi.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phoneNumber ?? 'No phone on file',
                      style: const TextStyle(
                        fontSize: 12,
                        color: DebtsUi.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasBalance ? DebtsUi.openBg : DebtsUi.settledBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasBalance
                        ? DebtsUi.openBorder
                        : DebtsUi.settledBorder,
                    width: 1,
                  ),
                ),
                child: Text(
                  hasBalance
                      ? DebtsUiUtils.formatMinor(outstanding)
                      : 'Cleared',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        hasBalance ? DebtsUi.openFg : DebtsUi.settledFg,
                  ),
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DebtsUi.surface2,
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        border: Border.all(color: DebtsUi.border, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 20,
            color: DebtsUi.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasQuery
                  ? 'No matches for "$query". Try a different name, or add a new customer above.'
                  : 'You don\'t have any customers saved yet. Tap "Add a new customer" above.',
              style: const TextStyle(
                fontSize: 12.5,
                color: DebtsUi.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
