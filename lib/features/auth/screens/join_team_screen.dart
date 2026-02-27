import 'dart:async';
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
  bool _waitingForSession = false;

  @override
  void initState() {
    super.initState();
    _validateAndJoin();
  }

  Future<Session?> _waitForSession({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final existing = _supabase.auth.currentSession;
    if (existing != null) return existing;

    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> sub;

    sub = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && !completer.isCompleted) {
        completer.complete(data.session);
      }
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final session = await completer.future;
    await sub.cancel();
    return session;
  }

  Future<void> _validateAndJoin() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or missing invite token.';
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
      // 1. PREPARE: Check if the invite is valid and get the target email
      final prep = await _supabase.functions.invoke(
        'team-accept-invite',
        body: {'token': token, 'action': 'prepare'},
      );

      if (prep.status != 200) {
        throw Exception(prep.data['error'] ?? 'Invite lookup failed');
      }

      final inviteEmail = (prep.data['email'] ?? '').toString().trim();

      // 2. WAIT FOR SESSION: Ensure we are actually logged in
      setState(() => _waitingForSession = true);
      final session = await _waitForSession();
      setState(() => _waitingForSession = false);

      if (session == null || _supabase.auth.currentUser == null) {
        setState(() {
          _isLoading = false;
          _infoMessage = 'Please check your email ($inviteEmail) to set your password and log in.';
        });
        return;
      }

      // 3. EMAIL MATCH VALIDATION
      final currentEmail = _supabase.auth.currentUser!.email ?? '';
      if (currentEmail.toLowerCase() != inviteEmail.toLowerCase()) {
        await _supabase.auth.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage = 'This invite is for $inviteEmail, but you are logged in as $currentEmail. You have been signed out.';
        });
        return;
      }

      // 4. THE JWT REFRESH: This prevents the 401 loop
      // Refreshing right before the call ensures the token is fresh and has the latest user metadata
      final refreshRes = await _supabase.auth.refreshSession();
      final freshToken = refreshRes.session?.accessToken;

      if (freshToken == null) throw Exception('Failed to obtain a fresh security token.');

      // 5. ACCEPT: Finalize the join
      final acceptRes = await _supabase.functions.invoke(
        'team-accept-invite',
        headers: {'Authorization': 'Bearer $freshToken'},
        body: {'token': token, 'action': 'accept'},
      );

      if (acceptRes.status != 200) {
        throw Exception(acceptRes.data['error'] ?? 'Failed to accept invitation');
      }

      // 6. SUCCESS & CONTEXT REFRESH
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      // Force the global team state to update immediately
      await TeamContextController.instance.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to the team!')),
        );
        context.go('/app/overview');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _waitingForSession = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Joining Team')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_waitingForSession || _isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(_waitingForSession ? 'Syncing session...' : 'Verifying invite...'),
              ] else if (_isSuccess) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 24),
                const Text('Joined successfully!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ] else if (_infoMessage != null) ...[
                const Icon(Icons.mail_outline, color: Colors.blue, size: 64),
                const SizedBox(height: 16),
                Text(_infoMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Go to Login')),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'An error occurred', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _validateAndJoin, child: const Text('Try Again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}