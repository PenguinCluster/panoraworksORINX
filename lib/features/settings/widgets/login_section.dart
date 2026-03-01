// DEPENDENCIES REQUIRED (add to pubspec.yaml if not already present):
//   flutter_svg: ^2.0.0     ← renders the SVG QR code Supabase returns
//   intl: ^0.19.0           ← date formatting (Phase 1)
//   file_saver: ^0.5.1      ← cross-platform file save (web download + mobile)
//
// ANDROID: add to android/app/src/main/AndroidManifest.xml inside <manifest>:
//   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
//                    android:maxSdkVersion="28"/>
// (Only needed on Android ≤ 9. Android 10+ writes to Downloads without it.)

import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/state/team_context_controller.dart';

class LoginSection extends StatefulWidget {
  const LoginSection({super.key});

  @override
  State<LoginSection> createState() => _LoginSectionState();
}

class _LoginSectionState extends State<LoginSection> {
  final _supabase = Supabase.instance.client;

  bool _isSigningOut       = false;
  bool _isUpdatingPassword = false;
  bool _isDeletingAccount  = false;
  bool _isExporting        = false;

  // ── MFA state (Phase 4) ───────────────────────────────────────────────────
  //
  // We track the user's enrolled TOTP factor so the MFA row shows
  // "Enable" vs "Disable" and the correct action on tap.
  //
  // _mfaLoading is true only during the initial listFactors() call on initState
  // and during unenroll. The enrollment dialog manages its own internal loading
  // state via StatefulBuilder so the main screen does not grey out while the
  // user is scanning the QR code.
  bool              _mfaLoading = true;
  dynamic        _enrolledFactor; // non-null = MFA is active for this user

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  // ─── Phase 1 helpers ──────────────────────────────────────────────────────

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return '—';
    }
  }

  // ─── Phase 1: sign out other devices ──────────────────────────────────────

  Future<void> _signOutOtherDevices() async {
    setState(() => _isSigningOut = true);
    try {
      await _supabase.auth.signOut(scope: SignOutScope.others);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out from all other devices.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  // ─── Phase 2: update password ──────────────────────────────────────────────

  void _showUpdatePasswordDialog() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl     = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey             = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool obscureCurrent = true;
        bool obscureNew     = true;
        bool obscureConfirm = true;
        bool isLoading      = false;

        return StatefulBuilder(builder: (context, setDS) {
          return AlertDialog(
            title: const Text('Update Password'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDS(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your current password'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDS(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a new password';
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        if (v == currentPasswordCtrl.text) {
                          return 'New password must differ from current';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setDS(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != newPasswordCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDS(() => isLoading = true);
                        final ok = await _updatePassword(
                          currentPassword: currentPasswordCtrl.text,
                          newPassword: newPasswordCtrl.text,
                        );
                        if (!dialogContext.mounted) return;
                        setDS(() => isLoading = false);
                        if (ok) Navigator.pop(dialogContext);
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        });
      },
    ).whenComplete(() {
      currentPasswordCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    });
  }

  Future<bool> _updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    setState(() => _isUpdatingPassword = true);
    try {
      final email = _supabase.auth.currentUser?.email;
      if (email == null) throw const AuthException('No authenticated user.');

      // ── Bug 3 fix: AAL check before any sensitive operation ──────────────
      //
      // Supabase requires an aal2 session to change passwords when MFA is
      // enrolled. We check BEFORE re-auth so we know which path to take:
      //
      //   Path A — MFA enrolled, session is aal1:
      //     Show TOTP step-up dialog. signInWithPassword is intentionally
      //     SKIPPED here because it would reset an aal2 session back to aal1,
      //     causing the same insufficient_aal error immediately after.
      //     The TOTP step-up IS the re-authentication for MFA users.
      //
      //   Path B — No MFA (currentLevel == nextLevel == aal1):
      //     Classic re-auth via signInWithPassword, then updateUser.
      //
      //   Path C — Already aal2 (MFA verified this session):
      //     Skip both re-auth and step-up; go straight to updateUser.
      final aalData = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      final currentLevel = aalData.currentLevel;
      final nextLevel    = aalData.nextLevel;

      if (nextLevel?.name == 'aal2' &&
          currentLevel?.name != 'aal2') {
        // Path A — MFA enrolled but not yet verified this session.
        // Show step-up dialog; do NOT call signInWithPassword.
        setState(() => _isUpdatingPassword = false); // release lock during dialog
        final steppedUp = await _showMfaStepUpDialog();
        // Bug 1 fix: widget may have been disposed while the step-up dialog
        // was open (e.g. user navigated away via back gesture). Check mounted
        // before every setState / context access that follows an await.
        if (!mounted) return false;
        if (!steppedUp) return false; // user cancelled
        setState(() => _isUpdatingPassword = true);
        // Session is now aal2 — fall through to updateUser below.
      } else if (currentLevel?.name != 'aal2') {
        // Path B — No MFA enrolled; use classic current-password re-auth.
        await _supabase.auth
            .signInWithPassword(email: email, password: currentPassword);
      }
      // Path C — Already aal2: no re-auth needed, fall through.

      // ── Bug 1 fix: write password_last_changed into user metadata ────────
      //
      // user.updatedAt changes on ANY profile update (name, email, etc.),
      // not just password changes. Storing a dedicated key in user_metadata
      // gives us a precise "password last changed" timestamp.
      //
      // We bundle both into a single updateUser call to avoid a race between
      // the password write and the metadata write — one atomic operation.
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
          data: {'password_last_changed': now},
        ),
      );

      if (mounted) {
        setState(() {}); // re-reads userMetadata['password_last_changed'] in build
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } on AuthException catch (e) {
      if (mounted) {
        final msg = e.message.toLowerCase();
        final message = msg.contains('invalid login credentials')
            ? 'Current password is incorrect.'
            : msg.contains('insufficient_aal')
                ? 'A verified MFA session is required. Please re-authenticate.'
                : e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  // ── Bug 3: TOTP step-up dialog ────────────────────────────────────────────
  //
  // Shows a minimal challenge+verify dialog to lift the session from aal1 →
  // aal2. This is reused by _updatePassword; it is NOT the enrollment flow
  // (no enroll() call, no QR code — the factor already exists).
  //
  // Returns true if the session was successfully stepped up to aal2.
  // Returns false if the user cancelled or the code was wrong after retries.
  Future<bool> _showMfaStepUpDialog() async {
    final codeCtrl = TextEditingController();
    bool result    = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool   isLoading    = false;
        String? errorText;

        return StatefulBuilder(builder: (context, setDS) {
          Future<void> verify() async {
            final code = codeCtrl.text.trim();
            if (code.length != 6) {
              setDS(() => errorText = 'Enter the 6-digit code.');
              return;
            }
            setDS(() { isLoading = true; errorText = null; });

            try {
              // listFactors is fast (rarely hits network) — gets us the factorId.
              final factors = await _supabase.auth.mfa.listFactors();
              final factor  = factors.totp.firstWhere(
                (f) => f.status == FactorStatus.verified,
                orElse: () => throw const AuthException('No verified MFA factor found.'),
              );

              // Create a fresh challenge then verify immediately.
              final challenge = await _supabase.auth.mfa
                  .challenge(factorId: factor.id);
              await _supabase.auth.mfa.verify(
                factorId:    factor.id,
                challengeId: challenge.id,
                code:        code,
              );

              result = true;
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } on AuthException catch (e) {
              if (dialogContext.mounted) {
                setDS(() {
                  isLoading = false;
                  errorText = e.message.toLowerCase().contains('invalid')
                      ? 'Incorrect code — check your app and try again.'
                      : e.message;
                });
              }
            }
          }

          return AlertDialog(
            title: const Text('Confirm your identity'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Changing your password requires MFA verification. '
                  'Enter the 6-digit code from your authenticator app.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  enabled: !isLoading,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontFamily: 'monospace',
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                  onSubmitted: (_) { if (!isLoading) verify(); },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading ? null : verify,
                child: isLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm'),
              ),
            ],
          );
        });
      },
    ).whenComplete(codeCtrl.dispose);

    return result;
  }

  // ─── Phase 3: delete account ───────────────────────────────────────────────

  void _showDeleteAccountDialog() {
    final confirmCtrl   = TextEditingController();
    const confirmWord   = 'DELETE';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading    = false;
        bool inputMatches = false;

        return StatefulBuilder(builder: (context, setDS) {
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Delete Account'),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      'This action is permanent and cannot be undone. '
                      'Your account, workspace, all team data, and billing '
                      'history will be deleted immediately.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: const [
                        TextSpan(text: 'Type '),
                        TextSpan(
                          text: confirmWord,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace'),
                        ),
                        TextSpan(text: ' to confirm:'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    enabled: !isLoading,
                    autofocus: true,
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: confirmWord,
                      border: const OutlineInputBorder(),
                      errorText:
                          confirmCtrl.text.isNotEmpty && !inputMatches
                              ? 'Type DELETE in capitals'
                              : null,
                    ),
                    onChanged: (v) =>
                        setDS(() => inputMatches = v == confirmWord),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: (inputMatches && !isLoading)
                    ? () async {
                        setDS(() => isLoading = true);
                        final ok = await _deleteAccount();
                        if (!dialogContext.mounted) return;
                        if (!ok) setDS(() => isLoading = false);
                      }
                    : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Delete my account'),
              ),
            ],
          );
        });
      },
    ).whenComplete(confirmCtrl.dispose);
  }

  Future<bool> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      final response =
          await _supabase.functions.invoke('delete-account');
      if (response.status != 200) {
        final error = response.data?['error'] as String?
            ?? 'Account deletion failed. Please try again.';
        throw Exception(error);
      }
      await _supabase.auth.signOut(scope: SignOutScope.local);
      TeamContextController.instance.clear();
      if (mounted) context.go('/login');
      return true;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  // ─── Phase 5: Data Export ─────────────────────────────────────────────────
  //
  // FLOW:
  //   1. Call export-user-data Edge Function → returns JSON bytes.
  //   2. Read the filename from Content-Disposition response header.
  //   3. Save the file via file_saver:
  //        • Web    → triggers a browser "Save As" / automatic download.
  //        • Mobile → writes to Downloads (Android) or Documents (iOS),
  //                   accessible from the device's Files app.
  //        • Desktop → writes to the system Downloads folder.
  //
  // WHY file_saver over path_provider + share_plus:
  //   file_saver handles all three platforms in one call without needing
  //   a share sheet. The user gets a file in a predictable location rather
  //   than being asked "share with…" — more appropriate for a data export.
  //
  // ERROR HANDLING:
  //   The Edge Function includes a _partial_errors key if any individual
  //   table query failed. We still save the file (partial data is better
  //   than none) but show a SnackBar warning so the user knows.

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      // ── Step 1: Invoke the Edge Function ──────────────────────────────
      // Bug 3 fix (Flutter side):
      //   - Guard against a null session before invoking. If accessToken is
      //     null we'd silently send "Bearer " with no token, which the gateway
      //     always rejects. Surfacing this early gives a clear error message.
      //   - Pass the Authorization header explicitly — the Supabase Flutter SDK
      //     does not guarantee forwarding it automatically across all versions.
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('No active session — please sign in again.');
      }
      final response = await _supabase.functions.invoke(
        'export-user-data',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status != 200) {
        final errMsg = (response.data is Map)
            ? (response.data['error'] as String? ?? 'Export failed.')
            : 'Export failed (status ${response.status}).';
        throw Exception(errMsg);
      }

      // ── Step 2: Encode to bytes ────────────────────────────────────────
      // response.data is already parsed JSON (a Map). Re-encode it to a
      // pretty-printed UTF-8 byte array for the file.
      final jsonString = const JsonEncoder.withIndent('  ')
          .convert(response.data);
      final bytes = utf8.encode(jsonString);

      // ── Step 3: Build filename from today's date ───────────────────────
      final dateSlug = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename  = 'orinx-data-export-$dateSlug';

      // ── Step 4: Save the file ──────────────────────────────────────────
      // file_saver API:
      //   name      → filename without extension
      //   bytes     → Uint8List content
      //   ext       → extension without leading dot
      //   mimeType  → MimeType enum value
      //
      // On web this immediately triggers a browser download.
      // On mobile/desktop it writes to the platform Downloads folder.
      await FileSaver.instance.saveFile(
        name:     filename,
        bytes:    bytes,
        fileExtension:      'json',
        mimeType: MimeType.json,
      );

      if (!mounted) return;

      // Surface a warning if the export is partial (some tables failed).
      final hasPartialErrors = (response.data is Map) &&
          (response.data as Map).containsKey('_partial_errors');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasPartialErrors
                ? 'Data exported with warnings — some sections may be incomplete. '
                  'Check the _partial_errors key in the file for details.'
                : kIsWeb
                    ? 'Download started: $filename.json'
                    : 'Saved to your Downloads folder: $filename.json',
          ),
          backgroundColor: hasPartialErrors ? Colors.orange : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $message'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Phase 4: MFA ─────────────────────────────────────────────────────────
  //
  // ENROLLMENT FLOW (three mandatory steps per Supabase Auth):
  //
  //   Step 1 — enroll()
  //     Creates an unverified factor in auth.mfa_factors with status='unverified'.
  //     Returns: factorId (UUID), totp.qrCode (SVG string), totp.secret (base32).
  //     The QR code encodes an otpauth:// URI the authenticator app reads.
  //
  //   Step 2 — challenge()
  //     Prepares Supabase Auth to accept a TOTP code for this factor.
  //     Returns: challengeId (UUID). Challenges expire after ~10 minutes.
  //     A new challenge must be created each time the user clicks "Verify"
  //     (if they mistype and retry, challenge() is called again — see dialog).
  //
  //   Step 3 — verify()
  //     Submits the 6-digit code from the authenticator app.
  //     On success: factor status → 'verified', session AAL → aal2.
  //     On failure: throws AuthException — keep the dialog open, let user retry.
  //
  // UNENROLL FLOW:
  //   unenroll() removes the factor and downgrades AAL from aal2 to aal1.
  //   We call refreshSession() immediately after to force the JWT to reflect
  //   the downgrade without waiting for the next token refresh cycle.

  /// Fetches the user's verified TOTP factors and updates [_enrolledFactor].
  /// Called on initState and after successful enroll/unenroll.
  Future<void> _loadMfaStatus() async {
    setState(() => _mfaLoading = true);
    try {
      final result = await _supabase.auth.mfa.listFactors();
      if (mounted) {
        // We only care about verified TOTP factors — unverified ones mean a
        // previous enrollment was abandoned mid-flow and should be ignored.
        final verified = result.totp
            .where((f) => f.status == FactorStatus.verified)
            .toList();
        setState(() => _enrolledFactor = verified.isNotEmpty ? verified.first : null);
      }
    } catch (_) {
      // Non-fatal: if listFactors fails (e.g. offline) we show "Enable"
      // as the safe default. The user can tap it and get a proper error then.
      if (mounted) setState(() => _enrolledFactor = null);
    } finally {
      if (mounted) setState(() => _mfaLoading = false);
    }
  }

  /// Opens the enrollment dialog.
  /// Calls enroll() immediately on open to get the QR code, then walks the
  /// user through scanning and entering their first TOTP code to verify.
  void _showEnrollMfaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _MfaEnrollDialog(
        supabase: _supabase,
        onEnrolled: () {
          Navigator.pop(dialogContext);
          _loadMfaStatus();
          // Bug 1 fix: Navigator.pop closes the dialog, but the parent widget
          // (LoginSection) could theoretically have been disposed in the same
          // frame (e.g. rapid navigation). Guard before accessing context.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authenticator app enabled.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onCancelled: () => Navigator.pop(dialogContext),
      ),
    );
  }

  /// Confirms then unenrolls the active TOTP factor.
  ///
  /// Bug 2 fix — WHY unenroll needs aal2:
  /// Supabase requires the session to be at aal2 before it will accept
  /// unenroll(). This is intentional: without this requirement, anyone who
  /// unlocks a logged-in phone could silently disable MFA. The step-up dialog
  /// proves the user still has access to their authenticator app before we
  /// remove it. Only THEN do we show the final confirmation + call unenroll().
  Future<void> _showUnenrollMfaDialog() async {
    final factor = _enrolledFactor;
    if (factor == null) return;

    // ── Step-up check ──────────────────────────────────────────────────────
    // getAuthenticatorAssuranceLevel() is fast (rarely hits the network).
    final aal = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (!mounted) return;

    if (aal.currentLevel?.name != 'aal2') {
      // Session is aal1 — show TOTP step-up dialog first.
      // If the user cancels or enters the wrong code, we bail out entirely;
      // the unenroll confirmation dialog is never shown.
      final steppedUp = await _showMfaStepUpDialog();
      if (!mounted || !steppedUp) return;
    }
    // Session is now guaranteed aal2. Show the unenroll confirmation.

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(builder: (context, setDS) {
          return AlertDialog(
            title: const Text('Disable Authenticator App'),
            content: const Text(
              'This will remove two-factor authentication from your account. '
              'You will only need your password to log in.',
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setDS(() => isLoading = true);
                        try {
                          await _supabase.auth.mfa
                              .unenroll(factor.id);
                          // Force immediate JWT downgrade from aal2 → aal1.
                          // Without this the stale JWT keeps aal2 until it
                          // naturally expires (~1 hour).
                          await _supabase.auth.refreshSession();
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          _loadMfaStatus();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Two-factor authentication disabled.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } on AuthException catch (e) {
                          if (!dialogContext.mounted) return;
                          setDS(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Disable'),
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
    final user  = _supabase.auth.currentUser;

    // Bug 1 fix: read password_last_changed from user_metadata, not updatedAt.
    // updatedAt changes on any profile update (name, email, etc.). The
    // password_last_changed key is written explicitly by _updatePassword after
    // a successful updateUser(), so it only moves when the password moves.
    // Falls back to '—' for users who have never changed their password through
    // this flow (e.g. OAuth-only users or pre-fix accounts).
    final passwordLastUpdated = _formatDate(
      user?.userMetadata?['password_last_changed'] as String?,
    );
    final accountCreatedOn = _formatDate(user?.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Login',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        // ── Password ──────────────────────────────────────────────────────
        _buildSectionTitle(context, 'Password'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Password last updated: $passwordLastUpdated'),
            TextButton(
              onPressed:
                  _isUpdatingPassword ? null : _showUpdatePasswordDialog,
              child: const Text('Update'),
            ),
          ],
        ),
        const Divider(),

        // ── Passkey ───────────────────────────────────────────────────────
        _buildSectionTitle(context, 'Passkey'),
        const Text(
          'Use your fingerprint, face, or screen lock to log in without '
          'needing to ever remember, reset, or use a password. Passkeys are '
          'encrypted and stored on your device and are not visible to anyone, '
          'including ORINX.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: null, // disabled — Supabase Flutter SDK has no passkey API yet
          icon: const Icon(Icons.key),
          label: const Text('Add passkey'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Passkey support is coming soon.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const Divider(height: 48),

        // ── MFA (Phase 4) ──────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Multi-factor authentication (MFA)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // Green badge when MFA is active so the user can see at a
                // glance that their account is protected.
                if (_enrolledFactor != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Enabled',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            _mfaLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _enrolledFactor != null
                        ? _showUnenrollMfaDialog
                        : _showEnrollMfaDialog,
                    style: _enrolledFactor != null
                        ? TextButton.styleFrom(foregroundColor: Colors.red)
                        : null,
                    child: Text(
                        _enrolledFactor != null ? 'Disable' : 'Enable'),
                  ),
          ],
        ),
        const Divider(),

        // ── Sign out other devices ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sign out from all other devices'),
            FilledButton.tonal(
              onPressed: _isSigningOut ? null : _signOutOtherDevices,
              child: _isSigningOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign out'),
            ),
          ],
        ),
        const Divider(),

        // ── Data download ─────────────────────────────────────────────────
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Request to download data'),
          trailing: _isExporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          onTap: _isExporting ? null : _exportData,
        ),
        const Divider(height: 48),

        // ── Delete account ────────────────────────────────────────────────
        Text(
          'Delete account',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text('Account created on: $accountCreatedOn'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isDeletingAccount ? null : _showDeleteAccountDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.5),
          ),
          child: _isDeletingAccount
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

// =============================================================================
// _MfaEnrollDialog
//
// Extracted into its own StatefulWidget so it manages its own async lifecycle
// cleanly. The parent _LoginSectionState stays simple — it just opens this
// dialog and waits for onEnrolled / onCancelled.
//
// LAYOUT (two visual pages within one dialog):
//
//   Page 0 — Scan QR code
//     ┌──────────────────────────────────────┐
//     │  Scan this QR code with your         │
//     │  authenticator app                   │
//     │                                      │
//     │  ┌──────────────────────────────┐    │
//     │  │  <SVG QR code from Supabase> │    │
//     │  └──────────────────────────────┘    │
//     │                                      │
//     │  Can't scan?  [show secret]          │
//     │  <base32 secret + copy button>       │
//     │                                      │
//     │  [Cancel]              [Next →]      │
//     └──────────────────────────────────────┘
//
//   Page 1 — Enter code
//     ┌──────────────────────────────────────┐
//     │  Enter the 6-digit code shown        │
//     │  in your authenticator app           │
//     │                                      │
//     │  ┌──────────────────────────────┐    │
//     │  │  [ _ _ _ - _ _ _ ]           │    │
//     │  └──────────────────────────────┘    │
//     │                                      │
//     │  [← Back]              [Verify]      │
//     └──────────────────────────────────────┘
// =============================================================================
class _MfaEnrollDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final VoidCallback   onEnrolled;
  final VoidCallback   onCancelled;

  const _MfaEnrollDialog({
    required this.supabase,
    required this.onEnrolled,
    required this.onCancelled,
  });

  @override
  State<_MfaEnrollDialog> createState() => _MfaEnrollDialogState();
}

class _MfaEnrollDialogState extends State<_MfaEnrollDialog> {
  // Enrollment data returned by enroll()
  String? _factorId;
  String? _qrSvg;    // raw SVG string — rendered with SvgPicture.string()
  String? _secret;   // base32 secret for manual entry

  // UI state
  int  _page          = 0;    // 0 = scan QR, 1 = enter code
  bool _loadingEnroll = true; // true while enroll() is in-flight
  bool _loadingVerify = false;
  bool _showSecret    = false;
  String? _errorMessage;

  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startEnrollment();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Step 1 — enroll()
  /// Creates the factor in auth.mfa_factors (status = 'unverified') and
  /// returns the QR code and secret needed by the authenticator app.
  Future<void> _startEnrollment() async {
    try {
      final response = await widget.supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        // issuer and friendlyName appear in the authenticator app's entry list.
        issuer: 'ORINX',
        friendlyName: widget.supabase.auth.currentUser?.email ?? 'ORINX Account',
      );
      if (mounted) {
        setState(() {
          _factorId     = response.id;
          final totp = response.totp;
if (totp != null) {
  _qrSvg = totp.qrCode;
  _secret = totp.secret;
}
          _loadingEnroll = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage  = e.message;
          _loadingEnroll = false;
        });
      }
    }
  }

  /// Steps 2 + 3 — challenge() then verify()
  /// Called each time the user presses "Verify" on page 1.
  /// A fresh challenge is created every attempt so expired challenges
  /// don't cause spurious errors on retries.
  Future<void> _verifyCode() async {
    final code     = _codeCtrl.text.trim();
    final factorId = _factorId;

    if (factorId == null) return;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your app.');
      return;
    }

    setState(() {
      _loadingVerify = true;
      _errorMessage  = null;
    });

    try {
      // Step 2 — create a challenge for this factor
      final challengeRes = await widget.supabase.auth.mfa
          .challenge(factorId: factorId);

      // Step 3 — verify the TOTP code against the challenge
      await widget.supabase.auth.mfa.verify(
        factorId:    factorId,
        challengeId: challengeRes.id,
        code:        code,
      );

      // Success — factor is now verified (status = 'verified'), session
      // AAL is upgraded to aal2 automatically by the SDK.
      widget.onEnrolled();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          // Map the most common server error to a friendlier message.
          _errorMessage = e.message.toLowerCase().contains('invalid')
              ? 'Incorrect code. Check your authenticator app and try again.'
              : e.message;
          _loadingVerify = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_page == 0
          ? 'Set up authenticator app'
          : 'Verify authenticator app'),
      // Fixed height so the dialog doesn't jump between pages.
      content: SizedBox(
        width: 320,
        child: _page == 0 ? _buildScanPage() : _buildVerifyPage(),
      ),
      actions: _page == 0 ? _scanActions() : _verifyActions(),
    );
  }

  // ── Page 0: QR code ───────────────────────────────────────────────────────

  Widget _buildScanPage() {
    if (_loadingEnroll) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _qrSvg == null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Open your authenticator app (Google Authenticator, Authy, '
            '1Password, etc.) and scan this QR code.',
          ),
          const SizedBox(height: 20),

          // QR code — Supabase returns raw SVG.
          // flutter_svg renders it natively without needing an image codec.
          if (_qrSvg != null)
            Container(
              width: 200,
              height: 200,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white, // QR codes need white background
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SvgPicture.string(
                _qrSvg!,
                fit: BoxFit.contain,
              ),
            ),

          const SizedBox(height: 16),

          // Manual entry fallback
          TextButton.icon(
            icon: Icon(
                _showSecret ? Icons.visibility_off : Icons.visibility_outlined,
                size: 16),
            label: Text(_showSecret ? 'Hide secret key' : 'Can\'t scan? Show secret key'),
            onPressed: () => setState(() => _showSecret = !_showSecret),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          ),

          if (_showSecret && _secret != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _secret!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy secret',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _secret!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Secret copied to clipboard.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Type or paste this key into your authenticator app.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _scanActions() => [
        TextButton(
          onPressed: widget.onCancelled,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loadingEnroll || _qrSvg == null
              ? null
              : () => setState(() {
                    _page         = 1;
                    _errorMessage = null;
                  }),
          child: const Text('Next →'),
        ),
      ];

  // ── Page 1: enter code ────────────────────────────────────────────────────

  Widget _buildVerifyPage() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the 6-digit code currently shown in your authenticator app '
            'to confirm the setup is working.',
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _codeCtrl,
            enabled: !_loadingVerify,
            autofocus: true,
            keyboardType: TextInputType.number,
            // Allow only digits; TOTP codes are always 6 numeric digits.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontFamily: 'monospace',
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                letterSpacing: 8,
              ),
              border: const OutlineInputBorder(),
              errorText: _errorMessage,
              // Live feedback: green border when 6 digits entered
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _codeCtrl.text.length == 6
                      ? Colors.green
                      : Colors.grey.shade400,
                  width: _codeCtrl.text.length == 6 ? 2 : 1,
                ),
              ),
            ),
            onChanged: (_) => setState(() => _errorMessage = null),
            // Submit on keyboard "done" / Enter key
            onSubmitted: (_) {
              if (!_loadingVerify) _verifyCode();
            },
          ),

          const SizedBox(height: 12),
          const Text(
            'Codes refresh every 30 seconds. If the code is rejected, '
            'wait for the next one and try again.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _verifyActions() => [
        TextButton(
          onPressed: _loadingVerify
              ? null
              : () => setState(() {
                    _page         = 0;
                    _errorMessage = null;
                    _codeCtrl.clear();
                  }),
          child: const Text('← Back'),
        ),
        FilledButton(
          onPressed: _loadingVerify ? null : _verifyCode,
          child: _loadingVerify
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify'),
        ),
      ];
}
