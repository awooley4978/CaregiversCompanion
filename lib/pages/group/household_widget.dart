// Household (Care Circle group) page — security phase 2.
//
// The group page from design §6.1 phase 2, labeled "Household" in the Care
// Circle UI (D5). It loads the user's ACTIVE org through
// loadOrgSnapshot(), which re-verifies active membership at the app layer
// before returning any org data (D1: users/{uid}.activeGroupId is a context
// selector only — it never authorizes by itself). Actions are role-gated:
// owner sees everything, admin sees member management (never transfer/delete
// org, never owner-role changes), caregiver/viewer see the members list only.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/backend/schema/invites_record.dart';
import '/backend/schema/members_record.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'household_model.dart';
export 'household_model.dart';

class HouseholdWidget extends StatefulWidget {
  const HouseholdWidget({super.key});

  static String routeName = 'Household';
  static String routePath = '/household';

  @override
  State<HouseholdWidget> createState() => _HouseholdWidgetState();
}

class _HouseholdWidgetState extends State<HouseholdWidget> {
  late HouseholdModel _model;

  late Future<OrgSnapshot?> _future;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _canManage {
    final myRole = _myRole;
    return myRole == kRoleOwner || myRole == kRoleAdmin;
  }

  bool get _isOwner => _myRole == kRoleOwner;

