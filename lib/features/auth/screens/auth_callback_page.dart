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

  // ---------------------------------------------------------------------------
  // _parseNextDestination
  //
  // THE BUG THAT WAS HERE:
  //   uri.queryParameters['next']
  //
  // In Dart, Uri.queryParameters builds a Map<String, String> from all query
  // params. For DUPLICATE keys (e.g. `?next=A&next=B`), Dart keeps the LAST
  // value. The old team-invite buildRedirectTo appended `&next=/app/overview`
  // to the innermost finalDest URL, which — after the double encode/decode
  // cycle — surfaced as a literal second `&next=` in the URL that reached
  // this page. Dart's `queryParameters['next']` therefore returned
  // `/app/overview` (the last value), silently discarding the join-team token.
  //
  // THE FIX:
  //   uri.queryParametersAll['next']?.first
  //
  // `queryParametersAll` returns a Map<String, List<String>> where ALL values
  // for each key are preserved in order. `.first` gives us the FIRST `next`
  // value — which is always the one we actually constructed in buildRedirectTo
  // — regardless of any spurious duplicates that may follow.
  //
  // ENCODING NOTE:
  //   The new buildRedirectTo uses single-level encoding:
  //     redirectTo = /auth/callback?next=%2Fset-password%3Fnext%3D%2Fjoin-team%3Ftoken%3DTOKEN
  //   uri.queryParameters (and queryParametersAll) auto-decode once, giving:
  //     next = /set-password?next=/join-team?token=TOKEN
  //   No second Uri.decodeComponent is needed for new invite links.
  //
  //   We keep the fallback Uri.decodeComponent call for backwards compatibility
  //   with old invite emails still in recipients' inboxes (the old double-
  //   encoded links will still have `%25` in them after the first auto-decode
  //   and need a second pass). It is a safe no-op on already-decoded strings.
  // ---------------------------------------------------------------------------
  String? _parseNextDestination(Uri uri) {
    // Always take the FIRST `next` value — immune to duplicate-key poisoning.
    final rawNext =
        uri.queryParametersAll['next']?.firstOrNull ?? uri.queryParameters['next'];

    if (rawNext == null || rawNext.trim().isEmpty) return null;

    var next = rawNext;

    // Decode pass: handles backwards-compatible double-encoded old invite links.
    // For new single-encoded links this is a no-op.
    try {
      next = Uri.decodeComponent(next);
      // Second pass needed only if the string still starts with an encoded slash.
      if (next.startsWith('%2F') || next.startsWith('%2f')) {
        next = Uri.decodeComponent(next);
      }
    } catch (e) {
      debugPrint('AuthCallbackPage: Error decoding next param: $e');
    }

    // Normalise hash-router prefixes that some Supabase redirects produce.
    if (next.startsWith('/#/')) {
      next = next.substring(2);
    } else if (next.startsWith('#/')) {
      next = next.substring(1);
    }

    // Ensure it is a relative path.
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

    // Redact fragment from logs (contains access_token).
    final uriForLogs = uri.replace(fragment: '');
    debugPrint('AuthCallbackPage: Processing callback. URI: $uriForLogs');

    final nextDest = _parseNextDestination(uri) ?? '/app/overview';
    debugPrint('AuthCallbackPage: Target destination (next): $nextDest');

    // Fast-path: session already established (e.g. navigated back).
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
      // For invite/recovery flows the Supabase token may already be consumed
      // on a previous attempt. If there are no raw Supabase params but we have
      // an invite-style next destination, navigate anyway — the session likely
      // came through the auth state stream.
      if (_isInviteOnboardingNext(nextDest) && !_hasSupabaseCallbackParams(uri)) {
        debugPrint(
            'AuthCallbackPage: No Supabase code/hash but invite next present. Routing anyway.');
        _navigateToNext(nextDest);
        return;
      }
    }

    final session = await _waitForSession(timeout: const Duration(seconds: 8));
    _authSubscription?.cancel();

    if (!mounted) return;

    if (session != null) {
      debugPrint(
          'AuthCallbackPage: Session established. User: ${session.user.email}');
      _navigateToNext(nextDest);
    } else if (_isInviteOnboardingNext(nextDest)) {
      debugPrint('AuthCallbackPage: Timeout but invite next present. Routing anyway.');
      _navigateToNext(nextDest);
    } else {
      debugPrint('AuthCallbackPage: Failed to establish session after timeout.');
      _navigateToLogin(nextDest);
    }
  }

  Future<Session?> _waitForSession(
      {Duration timeout = const Duration(seconds: 8)}) async {
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
