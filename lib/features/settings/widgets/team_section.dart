import 'package:flutter/material.dart';

class TeamSection extends StatelessWidget {
  const TeamSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Team and people', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite people'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final isOwner = index == 0;
              return ListTile(
                leading: CircleAvatar(child: Text(isOwner ? 'JD' : 'AS')),
                title: Text(isOwner ? 'John Doe' : 'Alice Smith'),
                subtitle: Text(isOwner ? 'john.doe@example.com' : 'alice@example.com'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(label: Text(isOwner ? 'Owner' : 'Member')),
                    if (!isOwner) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () {},
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
