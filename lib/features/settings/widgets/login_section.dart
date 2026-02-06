import 'package:flutter/material.dart';

class LoginSection extends StatelessWidget {
  const LoginSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Login', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        // Password
        _buildSectionTitle(context, 'Password'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Password last updated: Feb 6, 2026'),
            TextButton(onPressed: () {}, child: const Text('Update')),
          ],
        ),
        const Divider(),

        // Passkey
        _buildSectionTitle(context, 'Passkey'),
        const Text(
          'Use your fingerprint, face, or screen lock to log in without needing to ever remember, reset, or use a password. Passkeys are encrypted and stored on your device and are not visible to anyone, including ORINX.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.key),
          label: const Text('Add element'),
        ),
        const Divider(height: 48),

        // MFA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Multi-factor authentication (MFA)', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('Enable')),
          ],
        ),
        const Divider(),

        // Sign out devices
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sign out from all devices'),
            FilledButton.tonal(onPressed: () {}, child: const Text('Sign out')),
          ],
        ),
        const Divider(),

        // Data download
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Request to download data'),
          trailing: const Icon(Icons.download),
          onTap: () {},
        ),
        const Divider(height: 48),

        // Delete account
        Text('Delete account', style: theme.textTheme.titleMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Account created on: Feb 6, 2026'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete account'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
