import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/services/auth_service.dart';

class OAuthButtons extends StatelessWidget {
  final AuthService _authService = AuthService();

  OAuthButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR CONTINUE WITH'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _OAuthButton(
              icon: Icons.g_mobiledata,
              label: 'Google',
              onPressed: () => _authService.signInWithOAuth(OAuthProvider.google),
            ),
            _OAuthButton(
              icon: Icons.apple,
              label: 'Apple',
              onPressed: () => _authService.signInWithOAuth(OAuthProvider.apple),
            ),
            _OAuthButton(
              icon: Icons.window,
              label: 'Microsoft',
              onPressed: () => _authService.signInWithOAuth(OAuthProvider.azure),
            ),
            _OAuthButton(
              icon: Icons.facebook,
              label: 'Facebook',
              onPressed: () => _authService.signInWithOAuth(OAuthProvider.facebook),
            ),
            _OAuthButton(
              icon: Icons.close,
              label: 'X.com',
              onPressed: () => _authService.signInWithOAuth(OAuthProvider.twitter),
            ),
          ],
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OAuthButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
