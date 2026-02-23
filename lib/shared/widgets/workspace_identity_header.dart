import 'package:flutter/material.dart';
import '../../core/state/team_context_controller.dart';

class WorkspaceIdentityHeader extends StatelessWidget {
  const WorkspaceIdentityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: TeamContextController.instance,
      builder: (context, child) {
        final controller = TeamContextController.instance;

        if (controller.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Loading...')),
              ],
            ),
          );
        }

        final hasTeam = controller.hasTeam;
        final displayName = hasTeam
            ? controller.workspaceDisplayName
            : 'Workspace';
        final avatarUrl = hasTeam ? controller.workspaceAvatarUrl : null;
        final role = controller.role;

        // Fallback Initial
        String initial = 'W';
        if (displayName.isNotEmpty) {
          initial = displayName[0].toUpperCase();
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  image: avatarUrl != null && avatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (role != null)
                      Text(
                        role.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
