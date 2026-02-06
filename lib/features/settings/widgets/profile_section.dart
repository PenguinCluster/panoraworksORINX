import 'package:flutter/material.dart';

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        
        // Profile Picture
        Row(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload your profile photo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('Upload photo'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Name and Email
        _buildEditableField(context, 'User\'s Name', 'John Doe'),
        _buildEditableField(context, 'User\'s Email address', 'john.doe@example.com'),

        // Language
        const Text('Language', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: 'English',
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ['English', 'Spanish', 'French', 'German']
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (value) {},
        ),
        const SizedBox(height: 32),

        // Connected social accounts
        const Text('Connected social accounts', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            'YouTube', 'Facebook', 'X.com', 'Twitch', 'Reddit', 
            'Telegram', 'WhatsApp', 'TikTok', 'Discord'
          ].map((s) => ActionChip(
            avatar: const Icon(Icons.link, size: 16),
            label: Text(s),
            onPressed: () {},
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildEditableField(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('Edit')),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
          const Divider(),
        ],
      ),
    );
  }
}
