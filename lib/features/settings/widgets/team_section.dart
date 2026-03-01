import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/state/team_context_controller.dart';
import '../../../core/utils/error_handler.dart';

class TeamSection extends StatefulWidget {
  const TeamSection({super.key});

  @override
  State<TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<TeamSection> {
  final _displayNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _isSaving = false;
  bool _isInviting = false;
  bool _isLoadingMembers = true;
  bool _isUploadingLogo = false;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingInvites = [];

  @override
  void initState() {
    super.initState();
    final controller = TeamContextController.instance;
    _displayNameController.text = controller.workspaceDisplayName;
    _brandNameController.text = controller.brandName ?? '';
    _fetchMembersAndInvites();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _brandNameController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // _fetchMembersAndInvites
  //
  // BUG 1 — ghost inactive rows in Active Members list:
  //   The previous query had no status filter on team_members, so rows that
  //   Phase A of team-accept-invite set to 'inactive' (ghost default-workspace
  //   owner rows) were shown in the Active Members section.
  //   FIX: add `.eq('status', 'active')` to the team_members query.
  //
  // BUG 2 — duplicate pending + active for the same email:
  //   After a user accepts an invite, the edge function marks team_invites
  //   status → 'accepted'. But if Phase C failed (non-fatal warning), or if
  //   the user was re-invited after a partial failure, a 'pending' row can
  //   survive in team_invites even though the person is now active in
  //   team_members. The query fetches both and the UI shows both.
  //   FIX: after fetching, build a Set of active member emails and filter
  //   _pendingInvites to exclude any email already in that set.
  //   This is a belt-and-suspenders client-side guard; the edge function's
  //   Phase C already attempts to mark invites 'accepted' on the server.
  // ---------------------------------------------------------------------------
  Future<void> _fetchMembersAndInvites() async {
    setState(() => _isLoadingMembers = true);
    final teamId = TeamContextController.instance.teamId;
    if (teamId == null) return;

    try {
      // 1. Fetch only ACTIVE team members.
      //    Inactive rows (ghost workspaces from Phase A deactivation) must not
      //    appear in the UI — filter them at the query level, not in the widget.
      final membersResponse = await _supabase
          .from('team_members')
          .select('*')
          .eq('team_id', teamId)
          .eq('status', 'active'); // ← FIX: was missing, allowed ghost rows
      final membersData = List<Map<String, dynamic>>.from(membersResponse);

      // 2. Fetch pending invites.
      final invitesResponse = await _supabase
          .from('team_invites')
          .select('*')
          .eq('team_id', teamId)
          .eq('status', 'pending');
      final invitesData = List<Map<String, dynamic>>.from(invitesResponse);

      // 3. Fetch profiles for active members.
      final userIds = membersData
          .map((m) => m['user_id'] as String?)
          .where((id) => id != null)
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, email, full_name, avatar_url')
            .inFilter('id', userIds);
        final profilesData =
            List<Map<String, dynamic>>.from(profilesResponse);
        profilesMap = {for (var p in profilesData) p['id'] as String: p};
      }

      // 4. Merge profiles into members.
      final mergedMembers = membersData.map((member) {
        final userId = member['user_id'] as String?;
        final profile = profilesMap[userId] ?? {};
        return {...member, 'profiles': profile};
      }).toList();

      // 5. Build a set of active-member emails (case-insensitive).
      //    citext in Postgres is case-insensitive; normalise in Dart too.
      final activeMemberEmails = mergedMembers
          .map((m) {
            // Try profile email first, fall back to team_members.email
            final profileEmail =
                (m['profiles'] as Map)['email'] as String? ?? '';
            final memberEmail = m['email'] as String? ?? '';
            return (profileEmail.isNotEmpty ? profileEmail : memberEmail)
                .toLowerCase();
          })
          .where((e) => e.isNotEmpty)
          .toSet();

      // 6. Filter pending invites: exclude any email already active.
      //    This is the client-side guard for the edge case where Phase C of
      //    team-accept-invite didn't mark the invite 'accepted' (non-fatal
      //    path), leaving a stale 'pending' row for someone who is now active.
      final deduplicatedInvites = invitesData.where((invite) {
        final inviteEmail =
            (invite['email'] as String? ?? '').toLowerCase();
        return !activeMemberEmails.contains(inviteEmail);
      }).toList();

      if (mounted) {
        setState(() {
          _members = mergedMembers;
          _pendingInvites = deduplicatedInvites;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(
          context,
          e,
          customMessage: 'Failed to load team members',
        );
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final controller = TeamContextController.instance;
    final teamId = controller.teamId;
    if (teamId == null) return;

    try {
      await _supabase
          .from('team_profiles')
          .update({
            'display_name': _displayNameController.text.trim(),
            'brand_name': _brandNameController.text.trim(),
          })
          .eq('team_id', teamId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace settings updated')),
        );
        await controller.refresh();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e,
            customMessage: 'Error updating settings');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final controller = TeamContextController.instance;
    final teamId = controller.teamId;
    if (teamId == null) return;

    setState(() => _isUploadingLogo = true);

    try {
      final ext = image.path.split('.').last.toLowerCase();
      final fileName = '$teamId/logo.$ext';
      final bytes = await image.readAsBytes();

      await _supabase.storage
          .from('team-assets')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));

      final publicUrl =
          _supabase.storage.from('team-assets').getPublicUrl(fileName);

      await _supabase
          .from('team_profiles')
          .update({'avatar_url': publicUrl}).eq('team_id', teamId);

      await controller.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e, customMessage: 'Failed to upload logo');
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  // ── Member actions ─────────────────────────────────────────────────────────

  Future<void> _removeMember(String userId) async {
    final teamId = TeamContextController.instance.teamId;
    try {
      await _supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId!)
          .eq('user_id', userId);
      _fetchMembersAndInvites();
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await _supabase.from('team_invites').delete().eq('id', inviteId);
      _fetchMembersAndInvites();
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e);
    }
  }

  Future<void> _resendInvite(String email) async {
    final teamId = TeamContextController.instance.teamId;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Resending invite…'), duration: Duration(seconds: 1)),
    );
    try {
      await _supabase.functions.invoke('team-invite', body: {
        'team_id': teamId,
        'email': email,
        'role': 'member',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invite resent to $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e, customMessage: 'Failed to resend invite');
      }
    }
  }

  Future<void> _performInvite(String email, String role) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email address')));
      return;
    }

