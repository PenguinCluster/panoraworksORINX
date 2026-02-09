import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_handler.dart';

class JoinTeamScreen extends StatefulWidget {
  final String? token;

  const JoinTeamScreen({super.key, this.token});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _validateAndJoin();
  }

  Future<void> _validateAndJoin() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'Invalid invite link.');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      // If not logged in, redirect to login/signup with return URL
      // But for better UX, we show a message here first
      setState(() => _errorMessage = 'Please log in to accept the invite.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _supabase.rpc(
        'accept_team_invite',
        params: {'invite_token': token},
      );

      if (res['error'] != null) {
        setState(() => _errorMessage = res['error']);
      } else if (res['success'] == true) {
        setState(() => _isSuccess = true);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Welcome to the team!')));
          // Wait a moment then redirect
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/app/overview');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to join team: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Team')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Verifying invite...'),
                  ] else if (_isSuccess) ...[
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Redirecting to your dashboard...'),
                  ] else ...[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage?.contains('Please log in') == true)
                      FilledButton(
                        onPressed: () =>
                            context.go('/login'), // Ideally pass return URL
                        child: const Text('Log In'),
                      )
                    else
                      FilledButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Go Home'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
