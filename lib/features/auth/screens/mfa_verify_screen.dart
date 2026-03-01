import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// MfaVerifyScreen
//
// Shown immediately after a successful signInWithPassword() when the user has
// an enrolled TOTP factor (nextLevel == aal2 but currentLevel == aal1).
//
// FLOW:
//   LoginScreen.signInWithPassword()
//     → AAL check: nextLevel == aal2 && currentLevel != aal2
//     → context.go('/mfa-verify?next=/app/overview')
//     → MfaVerifyScreen: challenge() → verify()
//     → context.go(next)            (session is now aal2)
//
// ROUTE:  /mfa-verify?next=<destination>
//   next  Required. Where to navigate on successful verification.
//         Sanitised before use (must start with '/').
//
// This screen is intentionally minimal — it is shown inline during the login
// flow, not as a settings dialog, so it needs to feel like a login step.
// =============================================================================

class MfaVerifyScreen extends StatefulWidget {
  final String? next;

  const MfaVerifyScreen({super.key, this.next});

  @override
  State<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<MfaVerifyScreen> {
  final _supabase = Supabase.instance.client;
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _sanitizeNext(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('/')) return null;
    // Prevent redirect back to auth screens
    if (trimmed.startsWith('/login') ||
        trimmed.startsWith('/signup') ||
        trimmed.startsWith('/mfa-verify')) {
      return null;
    }
    return trimmed;
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code from your app.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Step 1 — find the verified TOTP factor for this user.
      // listFactors() is fast and rarely hits the network.
      final factors = await _supabase.auth.mfa.listFactors();
      final totpFactor = factors.totp.firstWhere(
        (f) => f.status == FactorStatus.verified,
        orElse: () => throw const AuthException(
          'No verified MFA factor found on this account.',
        ),
      );

      // Step 2 — create a fresh challenge for this factor.
      // A new challenge must be created for every verification attempt;
      // challenges expire after ~10 minutes if unused.
      final challenge = await _supabase.auth.mfa.challenge(
        factorId: totpFactor.id,
      );

      // Step 3 — verify the 6-digit code against the challenge.
      // On success: session AAL is upgraded to aal2 automatically by the SDK.
      // On failure: throws AuthException; we display the error and let the
      //             user try again with the next code (codes refresh every 30s).
      await _supabase.auth.mfa.verify(
        factorId: totpFactor.id,
        challengeId: challenge.id,
        code: code,
      );

      if (!mounted) return;

      // Navigate to the intended destination now that aal2 is confirmed.
      final dest = _sanitizeNext(widget.next) ?? '/app/overview';
      context.go(dest);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = e.message.toLowerCase().contains('invalid')
            ? 'Incorrect code — check your app and try again.'
            : e.message;
      });
      // Re-focus the code field so the user can immediately type the next code.
      _codeCtrl.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        // Prevent back navigation — the user has already authenticated with
        // password; going back would leave them in a partial-auth limbo.
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Icon(
                  Icons.security,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Heading
                Text(
                  'Verify your identity',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code from your authenticator app '
                  'to complete sign-in.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Code input
                TextField(
                  controller: _codeCtrl,
                  focusNode: _focusNode,
                  autofocus: true,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontFamily: 'monospace',
                    letterSpacing: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      letterSpacing: 10,
                    ),
                    border: const OutlineInputBorder(),
                    // Green border once 6 digits entered — visual confirmation
                    // before the user presses Verify.
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _codeCtrl.text.length == 6
                            ? Colors.green
                            : theme.colorScheme.outline,
                        width: _codeCtrl.text.length == 6 ? 2 : 1,
                      ),
                    ),
                    errorText: _errorText,
                  ),
                  onChanged: (_) {
                    setState(() => _errorText = null);
                    // Auto-submit when 6 digits are entered — removes the need
                    // to tap Verify for the common happy path.
                    if (_codeCtrl.text.length == 6 && !_isLoading) {
                      _verify();
                    }
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) _verify();
                  },
                ),

                const SizedBox(height: 8),
                Text(
                  'Codes refresh every 30 seconds.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Verify button
                FilledButton(
                  onPressed: _isLoading ? null : _verify,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify'),
                ),

                const SizedBox(height: 16),

                // Sign out fallback — in case the user has lost access to
                // their authenticator app, they can start over.
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          await _supabase.auth.signOut(
                            scope: SignOutScope.local,
                          );
                          if (!mounted) return;
                          if (mounted && context.mounted) context.go('/login');
                        },
                  child: const Text('Sign out and use a different account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
