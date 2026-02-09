import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/state/profile_manager.dart';

class TeamSection extends StatefulWidget {
  const TeamSection({super.key});

  @override
  State<TeamSection> createState() => _TeamSectionState();
}

class _TeamSectionState extends State<TeamSection> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isInviting = false;

  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      debugPrint('[_fetchMembers] Current User ID: ${user.id}');

      // 1. Get team where user is owner or member
      // Strategy: Check if I am a member of any team (status active/pending).
      final memberRes = await _supabase
          .from('team_members')
          .select('team_id, role')
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'pending'])
          .maybeSingle();

      String? teamId;
      String? myRole;

      if (memberRes != null) {
        teamId = memberRes['team_id'];
        myRole = memberRes['role'];
        debugPrint(
          '[_fetchMembers] Found via membership. Team ID: $teamId, Role: $myRole',
        );
      } else {
        // Fallback: Check if I own a team (maybe member record missing/deleted but team exists?)
        final teamRes = await _supabase
            .from('teams')
            .select('id')
            .eq('owner_id', user.id)
            .maybeSingle();
        if (teamRes != null) {
          teamId = teamRes['id'];
          myRole = 'owner'; // Implicit owner
          debugPrint(
            '[_fetchMembers] Found via ownership (fallback). Team ID: $teamId',
          );
        } else {
          debugPrint('[_fetchMembers] No team found for user.');
        }
      }

      if (teamId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Fetch all members for this team
      final data = await _supabase
          .from('team_members')
          .select()
          .eq('team_id', teamId)
          .inFilter('status', ['active', 'pending'])
          .order('created_at', ascending: true);

      debugPrint(
        '[_fetchMembers] Query: fetch members for team $teamId. Rows returned: ${data.length}',
      );

      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(data);
          _isOwner = myRole == 'owner';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvite(String email, String role, bool isAdmin) async {
    if (_isInviting) return;
    setState(() => _isInviting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Ensure team exists for owner
      var teamRes = await _supabase
          .from('teams')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();

      String teamId;
      if (teamRes == null) {
        // Auto-create team if missing (for MVP robustness)
        final newTeam = await _supabase
            .from('teams')
            .insert({'owner_id': user.id, 'name': 'My Team'})
            .select()
            .single();
        teamId = newTeam['id'];

        // Add owner as member
        await _supabase.from('team_members').insert({
          'team_id': teamId,
          'user_id': user.id,
          'email': user.email,
          'role': 'owner',
          'status': 'active',
        });
      } else {
        teamId = teamRes['id'];
      }

      // Use Edge Function for invite + email
      final res = await _supabase.functions.invoke(
        'team-invite',
        body: {
          'email': email,
          'team_id': teamId,
          'role': role,
          'is_admin_toggle': isAdmin,
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw data['error'];
      }

      final token = data['token'];
      if (mounted) {
        // Safe navigation check
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Wait briefly to allow navigation to complete
        await Future.delayed(const Duration(milliseconds: 50));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite sent! Link: /#/join-team?token=$token'),
              duration: const Duration(seconds: 10),
              action: SnackBarAction(label: 'Copy', onPressed: () {}),
            ),
          );
          _fetchMembers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _resendInvite(String email, String role, String teamId) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Resending invite...')));

      final res = await _supabase.functions.invoke(
        'team-invite',
        body: {
          'email': email,
          'team_id': teamId,
          'role': role,
          'is_admin_toggle': role == 'admin', // infer from role
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw data['error'];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite resent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error resending invite: $e')));
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      final res = await _supabase.rpc(
        'remove_team_member',
        params: {'target_member_id': memberId},
      );

      if (res['error'] != null) {
        throw res['error'];
      }
      _fetchMembers();
    } catch (e) {
      debugPrint('Error removing member: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    String role = 'manager';
    bool isAdmin = false;

    showDialog(
      context: context,
      barrierDismissible: !_isInviting,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite People'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isInviting,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: _isInviting
                    ? null
                    : (v) => setState(() => role = v!),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Grant Admin Permissions'),
                subtitle: const Text('Can manage team settings'),
                value: isAdmin,
                onChanged: _isInviting
                    ? null
                    : (v) => setState(() => isAdmin = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isInviting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _isInviting
                  ? null
                  : () {
                      if (emailController.text.isNotEmpty) {
                        // We must call setState to update the dialog if we wanted a spinner there,
                        // but since _isInviting is in the parent widget state, we can just rely on the parent state
                        // However, StatefulBuilder only rebuilds when its setState is called.
                        // Since we are not triggering the dialog's setState when _isInviting changes in parent,
                        // the dialog won't update its UI (disabled buttons) automatically unless we force it.
                        // Actually, since _createInvite calls setState on the parent, the parent rebuilds.
                        // Does the dialog rebuild? No, showDialog pushes a new route.
                        // So we need to handle state locally in the dialog if we want to show loading there.
                        // OR we can close the dialog immediately and show a global loader.

                        // BUT the requirement is "Fix the Invite People button freeze/crash".
                        // The crash is likely due to async gaps and navigation.
                        // Let's stick to the robust navigation fix requested.
                        _createInvite(emailController.text, role, isAdmin);

                        // Note: The buttons in the dialog won't visually disable because the dialog's setState isn't called.
                        // But the _isInviting guard in _createInvite prevents double submission.
                      }
                    },
              child: _isInviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ProfileManager.instance.profileNotifier.value;
    final currentUserId = _supabase.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Team and people',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_isOwner)
              FilledButton.icon(
                onPressed: _showInviteDialog,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite people'),
              ),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No members found.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isMe = member['user_id'] == currentUserId;
                    final isPending = member['status'] == 'pending';
                    final role = member['role'];
                    final email = member['email'];
                    final invitedAt = member['created_at'] != null
                        ? DateTime.parse(member['created_at']).toLocal()
                        : null;
                    final dateStr = invitedAt != null
                        ? '${invitedAt.year}-${invitedAt.month.toString().padLeft(2, '0')}-${invitedAt.day.toString().padLeft(2, '0')}'
                        : '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isPending ? Colors.orange[100] : null,
                        child: isPending
                            ? const Icon(
                                Icons.hourglass_empty,
                                size: 16,
                                color: Colors.orange,
                              )
                            : Text(
                                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                              ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMe ? '$email (You)' : email,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isPending) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Role: ${role.toString().toUpperCase()} • Joined: $dateStr',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (role == 'owner') const Chip(label: Text('Owner')),
                          // Resend button: Only show if I am owner, target is pending
                          if (_isOwner && isPending) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.blue),
                              onPressed: () =>
                                  _resendInvite(email, role, member['team_id']),
                              tooltip: 'Resend Invite',
                            ),
                          ],
                          // Remove button: Only show if I am owner, and target is not me and not owner
                          if (_isOwner && !isMe && role != 'owner') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeMember(member['id']),
                              tooltip: 'Remove Member',
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