  String? _myRole;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HouseholdModel());
    _future = _load();
  }

  Future<OrgSnapshot?> _load() async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }
    final snapshot = await loadOrgSnapshot(uid);
    if (snapshot != null) {
      for (final member in snapshot.activeMembers) {
        if (member.uid == uid) {
          _myRole = member.role;
          break;
        }
      }
    }
    return snapshot;
  }

  void _reload() {
    safeSetState(() {
      _future = _load();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? FlutterFlowTheme.of(context).error : null,
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action,
      {required String successMessage}) async {
    try {
      await action();
      if (mounted) {
        _showMessage(successMessage);
      }
      _reload();
    } on OrgAccessDeniedException catch (e) {
      _showMessage(e.message, isError: true);
      _reload();
    } catch (_) {
      _showMessage('Something went wrong. Please try again.', isError: true);
      _reload();
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        foregroundColor: FlutterFlowTheme.of(context).onPrimary,
        title: Text('Household',
            style: FlutterFlowTheme.of(context).titleLarge?.copyWith(
                  color: FlutterFlowTheme.of(context).onPrimary,
                )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.safePop(),
        ),
      ),
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: FutureBuilder<OrgSnapshot?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 48.0,
                        color: FlutterFlowTheme.of(context).secondaryText),
                    const SizedBox(height: 12.0),
                    Text(
                      snapshot.hasError
                          ? 'Could not load this household.'
                          : 'You are not an active member of this household.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                    const SizedBox(height: 16.0),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final org = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _orgHeaderCard(org.org),
                const SizedBox(height: 16.0),
                if (_canManage) _inviteCard(org.org.id),
                const SizedBox(height: 16.0),
                _membersCard(org.org.id, org.activeMembers),
                if (org.pendingInvites.isNotEmpty || _canManage)
                  const SizedBox(height: 16.0),
                if (org.pendingInvites.isNotEmpty || _canManage)
                  _invitesCard(org.org.id, org.pendingInvites),
                if (_isOwner) ...[
                  const SizedBox(height: 16.0),
                  _ownerCard(org.org.id, org.activeMembers),
                ],
                const SizedBox(height: 32.0),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _orgHeaderCard(OrganizationsRecord org) {
    final kindLabel = org.kind == kFamilyOrgKind
        ? 'Family · Care Circle'
        : 'Organization';
    return Card(
      color: FlutterFlowTheme.of(context).secondaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: FlutterFlowTheme.of(context).primary,
              child: Icon(Icons.family_restroom_rounded,
                  color: FlutterFlowTheme.of(context).onPrimary),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(org.name,
                      style: FlutterFlowTheme.of(context).titleMedium),
                  const SizedBox(height: 4.0),
                  Text(kindLabel,
                      style: FlutterFlowTheme.of(context).bodySmall),
                ],
              ),
            ),
            _roleChip(_myRole ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String role) {
    final theme = FlutterFlowTheme.of(context);
    final (label, color) = switch (role) {
      kRoleOwner => ('Owner', theme.primary),
      kRoleAdmin => ('Admin', theme.info),
      kRoleViewer => ('Viewer', theme.secondary),
      _ => ('Caregiver', theme.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Text(label,
          style: theme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _inviteCard(String orgId) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      color: theme.secondaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite a caregiver', style: theme.titleSmall),
            const SizedBox(height: 12.0),
            TextField(
              controller: _model.inviteEmailController,
              focusNode: _model.inviteEmailFocusNode,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email address',
                hintText: 'name@example.com',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                filled: true,
                fillColor: theme.primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                DropdownButton<String>(
                  value: _model.inviteRole,
                  items: const [
                    DropdownMenuItem(
                        value: kRoleCaregiver, child: Text('Caregiver')),
                    DropdownMenuItem(value: kRoleViewer, child: Text('Viewer')),
                    DropdownMenuItem(value: kRoleAdmin, child: Text('Admin')),
                  ],
                  onChanged: (value) => safeSetState(() {
                    _model.inviteRole = value ?? kRoleCaregiver;
                  }),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _model.inviting
                      ? null
                      : () async {
                          safeSetState(() => _model.inviting = true);
                          await _runAction(
                            () => createInvite(
                              orgId: orgId,
                              email: _model.inviteEmailController.text,
                              role: _model.inviteRole,
                              invitedByUid: _uid ?? '',
                              invitedByName: FirebaseAuth
                                  .instance.currentUser?.displayName,
                            ),
                            successMessage: 'Invite sent.',
                          );
                          safeSetState(() {
                            _model.inviting = false;
                            _model.inviteEmailController.clear();
                          });
                        },
                  icon: const Icon(Icons.send_rounded, size: 18.0),
                  label: Text(_model.inviting ? 'Sending…' : 'Invite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersCard(String orgId, List<MembersRecord> members) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      color: theme.secondaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members (${members.length})', style: theme.titleSmall),
            const SizedBox(height: 8.0),
            if (members.isEmpty)
              Text('No members yet.', style: theme.bodySmall)
            else
              ...members.map((member) => _memberTile(orgId, member)),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(String orgId, MembersRecord member) {
    final theme = FlutterFlowTheme.of(context);
    final isSelf = member.uid == _uid;
    final canActOn = _canManage && !isSelf &&
        (member.role != kRoleOwner || _isOwner);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.alternate,
        child: Text(
          _initials(member.displayName.isNotEmpty
              ? member.displayName
              : member.email),
          style: theme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        member.displayName.isNotEmpty
            ? member.displayName
            : (member.email.isNotEmpty ? member.email : member.uid),
        style: theme.bodyMedium,
      ),
      subtitle: Text(
        member.email.isNotEmpty
            ? member.email
            : (isSelf ? 'You' : member.uid),
        style: theme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roleChip(member.role),
          if (canActOn)
            PopupMenuButton<String>(
              onSelected: (action) => _memberAction(orgId, member, action),
              itemBuilder: (context) => [
                if (_isOwner)
                  const PopupMenuItem(
                      value: 'transfer', child: Text('Transfer ownership')),
                if (member.role != kRoleOwner)
                  const PopupMenuItem(
                      value: 'promote-admin', child: Text('Make admin')),
                if (member.role == kRoleAdmin)
                  const PopupMenuItem(
                      value: 'demote-caregiver',
                      child: Text('Make caregiver')),
                if (member.role != kRoleOwner && member.role != kRoleCaregiver)
                  const PopupMenuItem(
                      value: 'promote-caregiver',
                      child: Text('Make caregiver')),
                if (member.role == kRoleCaregiver)
                  const PopupMenuItem(
                      value: 'demote-viewer', child: Text('Make viewer')),
                if (member.role != kRoleOwner)
                  const PopupMenuItem(
                      value: 'remove', child: Text('Remove from household')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _memberAction(
      String orgId, MembersRecord member, String action) async {
    final uid = _uid ?? '';
    switch (action) {
      case 'transfer':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transfer ownership?'),
            content: Text(
                '${member.displayName.isNotEmpty ? member.displayName : member.email} will become the owner and you will become an admin.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Transfer')),
            ],
          ),
        );
        if (confirmed == true) {
          await _runAction(
            () => transferOwnership(
                orgId: orgId, actingUid: uid, newOwnerUid: member.uid),
            successMessage: 'Ownership transferred.',
          );
        }
      case 'remove':
        await _runAction(
          () => removeMember(
              orgId: orgId, actingUid: uid, targetUid: member.uid),
          successMessage: 'Member removed.',
        );
      case 'promote-admin':
        await _runAction(
          () => setMemberRole(
              orgId: orgId,
              actingUid: uid,
              targetUid: member.uid,
              newRole: kRoleAdmin),
          successMessage: 'Role updated.',
        );
      case 'promote-caregiver':
        await _runAction(
          () => setMemberRole(
              orgId: orgId,
              actingUid: uid,
              targetUid: member.uid,
              newRole: kRoleCaregiver),
          successMessage: 'Role updated.',
        );
      case 'demote-viewer':
        await _runAction(
          () => setMemberRole(
              orgId: orgId,
              actingUid: uid,
              targetUid: member.uid,
              newRole: kRoleViewer),
          successMessage: 'Role updated.',
        );
    }
  }

  Widget _invitesCard(String orgId, List<InviteRecord> invites) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      color: theme.secondaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending invites (${invites.length})', style: theme.titleSmall),
            const SizedBox(height: 8.0),
            if (invites.isEmpty)
              Text('No pending invites.', style: theme.bodySmall)
            else
              ...invites.map((invite) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.mail_outline_rounded,
                        color: theme.secondaryText),
                    title: Text(invite.invitedEmail, style: theme.bodyMedium),
                    subtitle: Text(
                      '${invite.role} · invited by '
                      '${invite.invitedByName.isNotEmpty ? invite.invitedByName : invite.invitedBy}',
                      style: theme.bodySmall,
                    ),
                    trailing: _canManage
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Revoke invite',
                            onPressed: () => _runAction(
                              () => revokeInvite(
                                  orgId: orgId,
                                  email: invite.invitedEmail,
                                  actingUid: _uid ?? ''),
                              successMessage: 'Invite revoked.',
                            ),
                          )
                        : null,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _ownerCard(String orgId, List<MembersRecord> members) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      color: theme.secondaryBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner settings', style: theme.titleSmall),
            const SizedBox(height: 8.0),
            Text(
              'You own this household. You can transfer ownership or delete it — '
              'deleting removes the household and all its members.',
              style: theme.bodySmall,
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _transferDialog(orgId, members),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18.0),
                  label: const Text('Transfer ownership'),
                ),
                const SizedBox(width: 8.0),
                OutlinedButton.icon(
                  onPressed: () => _deleteDialog(orgId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18.0),
                  label: const Text('Delete household'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transferDialog(String orgId, List<MembersRecord> members) async {
    final candidates =
        members.where((m) => m.uid != _uid && m.role != kRoleOwner).toList();
    if (candidates.isEmpty) {
      _showMessage('There is no other member to transfer ownership to.',
          isError: true);
      return;
    }
    final target = await showDialog<MembersRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transfer ownership to…'),
        children: candidates
            .map((member) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, member),
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName
                        : member.email,
                  ),
                ))
            .toList(),
      ),
    );
    if (target == null) {
      return;
    }
    await _runAction(
      () => transferOwnership(
          orgId: orgId, actingUid: _uid ?? '', newOwnerUid: target.uid),
      successMessage: 'Ownership transferred.',
    );
  }

  Future<void> _deleteDialog(String orgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this household?'),
        content: const Text(
            'This permanently deletes the household and removes all of its '
            'members. Care recipients are not deleted by this action.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => deleteOrg(orgId: orgId, actingUid: _uid ?? ''),
        successMessage: 'Household deleted.',
      );
      if (mounted) {
        context.safePop();
      }
    }
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty);
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length > 1) {
      return first + parts.elementAt(1).characters.first.toUpperCase();
    }
    return first;
  }
}
