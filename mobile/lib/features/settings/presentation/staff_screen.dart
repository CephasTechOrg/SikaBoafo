import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../data/settings_api.dart';

final _settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(ref.watch(apiClientProvider)),
);

final _staffListProvider = FutureProvider<List<StaffMember>>((ref) {
  return ref.watch(_settingsApiProvider).listStaff();
});

final _pendingInvitesProvider = FutureProvider<List<StaffInvite>>((ref) {
  return ref.watch(_settingsApiProvider).listPendingInvites();
});

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffListProvider);
    final invitesAsync = ref.watch(_pendingInvitesProvider);
    final members = staffAsync.valueOrNull ?? const <StaffMember>[];
    final invites = invitesAsync.valueOrNull ?? const <StaffInvite>[];
    final activeCount = members.where((m) => m.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.shell),
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.hero),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeaderActionButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Staff',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Invite teammates and manage store access',
                                  style: TextStyle(
                                    color: Color(0xFFC7D0E5),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _HeaderActionButton(
                            icon: Icons.person_add_rounded,
                            onTap: () => _showInviteSheet(context, ref),
                            tooltip: 'Invite staff',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StaffHeroChip(
                            label: '${members.length}',
                            value: 'Members',
                            tone: AppColors.gold,
                          ),
                          const SizedBox(width: 8),
                          _StaffHeroChip(
                            label: '$activeCount',
                            value: 'Active',
                            tone: const Color(0xFF8BE0B2),
                          ),
                          const SizedBox(width: 8),
                          _StaffHeroChip(
                            label: '${invites.length}',
                            value: 'Pending',
                            tone: AppColors.gold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: PremiumSurface(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_staffListProvider);
                    ref.invalidate(_pendingInvitesProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      _PendingInvitesSection(ref: ref),
                      const SizedBox(height: 16),
                      _ActiveStaffSection(ref: ref),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        onInvited: () {
          ref.invalidate(_pendingInvitesProvider);
        },
        settingsApi: ref.read(_settingsApiProvider),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

class _StaffHeroChip extends StatelessWidget {
  const _StaffHeroChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInvitesSection extends StatelessWidget {
  const _PendingInvitesSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(_pendingInvitesProvider);
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeading(
            title: 'Pending Invitations',
            caption:
                'People who still need to sign in and accept store access.',
          ),
          const SizedBox(height: 14),
          invitesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorPanel(message: error.toString()),
            data: (invites) {
              if (invites.isEmpty) {
                return const _InlineEmptyState(
                  icon: Icons.mark_email_read_rounded,
                  title: 'No pending invites',
                  message:
                      'New staff invitations will appear here until the invited user signs in.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < invites.length; i++) ...[
                    _InviteTile(invite: invites[i]),
                    if (i != invites.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite});

  final StaffInvite invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.phoneNumber,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  invite.roleDisplay,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const _StatusPill(
            label: 'Pending',
            foreground: AppColors.warning,
            background: AppColors.warningSoft,
          ),
        ],
      ),
    );
  }
}

class _ActiveStaffSection extends StatelessWidget {
  const _ActiveStaffSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(_staffListProvider);
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeading(
            title: 'Team Members',
            caption:
                'Review access, change roles, and deactivate staff when needed.',
          ),
          const SizedBox(height: 14),
          staffAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => _ErrorPanel(message: err.toString()),
            data: (members) {
              if (members.isEmpty) {
                return const _InlineEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No staff members yet',
                  message:
                      'Use the invite button above to bring your first teammate into the store.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < members.length; i++) ...[
                    _StaffTile(
                      member: members[i],
                      onRoleChanged: (newRole) async {
                        await ref.read(_settingsApiProvider).updateRole(
                              staffUserId: members[i].userId,
                              role: newRole,
                            );
                        ref.invalidate(_staffListProvider);
                      },
                      onDeactivate: () async {
                        await ref
                            .read(_settingsApiProvider)
                            .deactivateStaff(members[i].userId);
                        ref.invalidate(_staffListProvider);
                      },
                    ),
                    if (i != members.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.onRoleChanged,
    required this.onDeactivate,
  });

  final StaffMember member;
  final Future<void> Function(String role) onRoleChanged;
  final Future<void> Function() onDeactivate;

  @override
  Widget build(BuildContext context) {
    final initials = (member.fullName?.isNotEmpty == true
            ? member.fullName![0]
            : member.phoneNumber[0])
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.mint,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName ?? member.phoneNumber,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.fullName != null
                          ? member.phoneNumber
                          : member.roleDisplay,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (member.isActive)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onSelected: (value) async {
                    if (value == 'deactivate') {
                      final confirmed = await _confirmDeactivate(context);
                      if (confirmed == true) {
                        await onDeactivate();
                      }
                    } else {
                      await onRoleChanged(value);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'manager',
                      child: Text('Set as Manager'),
                    ),
                    PopupMenuItem(
                      value: 'cashier',
                      child: Text('Set as Cashier'),
                    ),
                    PopupMenuItem(
                      value: 'stock_keeper',
                      child: Text('Set as Stock Keeper'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Text(
                        'Deactivate',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                label: member.roleDisplay,
                foreground: AppColors.forest,
                background: AppColors.mint,
              ),
              _StatusPill(
                label: member.isActive ? 'Active' : 'Inactive',
                foreground:
                    member.isActive ? AppColors.success : AppColors.muted,
                background: member.isActive
                    ? AppColors.successSoft
                    : AppColors.surfaceAlt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeactivate(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate staff member?'),
        content: Text(
          'This will prevent ${member.fullName ?? member.phoneNumber} from accessing the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({
    required this.onInvited,
    required this.settingsApi,
  });

  final VoidCallback onInvited;
  final SettingsApi settingsApi;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _phoneCtrl = TextEditingController();
  String _role = 'cashier';
  bool _loading = false;
  String? _error;

  static const _roles = [
    ('cashier', 'Cashier'),
    ('manager', 'Manager'),
    ('stock_keeper', 'Stock Keeper'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumSheetFrame(
      title: 'Invite Staff Member',
      subtitle:
          'They will be linked to your store when they first sign in with the invited phone number.',
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
      badge: const PremiumBadge(
        label: 'Team access',
        icon: Icons.person_add_alt_1_rounded,
        foreground: AppColors.forest,
        background: AppColors.successSoft,
      ),
      trailing: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumPanel(
            child: PremiumSectionHeading(
              title: 'Invitation details',
              caption:
                  'Choose the phone number and the role the teammate should start with.',
            ),
          ),
          const SizedBox(height: 14),
          PremiumPanel(
            child: Column(
              children: [
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '0244123456',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.$1,
                          child: Text(r.$2),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text('Send Invitation'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 8) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.settingsApi.inviteStaff(phoneNumber: phone, role: _role);
      widget.onInvited();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Failed to send invitation. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
            ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.info, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2C9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
