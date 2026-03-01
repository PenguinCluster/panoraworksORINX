import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_handler.dart';

class SetPasswordScreen extends StatefulWidget {
  final String? next;
  const SetPasswordScreen({super.key, this.next});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _error;
  bool _hasSession = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkSession();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      final session = data.session;
      if (session == null) return;

      if (event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.tokenRefreshed) {
        if (!mounted) return;
        setState(() {
          _hasSession = true;
          _error = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _loginUrlPreservingNext() {
    final finalNext = widget.next;
    final current = (finalNext != null && finalNext.isNotEmpty)
        ? '/set-password?next=${Uri.encodeComponent(finalNext)}'
        : '/set-password';
    return '/login?next=${Uri.encodeComponent(current)}';
  }

  void _checkSession() {
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _hasSession = session != null;
      if (!_hasSession) {
        _error =
            'No valid session found. Please reopen the invite link from your email.';
      }
    });
  }

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception(
          'Session expired or missing. Please return to the invite email.',
        );
      }

      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      // FIX BUG 2: Force fresh JWT after password update (prevents 401 in join-team)
      await supabase.auth.refreshSession();
      debugPrint('SetPasswordScreen: Session refreshed after password update');

      try {
        await supabase.rpc('mark_password_initialized');
      } catch (e) {
        debugPrint('mark_password_initialized failed (optional step): $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password set successfully!')),
      );

      final nextDest = widget.next;
      debugPrint('SetPasswordScreen: Routing to next=$nextDest');

      if (nextDest != null && nextDest.isNotEmpty) {
        context.go(nextDest);
      } else {
        context.go('/app/overview');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceAll('Exception:', '').trim(),
        );
        ErrorHandler.handle(
          context,
          e,
          customMessage: 'Failed to set password',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please set a password to finish setting up your account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              if (!_hasSession) ...[
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {
                                    context.go(_loginUrlPreservingNext());
                                  },
                                  child: const Text('Return to Login'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        enabled: _hasSession && !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        enabled: _hasSession && !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.check_circle_outline),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: (_hasSession && !_isLoading) ? _setPassword : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Set Password & Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}