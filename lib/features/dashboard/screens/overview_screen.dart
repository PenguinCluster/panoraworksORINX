import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/team_context_controller.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamId = TeamContextController.instance.teamId;

    if (teamId == null) {
      return const Center(child: Text('No active workspace'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            children: [
              _StatCard(
                title: 'Total Reach',
                value: '12.4k',
                icon: Icons.people_outline,
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _StatCard(
                title: 'Engagement',
                value: '3.2%',
                icon: Icons.thumb_up_outlined,
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              _StatCard(
                title: 'Active Alerts',
                value: '4',
                icon: Icons.notifications_active_outlined,
                color: Colors.orange,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Connect accounts state
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('connected_accounts')
                .select()
                .eq('team_id', teamId), // CHANGED: Filter by team_id
            builder: (context, snapshot) {
              final connections = snapshot.data ?? [];
              if (connections.isEmpty) {
                return Card(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.link_off, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Connect accounts to activate real-time monitoring',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Go to Settings to link your Facebook, TikTok, or Discord.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/app/settings'),
                          child: const Text('Go to Settings'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(height: 32),

          // Recent Activity (Simulated)
          Text(
            'Recent Activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.history)),
                title: Text('Post ${index + 1} scheduled for tomorrow'),
                subtitle: const Text('Simulated activity'),
                trailing: const Text('2h ago'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
