import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/utils/user_friendly_error.dart';
import '../../data/debt_reminders_repository.dart';
import '../../providers/debt_reminders_provider.dart';

/// Bottom sheet that lets the merchant pick a future date + time, write an
/// optional message, and schedule a local notification.
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
    // Sensible defaults: tomorrow at 09:00.
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
                primary: AppColors.forestDark,
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
                primary: AppColors.forestDark,
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppShadows.elevated,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 14),
                  const Text(
                    'Set a reminder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We\'ll send a local notification at the time you pick so '
                    'you remember to follow up with ${widget.customerName}.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Reminder message (optional)',
                      hintText:
                          'What should the notification say to nudge you?',
                      filled: true,
                      fillColor: AppColors.surface,
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
                        borderSide: const BorderSide(
                          color: AppColors.forest,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.alarm_rounded, size: 18),
                      label: Text(_saving ? 'Scheduling…' : 'Schedule reminder'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestDark,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
