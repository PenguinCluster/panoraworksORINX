import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: isMobile ? const _Sidebar() : null,
      appBar: isMobile
          ? AppBar(
              title: const Text('ORINX'),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile) const _Sidebar(),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
              child: SafeArea(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;
    final authService = AuthService();
    final user = authService.currentUser;
    final String location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 280,
      height: double.infinity,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header / Logo
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ORINX',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),

          // Profile Section
          _ProfileSection(user: user, authService: authService),

          const Divider(indent: 16, endIndent: 16),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Overview',
                  isSelected: location == '/app/overview',
                  onTap: () => context.go('/app/overview'),
                ),
                _MenuItem(
                  icon: Icons.hub_outlined,
                  selectedIcon: Icons.hub,
                  label: 'Content Hub',
                  isSelected: location == '/app/content',
                  onTap: () => context.go('/app/content'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications,
                  label: 'Live Alerts',
                  isSelected: location == '/app/alerts',
                  onTap: () => context.go('/app/alerts'),
                ),
                _MenuItem(
                  icon: Icons.search_outlined,
                  selectedIcon: Icons.search,
                  label: 'Keyword Monitoring',
                  isSelected: location == '/app/keywords',
                  onTap: () => context.go('/app/keywords'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final User? user;
  final AuthService authService;

  const _ProfileSection({required this.user, required this.authService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = user?.email ?? 'user@example.com';

    return FutureBuilder<Map<String, dynamic>?>(
      future: Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user?.id ?? '')
          .maybeSingle(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final String displayName = profile?['username'] ?? email.split('@').first;
        final String initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  child: Text(initials, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  email,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, size: 20),
                    title: const Text('Settings'),
                    onTap: () {
                      if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
                      context.go('/app/settings');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, size: 20, color: Colors.red),
                    title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await authService.signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
