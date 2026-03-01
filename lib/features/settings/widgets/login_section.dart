import 'package:flutter/material.dart';
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
  bool _isSigningOut    = false;
  bool _isUpdatingPassword = false;
  bool _isDeletingAccount  = false;

  // ── Date helpers (Phase 1) ──────────────────────────────────────────────────

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return '—';
    }
  }

  // ── Sign out other devices (Phase 1) ───────────────────────────────────────

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

  // ── Update Password (Phase 2) ───────────────────────────────────────────────

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

        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                            onPressed: () => setDialogState(
                                () => obscureCurrent = !obscureCurrent),
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
                            onPressed: () => setDialogState(
                                () => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a new password';
                          if (v.length < 8) return 'Password must be at least 8 characters';
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
                            onPressed: () => setDialogState(
                                () => obscureConfirm = !obscureConfirm),
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
                          setDialogState(() => isLoading = true);
                          final success = await _updatePassword(
                            currentPassword: currentPasswordCtrl.text,
                            newPassword: newPasswordCtrl.text,
                          );
                          if (!dialogContext.mounted) return;
                          setDialogState(() => isLoading = false);
                          if (success) Navigator.pop(dialogContext);
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
          },
        );
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

      await _supabase.auth.signInWithPassword(
          email: email, password: currentPassword);
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      if (mounted) {
        setState(() {});
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
        final message =
            e.message.toLowerCase().contains('invalid login credentials')
                ? 'Current password is incorrect.'
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

  // ── Delete Account (Phase 3) ────────────────────────────────────────────────
  //
  // WHY an Edge Function is required:
  //   The client-side Supabase SDK has no deleteUser() method. Only the Admin
  //   API (service-role key) can remove a row from auth.users. Exposing the
  //   service-role key in the Flutter app is a critical security risk, so the
  //   deletion must go through a server-side Edge Function (delete-account v1)
  //   that holds the key in a Deno environment variable.
  //
  // CALL ORDER — why we invoke the function BEFORE signing out locally:
  //   1. Call delete-account (uses the current valid JWT to authenticate).
  //   2. Edge Function deletes the auth.users row → Postgres cascade removes
  //      all public-schema data atomically.
  //   3. Sign out locally (SignOutScope.local) to clear the device token.
  //      We don't need SignOutScope.global here because the user row is gone;
  //      all other sessions will fail on next use automatically.
  //   4. Clear TeamContextController in-memory state (ProfileManager
  //      self-clears via its onAuthStateChange(signedOut) listener).
  //   5. Navigate to /login.
  //
  //   If we called signOut() first, the JWT would be revoked before the Edge
  //   Function could authenticate the request → 401.

  void _showDeleteAccountDialog() {
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading      = false;
        bool inputMatches   = false;
        const confirmWord   = 'DELETE';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Delete Account'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Severity warning
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
                    // Typed confirmation — prevents accidental taps on mobile
                    // and makes the user consciously acknowledge the action.
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'Type '),
                          TextSpan(
                            text: confirmWord,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
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
                        errorText: confirmCtrl.text.isNotEmpty && !inputMatches
                            ? 'Type DELETE in capitals'
                            : null,
                      ),
                      onChanged: (v) => setDialogState(
                          () => inputMatches = v == confirmWord),
                    ),
                  ],
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
                  // Active only when the user has typed DELETE exactly.
                  onPressed: (inputMatches && !isLoading)
                      ? () async {
                          setDialogState(() => isLoading = true);
                          final success = await _deleteAccount();
                          if (!dialogContext.mounted) return;
                          // On success the screen is already gone; we only
                          // need to handle failure (dialog stays open).
                          if (!success) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red),
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
          },
        );
      },
    ).whenComplete(confirmCtrl.dispose);
  }

  /// Calls the delete-account Edge Function, signs out locally, clears
  /// in-memory state, and navigates to /login.
  ///
  /// Returns true on success (caller can close any dialogs / navigate away),
  /// false on failure (caller keeps the confirmation dialog open).
  Future<bool> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);

    try {
      // Step 1 — Call the Edge Function with the current JWT.
      //   The function authenticates the caller, then uses the service-role
      //   key server-side to call admin.deleteUser(). This triggers the full
      //   Postgres cascade chain, atomically removing all public-schema rows.
      final response = await _supabase.functions.invoke('delete-account');

      if (response.status != 200) {
        final error = response.data?['error'] as String?
            ?? 'Account deletion failed. Please try again.';
        throw Exception(error);
      }

      // Step 2 — Clear the local session token.
      //   SignOutScope.local only clears the on-device token; no server call.
      //   The auth.users row is already gone so SignOutScope.global is both
      //   unnecessary and would return an error on the revoke endpoint.
      await _supabase.auth.signOut(scope: SignOutScope.local);

      // Step 3 — Clear in-memory state.
      //   TeamContextController must be cleared manually.
      //   ProfileManager self-clears via its onAuthStateChange(signedOut)
      //   listener that fired when signOut() was called above.
      TeamContextController.instance.clear();

      // Step 4 — Navigate to /login and replace the entire navigation stack
      //   so the user cannot press Back to return to the deleted account's UI.
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user  = _supabase.auth.currentUser;

    final passwordLastUpdated = _formatDate(user?.updatedAt);
    final accountCreatedOn    = _formatDate(user?.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Login',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),

        // ── Password ────────────────────────────────────────────────────────
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

        // ── Passkey ─────────────────────────────────────────────────────────
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
          onPressed: () {},
          icon: const Icon(Icons.key),
          label: const Text('Add passkey'),
        ),
        const Divider(height: 48),

        // ── MFA ─────────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Multi-factor authentication (MFA)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: () {}, child: const Text('Enable')),
          ],
        ),
        const Divider(),

        // ── Sign out other devices ───────────────────────────────────────────
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

        // ── Data download ────────────────────────────────────────────────────
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Request to download data'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        ),
        const Divider(height: 48),

        // ── Delete account ───────────────────────────────────────────────────
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
            disabledBackgroundColor: Colors.red.withOpacity(0.5),
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
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
