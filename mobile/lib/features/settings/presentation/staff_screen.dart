import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/providers/session_role_providers.dart';
import '../../../shared/utils/user_friendly_error.dart';
import '../../dashboard/presentation/widgets/dashboard_mockup_ui.dart';
import '../data/settings_api.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(
    ref.watch(apiClientProvider),
    cache: KvCacheRepository(ref.watch(appDatabaseProvider)),
  ),
);

final _staffListProvider = FutureProvider<List<StaffMember>>((ref) {
  return ref.watch(_settingsApiProvider).listStaff();
});

final _pendingInvitesProvider = FutureProvider<List<StaffInvite>>((ref) {
  return ref.watch(_settingsApiProvider).listPendingInvites();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwnerAsync = ref.watch(isMerchantOwnerProvider);
    if (isOwnerAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (isOwnerAsync.hasError || isOwnerAsync.valueOrNull == false) {
      return const _OwnerOnlyGate();
    }

    final staffAsync   = ref.watch(_staffListProvider);
    final members      = staffAsync.valueOrNull ?? const <StaffMember>[];
    final activeCount  = members.where((m) => m.isActive).length;

    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final subtitle  = '$activeCount active member${activeCount == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      body: RefreshIndicator(
        color: DashboardMockup.green700,
        onRefresh: () async {
          ref.invalidate(_staffListProvider);
          ref.invalidate(_pendingInvitesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                DashboardMockup.gutter, topPad + 14,
                DashboardMockup.gutter, 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DashboardMockup.lineSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        size: 18,
                        color: DashboardMockup.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff & Team',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: DashboardMockup.ink,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: DashboardMockup.ink2,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showInviteSheet(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DashboardMockup.greenTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.userPlus,
                        size: 18,
                        color: DashboardMockup.green700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Sections ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                DashboardMockup.gutter, 24,
                DashboardMockup.gutter, bottomPad + 32,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PendingInvitesSection(),
                  SizedBox(height: 24),
                  _ActiveStaffSection(),
                ],
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
        onInvited: () => ref.invalidate(_pendingInvitesProvider),
        settingsApi: ref.read(_settingsApiProvider),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SecLabel extends StatelessWidget {
  const _SecLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: DashboardMockup.ink3,
      ),
    );
  }
}

// ── Pending invitations section ───────────────────────────────────────────────

class _PendingInvitesSection extends ConsumerWidget {
  const _PendingInvitesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(_pendingInvitesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SecLabel('Pending Invitations'),
        const SizedBox(height: 12),
        invitesAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(message: userFriendlyError(e)),
          data: (invites) {
            if (invites.isEmpty) {
              return const _EmptyState(
                icon: LucideIcons.mail,
                title: 'No pending invites',
                message: 'Invites appear here until accepted.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < invites.length; i++) ...[
                  _InviteTile(
                    invite: invites[i],
                    onCancel: () async {
                      try {
                        await ref
                            .read(_settingsApiProvider)
                            .cancelInvite(invites[i].inviteId);
                        ref.invalidate(_pendingInvitesProvider);
                      } catch (_) {
                        if (!context.mounted) return;
                        _showError(context, 'Could not cancel invitation. Try again.');
                      }
                    },
                  ),
                  if (i < invites.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Active staff section ──────────────────────────────────────────────────────

class _ActiveStaffSection extends ConsumerWidget {
  const _ActiveStaffSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SecLabel('Team Members'),
        const SizedBox(height: 12),
        staffAsync.when(
          loading: () => const _LoadingCard(),
          error: (e, _) => _ErrorCard(message: userFriendlyError(e)),
          data: (members) {
            if (members.isEmpty) {
              return const _EmptyState(
                icon: LucideIcons.users,
                title: 'No team members yet',
                message: 'Tap + to invite your first teammate.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  _StaffTile(
                    member: members[i],
                    onRoleChanged: (role) async {
                      try {
                        await ref.read(_settingsApiProvider).updateRole(
                              staffUserId: members[i].userId,
                              role: role,
                            );
                        ref.invalidate(_staffListProvider);
                      } catch (_) {
                        if (!context.mounted) return;
                        _showError(context, 'Failed to update role. Please try again.');
                      }
                    },
                    onDeactivate: () async {
                      try {
                        await ref
                            .read(_settingsApiProvider)
                            .deactivateStaff(members[i].userId);
                        ref.invalidate(_staffListProvider);
                      } catch (_) {
                        if (!context.mounted) return;
                        _showError(context, 'Failed to deactivate. Please try again.');
                      }
                    },
                    onReactivate: () async {
                      try {
                        await ref
                            .read(_settingsApiProvider)
                            .reactivateStaff(members[i].userId);
                        ref.invalidate(_staffListProvider);
                      } catch (_) {
                        if (!context.mounted) return;
                        _showError(context, 'Failed to reactivate. Please try again.');
                      }
                    },
                  ),
                  if (i < members.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Invite tile ───────────────────────────────────────────────────────────────

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.onCancel});
  final StaffInvite invite;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: DashboardMockup.warnTint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                LucideIcons.mail,
                size: 20,
                color: DashboardMockup.warn,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.phoneNumber,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DashboardMockup.ink,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    invite.roleDisplay,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DashboardMockup.ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const _StatusPill(
              label: 'Pending',
              fg: DashboardMockup.warn,
              bg: DashboardMockup.warnTint,
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cancel invitation?'),
                    content: Text(
                        'Revoke the pending invite for ${invite.phoneNumber}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Keep'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: DashboardMockup.danger,
                        ),
                        child: const Text('Cancel invite'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await onCancel();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DashboardMockup.lineSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.x,
                  size: 16,
                  color: DashboardMockup.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staff member tile ─────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    required this.onRoleChanged,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final StaffMember member;
  final Future<void> Function(String role) onRoleChanged;
  final Future<void> Function() onDeactivate;
  final Future<void> Function() onReactivate;

  @override
  Widget build(BuildContext context) {
    final name = member.fullName ?? member.phoneNumber;
    final sub = member.fullName != null
        ? member.phoneNumber
        : member.roleDisplay;
    final initial = name[0].toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: DashboardMockup.greenTint,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DashboardMockup.green700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                // Name + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DashboardMockup.ink,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: DashboardMockup.ink2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action
                if (member.isActive)
                  _MoreMenu(
                    onSelected: (value) async {
                      if (value == 'deactivate') {
                        final ok = await _confirmDeactivate(context);
                        if (ok == true) await onDeactivate();
                      } else {
                        await onRoleChanged(value);
                      }
                    },
                  )
                else
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reactivate staff member?'),
                          content: Text(
                              '${member.fullName ?? member.phoneNumber} will be able to sign in again.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Reactivate'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await onReactivate();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: DashboardMockup.greenTint,
                      foregroundColor: DashboardMockup.green700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Reactivate'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatusPill(
                  label: member.roleDisplay,
                  fg: DashboardMockup.green700,
                  bg: DashboardMockup.greenTint,
                ),
                _StatusPill(
                  label: member.isActive ? 'Active' : 'Inactive',
                  fg: member.isActive
                      ? DashboardMockup.green700
                      : DashboardMockup.ink3,
                  bg: member.isActive
                      ? DashboardMockup.greenTint
                      : DashboardMockup.lineSoft,
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
            'This will prevent ${member.fullName ?? member.phoneNumber} from accessing the system.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: DashboardMockup.danger),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onSelected});
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: DashboardMockup.lineSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          LucideIcons.moreHorizontal,
          size: 18,
          color: DashboardMockup.ink2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onSelected: onSelected,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'manager',      child: Text('Set as Manager')),
          PopupMenuItem(value: 'cashier',      child: Text('Set as Cashier')),
          PopupMenuItem(value: 'stock_keeper', child: Text('Set as Stock Keeper')),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'deactivate',
            child: Text('Deactivate',
                style: TextStyle(color: DashboardMockup.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Invite sheet ──────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.onInvited, required this.settingsApi});
  final VoidCallback onInvited;
  final SettingsApi settingsApi;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _phoneCtrl = TextEditingController();
  String  _role    = 'cashier';
  bool    _loading = false;
  String? _error;

  static const _roles = [
    ('cashier',      'Cashier'),
    ('manager',      'Manager'),
    ('stock_keeper', 'Stock Keeper'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: DashboardMockup.lineSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Staff Member',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: DashboardMockup.ink,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'They\'ll be linked when they first sign in.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: DashboardMockup.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      LucideIcons.x,
                      size: 20,
                      color: DashboardMockup.ink3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Form
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone field
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: DashboardMockup.ink,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      hintText: '0244 123 456',
                      hintStyle: const TextStyle(
                          color: DashboardMockup.ink3, fontSize: 14.5),
                      prefixIcon: const Icon(LucideIcons.phone,
                          size: 18, color: DashboardMockup.ink3),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      labelStyle: const TextStyle(
                        color: DashboardMockup.ink3,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: DashboardMockup.green700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: DashboardMockup.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: DashboardMockup.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: DashboardMockup.green700, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Role label
                  Text(
                    'ROLE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: DashboardMockup.ink3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Role chips
                  Row(
                    children: _roles.map((r) {
                      final selected = _role == r.$1;
                      final isLast = r == _roles.last;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _role = r.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 40,
                              decoration: BoxDecoration(
                                color: selected
                                    ? DashboardMockup.green900
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: selected
                                      ? Colors.transparent
                                      : DashboardMockup.line,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                r.$2,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : DashboardMockup.ink2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: DashboardMockup.danger,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: _loading ? null : _submit,
                      style: TextButton.styleFrom(
                        backgroundColor: _loading
                            ? DashboardMockup.lineSoft
                            : DashboardMockup.green600,
                        foregroundColor: _loading
                            ? DashboardMockup.ink3
                            : Colors.white,
                        disabledBackgroundColor: DashboardMockup.lineSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: DashboardMockup.green700,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.send, size: 17),
                                SizedBox(width: 8),
                                Text('Send Invitation'),
                              ],
                            ),
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

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() =>
          _error = 'Enter a valid 10-digit phone number (e.g. 0244123456).');
      return;
    }
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      await widget.settingsApi.inviteStaff(phoneNumber: phone, role: _role);
      widget.onInvited();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanizeInviteError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanizeInviteError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data   = error.response?.data;
      if (status == 409) return 'This phone number already has a pending invite.';
      if (status == 400) {
        if (data is Map<String, dynamic> && data['detail'] is String) {
          return data['detail'] as String;
        }
        return 'Invalid phone number or details.';
      }
      if (status == 403) return 'Only the account owner can invite staff.';
      if (error.type == DioExceptionType.connectionError) {
        return 'No internet connection. Check your network and try again.';
      }
    }
    return 'Failed to send invitation. Please try again.';
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        boxShadow: DashboardMockup.cardShadow,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: DashboardMockup.card,
          borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
          border: Border.all(color: DashboardMockup.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DashboardMockup.greenTint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 20, color: DashboardMockup.green700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DashboardMockup.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DashboardMockup.ink2,
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

// ── Loading card ──────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: DashboardMockup.green700,
          ),
        ),
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardMockup.dangerTint,
        borderRadius: BorderRadius.circular(DashboardMockup.cardRadius),
        border: Border.all(color: const Color(0xFFF2C9C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.alertCircle,
              color: DashboardMockup.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DashboardMockup.danger,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner-only gate ───────────────────────────────────────────────────────────

class _OwnerOnlyGate extends StatelessWidget {
  const _OwnerOnlyGate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardMockup.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF041509),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Staff & Team',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: DashboardMockup.greenTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  LucideIcons.lock,
                  size: 28,
                  color: DashboardMockup.green700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Owner access only',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DashboardMockup.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Only the business owner can invite and manage team members.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DashboardMockup.ink2,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  backgroundColor: DashboardMockup.greenTint,
                  foregroundColor: DashboardMockup.green700,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Back to Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: DashboardMockup.danger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
