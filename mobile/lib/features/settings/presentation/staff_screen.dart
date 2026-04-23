import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/providers/core_providers.dart';
import '../data/settings_api.dart';

// ─── providers ────────────────────────────────────────────────────────────────

final _settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(ref.watch(apiClientProvider)),
);

final _staffListProvider = FutureProvider<List<StaffMember>>((ref) {
  return ref.watch(_settingsApiProvider).listStaff();
});

final _pendingInvitesProvider = FutureProvider<List<StaffInvite>>((ref) {
  return ref.watch(_settingsApiProvider).listPendingInvites();
});

// ─── screen ───────────────────────────────────────────────────────────────────

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Invite staff',
            onPressed: () => _showInviteSheet(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_staffListProvider);
          ref.invalidate(_pendingInvitesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PendingInvitesSection(ref: ref),
            const SizedBox(height: 16),
            _ActiveStaffSection(ref: ref),
          ],
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InviteSheet(
        onInvited: () {
          ref.invalidate(_pendingInvitesProvider);
        },
        settingsApi: ref.read(_settingsApiProvider),
      ),
    );
  }
}

// ─── pending invites ──────────────────────────────────────────────────────────

class _PendingInvitesSection extends StatelessWidget {
  const _PendingInvitesSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final invitesAsync = ref.watch(_pendingInvitesProvider);
    return invitesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Invitations',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 8),
            ...invites.map((inv) => _InviteTile(invite: inv)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite});
  final StaffInvite invite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.mail_outline_rounded, color: AppColors.warning, size: 20),
        ),
        title: Text(invite.phoneNumber),
        subtitle: Text(invite.roleDisplay),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Pending',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                ),
          ),
        ),
      ),
    );
  }
}

// ─── active staff ─────────────────────────────────────────────────────────────

class _ActiveStaffSection extends StatelessWidget {
  const _ActiveStaffSection({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(_staffListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Members',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.muted,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 8),
        staffAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => _ErrorCard(message: err.toString()),
          data: (members) {
            if (members.isEmpty) {
              return const _EmptyState();
            }
            return Column(
              children: members
                  .map(
                    (m) => _StaffTile(
                      member: m,
                      onRoleChanged: (newRole) async {
                        await ref
                            .read(_settingsApiProvider)
                            .updateRole(staffUserId: m.userId, role: newRole);
                        ref.invalidate(_staffListProvider);
                      },
                      onDeactivate: () async {
                        await ref.read(_settingsApiProvider).deactivateStaff(m.userId);
                        ref.invalidate(_staffListProvider);
                      },
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(member.fullName ?? member.phoneNumber),
        subtitle: Text(
          member.fullName != null ? member.phoneNumber : member.roleDisplay,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RolePill(roleDisplay: member.roleDisplay),
            if (member.isActive)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onSelected: (value) async {
                  if (value == 'deactivate') {
                    final confirmed = await _confirmDeactivate(context);
                    if (confirmed == true) onDeactivate();
                  } else {
                    onRoleChanged(value);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'manager',
                    child: Text('Set as Manager'),
                  ),
                  const PopupMenuItem(
                    value: 'cashier',
                    child: Text('Set as Cashier'),
                  ),
                  const PopupMenuItem(
                    value: 'stock_keeper',
                    child: Text('Set as Stock Keeper'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
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

class _RolePill extends StatelessWidget {
  const _RolePill({required this.roleDisplay});
  final String roleDisplay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        roleDisplay,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.forest,
            ),
      ),
    );
  }
}

// ─── invite sheet ─────────────────────────────────────────────────────────────

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite Staff Member',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'They will be linked to your store when they first sign in.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
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
                .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                .toList(growable: false),
            onChanged: (v) {
              if (v != null) setState(() => _role = v);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Send Invitation'),
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
    } catch (e) {
      setState(() => _error = 'Failed to send invitation. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── helpers ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 56, color: AppColors.mutedSoft),
          const SizedBox(height: 12),
          Text(
            'No staff members yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the + button to invite your first team member.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.dangerSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
      ),
    );
  }
}
