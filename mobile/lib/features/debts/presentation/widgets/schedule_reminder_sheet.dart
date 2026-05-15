import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/debt_reminders_repository.dart';
import '../../providers/debt_reminders_provider.dart';
import '../utils/debts_ui_tokens.dart';
import 'debts_gradient_button.dart';

/// Bottom sheet that lets the merchant pick a future date + time, write an
/// optional message, and schedule a local notification. Styled with the
/// shared debts mockup design language.
class ScheduleReminderSheet extends ConsumerStatefulWidget {
  const ScheduleReminderSheet({
    super.key,
    required this.receivableId,
    required this.customerName,
    required this.amountDisplay,
  });

  final String receivableId;
  final String customerName;
  final String amountDisplay;

  @override
  ConsumerState<ScheduleReminderSheet> createState() =>
      _ScheduleReminderSheetState();
}

class _ScheduleReminderSheetState extends ConsumerState<ScheduleReminderSheet> {
  late final TextEditingController _messageCtrl;
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(
      text: defaultReminderMessage(
        customerName: widget.customerName,
        amountDisplay: widget.amountDisplay,
      ),
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _time = const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  DateTime? get _combined {
    if (_date == null || _time == null) return null;
    return DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date ?? now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 3, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: DebtsUi.greenMid,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: DebtsUi.greenMid,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _submit() async {
    final when = _combined;
    if (when == null) {
      setState(() => _error = 'Pick both a date and a time.');
      return;
    }
    if (!when.isAfter(DateTime.now())) {
      setState(() => _error = 'Reminder time must be in the future.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(debtRemindersControllerProvider).schedule(
            receivableId: widget.receivableId,
            customerName: widget.customerName,
            amountDisplay: widget.amountDisplay,
            fireAt: when,
            message: _messageCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder scheduled for ${reminderFireLabel(when)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyError(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: DebtsUi.surface,
              borderRadius: BorderRadius.circular(DebtsUi.radiusXl),
              border: Border.all(color: DebtsUi.border, width: 1.5),
              boxShadow: DebtsUi.shadowLg,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DebtsUi.greenPale,
                          borderRadius:
                              BorderRadius.circular(DebtsUi.radiusSm),
                          border: Border.all(
                              color: DebtsUi.greenLight, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          size: 18,
                          color: DebtsUi.greenMid,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Set a reminder',
                          style: TextStyle(
                            fontFamily: 'Constantia',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: DebtsUi.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 46),
                    child: Text(
                      'We\'ll send a local notification at the time you pick so '
                      'you remember to follow up with ${widget.customerName}.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Date',
                          value: _date == null
                              ? 'Pick a date'
                              : _formatDate(_date!),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerCard(
                          icon: Icons.access_time_rounded,
                          label: 'Time',
                          value: _time == null
                              ? 'Pick a time'
                              : _time!.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageCtrl,
                    maxLines: 3,
                    cursorColor: DebtsUi.greenMid,
                    style: const TextStyle(
                      fontSize: 14,
                      color: DebtsUi.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Reminder message (optional)',
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        color: DebtsUi.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      floatingLabelStyle: const TextStyle(
                        fontSize: 12.5,
                        color: DebtsUi.greenMid,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      hintText:
                          'What should the notification say to nudge you?',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: DebtsUi.textMuted,
                      ),
                      filled: true,
                      fillColor: DebtsUi.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DebtsUi.radiusMd),
                        borderSide: const BorderSide(
                            color: DebtsUi.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DebtsUi.radiusMd),
                        borderSide: const BorderSide(
                            color: DebtsUi.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DebtsUi.radiusMd),
                        borderSide: const BorderSide(
                            color: DebtsUi.greenMid, width: 1.8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: DebtsUi.dangerSoft,
                        borderRadius:
                            BorderRadius.circular(DebtsUi.radiusSm),
                        border: Border.all(
                            color: DebtsUi.dangerBorder, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: DebtsUi.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: DebtsUi.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  DebtsGradientButton(
                    label: 'Schedule reminder',
                    icon: Icons.alarm_rounded,
                    loading: _saving,
                    loadingLabel: 'Scheduling…',
                    onPressed: _saving ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DebtsUi.surface,
            borderRadius: BorderRadius.circular(DebtsUi.radiusMd),
            border: Border.all(color: DebtsUi.border, width: 1.5),
            boxShadow: DebtsUi.shadowSm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: DebtsUi.greenMid),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: DebtsUi.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: DebtsUi.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> showScheduleReminderSheet(
  BuildContext context, {
  required String receivableId,
  required String customerName,
  required String amountDisplay,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => ScheduleReminderSheet(
      receivableId: receivableId,
      customerName: customerName,
      amountDisplay: amountDisplay,
    ),
  );
}
