import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/team_context_controller.dart';

/// OverviewScreen
///
/// Bug 1 Fix: On first mount, we call [TeamContextController.loadWithRetry]
/// instead of the bare [load]. This retries the `get_my_workspace_context`
/// RPC a few times with exponential backoff, bridging the narrow window
/// where the Postgres trigger has just run but the app loaded before the
/// first response resolved (typically only a few hundred milliseconds on
/// a fresh email-confirmation redirect).
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();

    // If we already have a resolved team context (e.g. navigating back from
    // another tab), skip the retry — load() is a no-op while _isLoading is
    // true, so this is safe to call unconditionally.
    final controller = TeamContextController.instance;
    if (!controller.hasTeam && !controller.isLoading) {
      // Post-frame to avoid calling setState-like operations during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TeamContextController.instance.loadWithRetry();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TeamContextController.instance,
      builder: (context, _) {
        final controller = TeamContextController.instance;

        // While retrying, show a loading state instead of "No active workspace"
        if (controller.isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading workspace…'),
              ],
            ),
          );
        }

        // After all retries, still no team — surface a clear error with a
        // manual retry button rather than a confusing blank screen.
        if (!controller.hasTeam) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_outlined,
                    size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No active workspace found.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This can happen if your account is still being set up.\n'
                  'Please wait a moment and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => controller.loadWithRetry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Normal dashboard content
        return _DashboardContent(teamId: controller.teamId!);
      },
    );
  }
}

// ─── Dashboard Content ────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final String teamId;

  const _DashboardContent({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

          // Connect-accounts prompt
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('connected_accounts')
                .select()
                .eq('team_id', teamId),
            builder: (context, snapshot) {
              final connections = snapshot.data ?? [];
              if (connections.isEmpty) {
                return Card(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
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

          // Recent Activity (placeholder)
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
            separatorBuilder: (_, __) => const Divider(),
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

// ─── Stat Card ────────────────────────────────────────────────────────────────

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