    setState(() => _isInviting = true);
    final teamId = TeamContextController.instance.teamId;

    try {
      await _supabase.functions.invoke('team-invite', body: {
        'team_id': teamId,
        'email': email,
        'role': role,
        'is_admin_toggle': role == 'admin',
      });

      _inviteEmailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Invite sent to $email')));
        _fetchMembersAndInvites();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e,
            customMessage: 'Failed to send invite');
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Invite Team Member'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRole = value);
                    }
                  },
                ),
                if (selectedRole == 'admin')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Admins have elevated access to workspace settings '
                      'and can invite team members.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.amber[800],
                          ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performInvite(emailController.text.trim(), selectedRole);
                },
                child: const Text('Send Invite'),
              ),
            ],
          );
        });
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return ListenableBuilder(
      listenable: TeamContextController.instance,
      builder: (context, _) {
        final controller = TeamContextController.instance;
        final canEditIdentity = controller.canEditWorkspaceIdentity;
        final canManageMembers = controller.canManageTeamMembers;

        // canDeleteTeamMembers = owner only.
        // Used exclusively for the remove-member icon button below.
        final canDeleteMembers = controller.canDeleteTeamMembers;

        if (!controller.isMemberLike) {
          return const Center(child: Text('Access Restricted'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section 1: Workspace Identity ──────────────────────────────
              Text('Workspace Identity',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Manage your shared workspace profile.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // Logo
              Row(
                children: [
                  _buildAvatar(controller, theme),
                  const SizedBox(width: 16),
                  if (canEditIdentity)
                    ElevatedButton.icon(
                      onPressed: _isUploadingLogo ? null : _uploadLogo,
                      icon: _isUploadingLogo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload),
                      label: Text(
                          _isUploadingLogo ? 'Uploading…' : 'Upload Logo'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      enabled: canEditIdentity,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _brandNameController,
                      enabled: canEditIdentity,
                      decoration: const InputDecoration(
                        labelText: 'Brand Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canEditIdentity)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveChanges,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save),
                          label: const Text('Save Changes'),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 64),

              // ── Section 2: Team Members ─────────────────────────────────────
              Text('Team Members', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Invite and manage your team.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              if (canManageMembers) ...[
                if (isSmallScreen) ...[
                  TextField(
                    controller: _inviteEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Invite by Email',
                      hintText: 'colleague@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isInviting ? null : _showInviteDialog,
                      icon: _isInviting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: const Text('Invite'),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Invite by Email',
                            hintText: 'colleague@example.com',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: _isInviting ? null : _showInviteDialog,
                        icon: _isInviting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ],

              if (_isLoadingMembers)
                const Center(child: CircularProgressIndicator())
              else ...[
                // ── Pending Invites ───────────────────────────────────────────
                // Only shows invites whose email is NOT already in active members.
                // (See _fetchMembersAndInvites for the deduplication logic.)
                if (_pendingInvites.isNotEmpty) ...[
                  Text(
                    'Pending Invites',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pendingInvites.length,
                    itemBuilder: (context, index) {
                      final invite = _pendingInvites[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.mail_outline)),
                          title: Text(invite['email'],
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text('Sent: ${invite['created_at']}'),
                          trailing: canManageMembers
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.refresh),
                                      color: Colors.blue,
                                      onPressed: () =>
                                          _resendInvite(invite['email']),
                                      tooltip: 'Resend Invite',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red,
                                      onPressed: () =>
                                          _cancelInvite(invite['id']),
                                      tooltip: 'Cancel Invite',
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],

                // ── Active Members ────────────────────────────────────────────
                Text(
                  'Active Members',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final profile =
                        (member['profiles'] as Map<String, dynamic>?) ?? {};
                    final name =
                        (profile['full_name'] as String?) ?? 'Unknown';
                    final email =
                        (profile['email'] as String?) ?? 'No Email';
                    final role =
                        (member['role'] as String? ?? '').toUpperCase();
                    final isMe = member['user_id'] ==
                        _supabase.auth.currentUser?.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profile['avatar_url'] != null
                              ? NetworkImage(profile['avatar_url'] as String)
                              : null,
                          child: profile['avatar_url'] == null
                              ? Text(name.isNotEmpty ? name[0] : '?')
                              : null,
                        ),
                        title: Text(
                          '$name${isMe ? ' (You)' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            Text(email, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSmallScreen)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    color: theme.colorScheme
                                        .onSecondaryContainer,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // ── Remove member button ─────────────────────────
                            // RBAC: shown to owner + admin (canManageTeamMembers),
                            // but only ENABLED for owner (canDeleteTeamMembers).
                            //
                            // Admins see the button greyed-out with a tooltip
                            // explaining the restriction, rather than hiding it.
                            // Hidden buttons create confusion ("why can't I do
                            // what I can see others do?"). Visible-but-disabled
                            // communicates the boundary clearly.
                            if (canManageMembers && !isMe) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: canDeleteMembers
                                    ? 'Remove Member'
                                    : 'Only the workspace owner can remove members',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    // Grey out the icon when admin cannot delete
                                    color: canDeleteMembers
                                        ? Colors.red
                                        : theme.disabledColor,
                                  ),
                                  // null onPressed = unclickable, visually
                                  // signals the disabled state to Flutter
                                  onPressed: canDeleteMembers
                                      ? () => _removeMember(
                                          member['user_id'] as String)
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(TeamContextController controller, ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        image: controller.workspaceAvatarUrl != null
            ? DecorationImage(
                image: NetworkImage(controller.workspaceAvatarUrl!),
                fit: BoxFit.cover)
            : null,
      ),
      child: controller.workspaceAvatarUrl == null
          ? Icon(Icons.business, color: theme.colorScheme.onPrimary, size: 40)
          : null,
    );
  }
}
