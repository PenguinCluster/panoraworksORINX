import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  bool _handling = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthCallback();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String? _parseNextDestination(Uri uri) {
    var next = uri.queryParameters['next'];
    if (next == null || next.isEmpty) return null;
    try {
      next = Uri.decodeComponent(next);
      if (next.startsWith('%2F')) {
        next = Uri.decodeComponent(next);
      }
    } catch (e) {
      debugPrint('AuthCallbackPage: Error decoding next param: $e');
    }
    if (next!.startsWith('/#/')) {
      next = next.substring(2);
    } else if (next.startsWith('#/')) {
      next = next.substring(1);
    }
    if (!next.startsWith('http') && !next.startsWith('/')) {
      next = '/$next';
    }
    return next.trim();
  }

  bool _isInviteOnboardingNext(String? next) {
    if (next == null || next.isEmpty) return false;
    return next.contains('/set-password') || next.contains('/join-team');
  }

  bool _hasSupabaseCallbackParams(Uri uri) {
    final query = uri.queryParameters;
    final frag = uri.fragment;
    return query.containsKey('code') ||
        query.containsKey('access_token') ||
        frag.contains('access_token=') ||
        frag.contains('refresh_token=') ||
        frag.contains('type=invite') ||
        frag.contains('type=recovery');
  }

  Future<void> _handleAuthCallback() async {
    if (_handling) return;
    _handling = true;

    final client = Supabase.instance.client;
    final uri = Uri.base;

    final uriForLogs = uri.replace(fragment: '');
    debugPrint('AuthCallbackPage: Processing callback. URI: $uriForLogs');

    final nextDest = _parseNextDestination(uri) ?? '/app/overview';
    debugPrint('AuthCallbackPage: Target destination (next): $nextDest');

    if (client.auth.currentSession != null) {
      debugPrint('AuthCallbackPage: Valid session already exists. Routing immediately.');
      _navigateToNext(nextDest);
      return;
    }

    debugPrint('AuthCallbackPage: Attempting to exchange code/hash for session...');
    try {
      await client.auth.getSessionFromUrl(uri);
      debugPrint('AuthCallbackPage: getSessionFromUrl completed successfully.');
    } catch (e) {
      debugPrint('AuthCallbackPage: getSessionFromUrl warning: $e');
      if (_isInviteOnboardingNext(nextDest) && !_hasSupabaseCallbackParams(uri)) {
        debugPrint('AuthCallbackPage: No Supabase code/hash but invite next present. Routing anyway.');
        _navigateToNext(nextDest);
        return;
      }
    }

    final session = await _waitForSession(timeout: const Duration(seconds: 8));
    _authSubscription?.cancel();

    if (!mounted) return;

    if (session != null) {
      debugPrint('AuthCallbackPage: Session established successfully. User: ${session.user.email}');
      _navigateToNext(nextDest);
    } else if (_isInviteOnboardingNext(nextDest)) {
      debugPrint('AuthCallbackPage: Timeout with invite next. Routing anyway.');
      _navigateToNext(nextDest);
    } else {
      debugPrint('AuthCallbackPage: Failed to establish session after timeout.');
      _navigateToLogin(nextDest);
    }
  }

  // Added helper for robust waiting (fixes Bugs 1 & 2)
  Future<Session?> _waitForSession({Duration timeout = const Duration(seconds: 8)}) async {
    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> sub;
    sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
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

  void _navigateToNext(String? next) {
    if (next != null && next.isNotEmpty) {
      debugPrint('AuthCallbackPage: Routing to next: $next');
      context.go(next);
    } else {
      debugPrint('AuthCallbackPage: No next param, routing to /app/overview');
      context.go('/app/overview');
    }
  }

  void _navigateToLogin(String? next) {
    if (next != null && next.isNotEmpty) {
      final loginUrl = '/login?next=${Uri.encodeComponent(next)}';
      debugPrint('AuthCallbackPage: Routing to login with next: $loginUrl');
      context.go(loginUrl);
    } else {
      debugPrint('AuthCallbackPage: Routing to /login');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying login...'),
          ],
        ),
      ),
    );
  }
}