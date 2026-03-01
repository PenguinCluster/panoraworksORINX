import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../../shared/widgets/oauth_buttons.dart';
import '../../../core/utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  final String? next;

  const LoginScreen({super.key, this.next});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _sanitizeNext(String? raw) {
    if (raw == null) return null;
    final next = raw.trim();
    if (next.isEmpty) return null;

    // Only allow internal navigation
    if (!next.startsWith('/')) return null;

    // Prevent redirect loops back to auth pages
    if (next.startsWith('/login') ||
        next.startsWith('/signup') ||
        next.startsWith('/forgot-password') ||
        next.startsWith('/auth/callback')) {
      return null;
    }

    return next;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // ── Bug 2 fix: MFA check after signInWithPassword ──────────────────
      //
      // signInWithPassword always returns aal1, even for MFA users.
      // getAuthenticatorAssuranceLevel() tells us whether a step-up is needed:
      //
      //   nextLevel == aal2 && currentLevel == aal1
      //     → User has a verified TOTP factor enrolled.
      //       Send them to MfaVerifyScreen before letting them into the app.
      //
      //   nextLevel == aal1 (== currentLevel)
      //     → No MFA enrolled. Proceed normally.
      //
      // getAuthenticatorAssuranceLevel() is fast and rarely hits the network.
      final aal = Supabase.instance.client.auth.mfa
          .getAuthenticatorAssuranceLevel();

      if (!mounted) return;

      if (aal.nextLevel?.name == 'aal2' &&
          aal.currentLevel?.name != 'aal2') {
        // MFA enrolled but not yet verified this session.
        // Navigate to the dedicated MFA screen, carrying `next` through so
        // the user lands in the right place after a successful TOTP verify.
        final dest = _sanitizeNext(widget.next) ?? '/app/overview';
        context.go('/mfa-verify?next=${Uri.encodeComponent(dest)}');
        // LoginScreen is done — MfaVerifyScreen owns the rest of the flow.
        return;
      }

      // No MFA enrolled (aal1 == aal1), proceed directly to the app.
      ErrorHandler.showSuccess(context, 'Login successful');

      final dest = _sanitizeNext(widget.next);
      if (dest != null) {
        context.go(dest);
      } else {
        context.go('/app/overview');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e, customMessage: 'Login failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      final next = _sanitizeNext(widget.next);
                      if (next != null) {
                        context.push('/signup?next=${Uri.encodeComponent(next)}');
                      } else {
                        context.push('/signup');
                      }
                    },
                    child: const Text('Don\'t have an account? Sign Up'),
                  ),
                  const SizedBox(height: 32),
                  OAuthButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
