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
    // Use addPostFrameCallback to ensure context is available for navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthCallback();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Normalizes the `next` parameter, handling nested encodings and hash/path confusion.
  String? _parseNextDestination(Uri uri) {
    // 1. Get raw 'next' param
    var next = uri.queryParameters['next'];
    if (next == null || next.isEmpty) return null;

    // 2. Decode repeatedly if it looks double-encoded (common in deep link chains)
    // e.g. %2Fset-password%3Fnext%3D...
    try {
      next = Uri.decodeComponent(next);
      // If it still looks encoded (starts with %2F), decode again?
      // Usually one decode is enough if buildRedirectTo used encodeURIComponent once.
      // But let's be safe against double encoding.
      if (next.startsWith('%2F')) {
        next = Uri.decodeComponent(next);
      }
    } catch (e) {
      debugPrint('AuthCallbackPage: Error decoding next param: $e');
    }

    // 3. Handle Hash Routing artifacts (e.g. /#/set-password -> /set-password)
    if (next!.startsWith('/#/')) {
      next = next.substring(2);
    } else if (next.startsWith('#/')) {
      next = next.substring(1);
    }

    // 4. Ensure it starts with / if it's a path
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

    // In Flutter Web, Uri.base gives the full URL including query params and hash.
    // Supabase Auth redirects to: /auth/callback#access_token=... (implicit) or ?code=... (PKCE)
    // We need to parse this.
    final uri = Uri.base;

    debugPrint('AuthCallbackPage: Processing callback. Full URI: $uri');
    debugPrint('AuthCallbackPage: URI.query: ${uri.query}');
    debugPrint('AuthCallbackPage: URI.fragment: ${uri.fragment}');
    debugPrint(
      'AuthCallbackPage: Supabase callback params present: ${_hasSupabaseCallbackParams(uri)}',
    );

    // 1. Parse 'next' destination immediately
    final nextDest = _parseNextDestination(uri);
    debugPrint('AuthCallbackPage: Target destination (next): $nextDest');

    // 2. Check if we already have a valid session (maybe from local storage or previous tab)
    if (client.auth.currentSession != null) {
      debugPrint(
        'AuthCallbackPage: Valid session already exists. Routing immediately.',
      );
      _navigateToNext(nextDest);
      return;
    }

    // 3. Attempt to exchange code/hash for session
    // This is the critical step for PKCE or Implicit flow.
    // We try/catch because sometimes the code is invalid or already used.
    debugPrint(
      'AuthCallbackPage: Attempting to exchange code/hash for session...',
    );
    try {
      // This method handles parsing the URL for code/token and setting the session.
      // It might throw if the link is invalid.
      await client.auth.getSessionFromUrl(uri);
      debugPrint('AuthCallbackPage: getSessionFromUrl completed successfully.');
    } catch (e) {
      debugPrint('AuthCallbackPage: getSessionFromUrl warning: $e');

      // Invite onboarding resilience:
      // If the callback was hit WITHOUT a Supabase code/hash (common when email templates
      // incorrectly link directly to /auth/callback instead of /auth/v1/verify),
      // do not bounce the user to /login immediately.
      // Let the next screen (Set Password / Join Team) show a clean recovery state.
      if (_isInviteOnboardingNext(nextDest) &&
          !_hasSupabaseCallbackParams(uri)) {
        debugPrint(
          'AuthCallbackPage: No Supabase code/hash detected, but invite onboarding next is present. '
          'Routing to next anyway to avoid redirect loop.',
        );
        _navigateToNext(nextDest);
        return;
      }
      // We don't return here; we fall through to the listener check.
      // Sometimes the session is established by the auto-refresh mechanism or local storage
      // concurrently, causing getSessionFromUrl to fail on "code already used".
    }

    // 4. Wait for Session (Robustness)
    // Even if getSessionFromUrl threw, the session might be arriving via the stream.
    // We wait up to 5 seconds for a session to appear.
    final sessionCompleter = Completer<Session?>();

    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && !sessionCompleter.isCompleted) {
        sessionCompleter.complete(data.session);
      }
    });

    // Check immediate state again just in case
    if (client.auth.currentSession != null && !sessionCompleter.isCompleted) {
      sessionCompleter.complete(client.auth.currentSession);
    }

    // Timer to prevent hanging forever
    Timer(const Duration(seconds: 5), () {
      if (!sessionCompleter.isCompleted) {
        sessionCompleter.complete(null);
      }
    });

    final session = await sessionCompleter.future;
    _authSubscription?.cancel();

    if (!mounted) return;

    if (session != null) {
      debugPrint(
        'AuthCallbackPage: Session established successfully. User: ${session.user.email}',
      );
      _navigateToNext(nextDest);
    } else {
      debugPrint(
        'AuthCallbackPage: Failed to establish session after timeout.',
      );

      // Invite onboarding resilience:
      // If we have an invite onboarding destination but no session, route there anyway.
      // The Set Password screen will show the "no session" recovery UI.
      if (_isInviteOnboardingNext(nextDest)) {
        debugPrint(
          'AuthCallbackPage: Timeout with no session, but invite onboarding next is present. '
          'Routing to next anyway to avoid /login redirect loop.',
        );
        _navigateToNext(nextDest);
        return;
      }

      // Fallback: Redirect to Login, but preserve 'next' so they can login manually and continue
      _navigateToLogin(nextDest);
    }
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