import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/state/team_context_controller.dart';

class JoinTeamScreen extends StatefulWidget {
  final String? token;

  const JoinTeamScreen({super.key, this.token});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  String? _infoMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _validateAndJoin();
  }

  Future<void> _validateAndJoin() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid invite link.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
      _isSuccess = false;
    });

    try {
      // 1) Validate invite token (action=prepare)
      // This validates the token exists and is pending, returning email/team info.
      final prep = await _supabase.functions.invoke(
        'team-accept-invite',
        body: {'token': token, 'action': 'prepare'},
      );

      final prepData = (prep.data is Map<String, dynamic>)
          ? (prep.data as Map<String, dynamic>)
          : <String, dynamic>{};

      if (prep.status != 200) {
        throw Exception(
          prepData['error'] ?? 'Invite lookup failed (status ${prep.status})',
        );
      }
      if (prepData['error'] != null) {
        throw Exception(prepData['error']);
      }

      final inviteEmail = (prepData['email'] ?? '').toString().trim();

      // 2) Check Authentication State
      final currentUser = _supabase.auth.currentUser;
      final currentEmail = (currentUser?.email ?? '').toString().trim();

      // Case A: User NOT logged in
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          // Prompt user to check email for password setup link
          _infoMessage =
              'Check your email ($inviteEmail) to set your password. '
              'After setup, you will automatically return here to accept the invite.';
        });
        return;
      }

      // Case B: User logged in, but wrong email
      if (!currentEmail.equalsIgnoreCase(inviteEmail)) {
        // Auto sign-out to prevent confusion
        await _supabase.auth.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage =
              'This invite is for $inviteEmail, but you were logged in as $currentEmail. '
              'You have been signed out. Please try the link again or sign in as the correct user.';
        });
        return;
      }

      // Case C: User logged in correctly -> Accept Invite
      // Force session refresh to ensure valid JWT
      try {
        await _supabase.auth.refreshSession();
      } catch (e) {
        debugPrint('Session refresh warning: $e');
      }

      final acceptRes = await _supabase.functions.invoke(
        'team-accept-invite',
        body: {'token': token, 'action': 'accept'},
      );

      final acceptData = (acceptRes.data is Map<String, dynamic>)
          ? (acceptRes.data as Map<String, dynamic>)
          : <String, dynamic>{};

      if (acceptRes.status != 200) {
        throw Exception(
          acceptData['error'] ?? 'Accept failed (status ${acceptRes.status})',
        );
      }

      // Success!
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      // Refresh global context
      await TeamContextController.instance.refresh();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Welcome to the team!')));
        // Delay slightly for UX
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/app/overview');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Team')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      const Text('Verifying invitation...'),
                    ] else if (_isSuccess) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Success!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Redirecting to your workspace...'),
                    ] else if (_infoMessage != null) ...[
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Colors.blue,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _infoMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to Login'),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _errorMessage ?? 'Unknown error occurred',
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: _validateAndJoin,
                            child: const Text('Retry'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go('/'),
                            child: const Text('Go Home'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  bool equalsIgnoreCase(String other) {
    return toLowerCase() == other.toLowerCase();
  }
}
