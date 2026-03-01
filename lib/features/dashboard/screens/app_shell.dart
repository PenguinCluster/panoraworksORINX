import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/state/profile_manager.dart';
import '../../../core/state/team_context_controller.dart';
import '../../../shared/widgets/workspace_identity_header.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);

    // Ensure ProfileManager is initialized
    ProfileManager.instance;

    return Scaffold(
      drawer: isMobile ? const _Sidebar() : null,
      appBar: isMobile ? AppBar(title: const Text('ORINX')) : null,
      body: Row(
        children: [
          if (!isMobile) const _Sidebar(),
          Expanded(
            child: Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
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
    final String location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 280,
      height: double.infinity,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Workspace Identity Header
          if (!isMobile) const WorkspaceIdentityHeader(),

          // Profile Section (Personal Identity & Logout)
          _ProfileSection(authService: authService),

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
  final AuthService authService;

  const _ProfileSection({required this.authService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        ProfileManager.instance.profileNotifier,
        TeamContextController.instance,
      ]),
      builder: (context, child) {
        final userProfile = ProfileManager.instance.profileNotifier.value;
        final teamContext = TeamContextController.instance;

        if (userProfile == null) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Settings access is allowed if canAccessSettings is true.
        // Internal gating inside SettingsScreen handles RBAC for workspace tabs.
        final canAccessSettings = teamContext.canAccessSettings;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: theme.primaryColor,
                  backgroundImage: userProfile.avatarUrl.isNotEmpty
                      ? NetworkImage(userProfile.avatarUrl)
                      : null,
                  child: userProfile.avatarUrl.isEmpty
                      ? Text(
                          userProfile.initials,
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(
                  userProfile.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  userProfile.email,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                children: [
                  if (canAccessSettings)
                    ListTile(
                      leading: const Icon(Icons.settings_outlined, size: 20),
                      title: const Text('Settings'),
                      onTap: () {
                        if (MediaQuery.of(context).size.width < 900)
                          {
                            Navigator.pop(context);
                          }
                        context.go('/app/settings');
                      },
                    ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      size: 20,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.red),
                    ),
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
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
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
