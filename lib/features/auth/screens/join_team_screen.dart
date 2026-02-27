import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/team_context_controller.dart';

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

  // ---------------------------------------------------------------------------
  // _sanitizeToken
  //
  // THE BUG:
  //   The Flutter router can hand us a contaminated token like:
  //     "af2cb30a-6801-41c0-8c03-34d563f56a12?next=/app/overview"
  //
  //   This happens with old invite emails (sent before the buildRedirectTo fix)
  //   where `?next=/app/overview` was appended to the join-team URL without
  //   encoding, causing GoRouter to include it in the `token` query param value.
  //   When this raw string is sent to the edge function, Postgres throws
  //   error 22P02 (invalid_text_representation) because it is not a valid UUID.
  //
  // THE FIX:
  //   Split on `?` and `&` and take the first segment. This is safe because
  //   a UUID never contains `?` or `&`. The edge function also does this as a
  //   second line of defence, but we sanitize here first so error messages
  //   in the UI are clear and the network call never carries garbage data.
  // ---------------------------------------------------------------------------
  String _sanitizeToken(String raw) {
    final clean = raw.split('?').first.split('&').first.trim();
    if (clean != raw) {
      debugPrint(
        'JoinTeamScreen: token sanitized from "$raw" to "$clean"',
      );
    }
    return clean;
  }

  // ---------------------------------------------------------------------------
  // _waitForValidSession
  //
  // THE BUG:
  //   The old code called the PREPARE edge function BEFORE waiting for a
  //   session. JoinTeamScreen is navigated to immediately after
  //   SetPasswordScreen calls context.go('/join-team?token=...'), but the
  //   Supabase Flutter client fires auth state events asynchronously. In the
  //   window between navigation and the userUpdated/tokenRefreshed event, the
  //   client still holds the pre-password session (or no session at all).
  //
  //   Additionally, refreshSession() after updateUser() returns quickly but
  //   the new session JWT is sometimes not yet accepted by Supabase Auth if
  //   called within milliseconds of the password change. Using that JWT for
  //   functions.invoke() produced a 401.
  //
  // THE FIX (three parts):
  //   1. Wait for a confirmed, live session FIRST — before any network calls.
  //   2. Listen specifically for AuthChangeEvent.userUpdated and
  //      AuthChangeEvent.tokenRefreshed, which guarantee the new session is
  //      fully committed. Also accept signedIn as a fallback.
  //   3. After receiving the event, extract accessToken directly from
  //      data.session (the event payload) rather than calling refreshSession()
  //      again. The event session IS the fresh, valid session.
  // ---------------------------------------------------------------------------
  Future<Session?> _waitForValidSession({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // Fast-path: if a live session is already present and fresh enough,
    // return it immediately. "Fresh enough" = not expiring in the next 30s.
    final existing = _supabase.auth.currentSession;
    if (existing != null) {
      final expiresAt = existing.expiresAt; // seconds since epoch
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt == null || expiresAt - nowSec > 30) {
        return existing;
      }
    }

    debugPrint('JoinTeamScreen: waiting for valid session…');

    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> sub;

    sub = _supabase.auth.onAuthStateChange.listen((data) {
      if (completer.isCompleted) return;

      final session = data.session;
      if (session == null) return;

      final relevantEvent =
          data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.userUpdated ||
          data.event == AuthChangeEvent.tokenRefreshed;

      if (relevantEvent) {
        debugPrint(
          'JoinTeamScreen: session confirmed via ${data.event}',
        );
        completer.complete(session);
      }
    });

    // Timeout guard
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('JoinTeamScreen: session wait timed out');
        completer.complete(null);
      }
    });

    final session = await completer.future;
    await sub.cancel();
    return session;
  }

  Future<void> _validateAndJoin() async {
    // ── 0. Validate raw token input ─────────────────────────────────────────
    final rawToken = widget.token;
    if (rawToken == null || rawToken.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid or missing invite token. '
            'Please reopen the invite link from your email.';
      });
      return;
    }

    // Sanitize immediately — strips `?next=...` and `&...` suffixes that
    // old invite emails can inject into the token value via the router.
    final token = _sanitizeToken(rawToken.trim());

    // Basic UUID format check — catches gross corruption before any network call.
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidPattern.hasMatch(token)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'The invite link appears to be malformed. '
            'Please reopen the invite link from your email.';
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
      // ── 1. Wait for a valid session FIRST ──────────────────────────────────
      //
      // ORDERING CHANGE: The old code called PREPARE before waiting for a
      // session. We now wait first. This guarantees:
      //   a) The PREPARE call has a valid JWT in the Authorization header.
      //   b) The ACCEPT call uses the same confirmed session — no stale token.
      //
      setState(() => _waitingForSession = true);
      final session = await _waitForValidSession();
      setState(() => _waitingForSession = false);

      if (session == null || _supabase.auth.currentUser == null) {
        setState(() {
          _isLoading = false;
          _infoMessage =
              'Your session could not be confirmed. Please check your email '
              'for the invite link and set your password to continue.';
        });
        return;
      }

      // Extract the access token from the confirmed session event.
      // DO NOT call refreshSession() here — it is redundant and can
      // briefly return an old token if called too quickly after updateUser().
      final accessToken = session.accessToken;

      // ── 2. PREPARE — look up the invite details ────────────────────────────
      //
      // Now that verify_jwt is false on the edge function, this call goes
      // through regardless of the JWT state. We still pass the auth header
      // so the edge function logs have full context.
      final prepRes = await _supabase.functions.invoke(
        'team-accept-invite',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'token': token, 'action': 'prepare'},
      );

      if (prepRes.status != 200) {
        final errMsg = prepRes.data?['error'] ?? 'Invite lookup failed.';
        throw Exception(errMsg);
      }

      final inviteEmail =
          (prepRes.data['email'] ?? '').toString().trim().toLowerCase();

      // ── 3. Email match validation ──────────────────────────────────────────
      final currentEmail =
          (_supabase.auth.currentUser!.email ?? '').toLowerCase();

      if (currentEmail != inviteEmail) {
        await _supabase.auth.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage =
              'This invite is for $inviteEmail, but you are logged in as '
              '$currentEmail. You have been signed out. Please reopen the '
              'invite link from your email.';
        });
        return;
      }

      // ── 4. ACCEPT — write the membership record ───────────────────────────
      //
      // Pass the exact same accessToken we confirmed in step 1.
      // verify_jwt is now false, so there is no infrastructure-layer 401 risk.
      // The edge function's auth.getUser(token) call is the single source of
      // truth for session validation.
      final acceptRes = await _supabase.functions.invoke(
        'team-accept-invite',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {'token': token, 'action': 'accept'},
      );

      if (acceptRes.status != 200) {
        final errMsg =
            acceptRes.data?['error'] ?? 'Failed to accept invitation.';
        throw Exception(errMsg);
      }

      // ── 5. Refresh team context and navigate ─────────────────────────────
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      await TeamContextController.instance.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to the team!')),
        );
        context.go('/app/overview');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('JoinTeamScreen error: $msg');
      setState(() {
        _isLoading = false;
        _waitingForSession = false;
        _errorMessage = msg;
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_waitingForSession) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Syncing session…',
                    style: TextStyle(color: Colors.grey),
                  ),
                ] else if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text(
                    'Verifying invite…',
                    style: TextStyle(color: Colors.grey),
                  ),
                ] else if (_isSuccess) ...[
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Joined successfully!',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ] else if (_infoMessage != null) ...[
                  const Icon(Icons.mail_outline,
                      color: Colors.blue, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _infoMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Go to Login'),
                  ),
                ] else ...[
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'An unexpected error occurred.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _validateAndJoin,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
