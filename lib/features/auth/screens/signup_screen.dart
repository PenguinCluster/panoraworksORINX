import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../../shared/widgets/oauth_buttons.dart';
import '../../../core/utils/error_handler.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailLockAndSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      // 1. Check Email Lock via DB Function
      final lockResult = await _supabase.rpc(
        'check_email_lock',
        params: {'check_email': email},
      );

      // 2. Handle Lock
      if (lockResult != null && lockResult['locked'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Email Reserved'),
              content: const Text(
                'This email address has already been invited to a team. '
                'You cannot create a standalone account.\n\n'
                'Please check your email for the invitation link to join your team.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 3. Proceed with standard signup if not locked
      await _authService.signUp(
        email: email,
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
      );

      if (mounted) {
        ErrorHandler.showSuccess(
          context,
          'Verification email sent! Please check your inbox.',
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e, customMessage: 'Signup failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
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
                    'Create Account',
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
                      if (value == null || value.isEmpty)
                        return 'Please enter your email';
                      if (!value.contains('@'))
                        return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter a username';
                      if (value.length < 3)
                        return 'Username must be at least 3 characters';
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
                      if (value == null || value.isEmpty)
                        return 'Please enter your password';
                      if (value.length < 6)
                        return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != _passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isLoading ? null : _checkEmailLockAndSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Already have an account? Login'),
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
