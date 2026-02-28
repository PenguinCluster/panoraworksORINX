import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/profile_section.dart';
import '../widgets/login_section.dart';
import '../widgets/accessibility_section.dart';
import '../widgets/team_section.dart';
import '../widgets/billing_section.dart';
import '../widgets/orders_section.dart';
import '../../../core/state/team_context_controller.dart';

class SettingsScreen extends StatefulWidget {
  final String initialTab;
  const SettingsScreen({super.key, this.initialTab = 'profile'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _selectedIndex;

  final List<String> _allSections = [
    'Your profile',
    'Login',
    'Accessibility',
    'Team and people',
    'Billing',
    'Orders and invoices',
  ];

  final List<String> _allSlugs = [
    'profile',
    'login',
    'accessibility',
    'team',
    'billing',
    'orders',
  ];

  @override
  void initState() {
    super.initState();
    _updateIndexFromTab(widget.initialTab);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _updateIndexFromTab(widget.initialTab);
    }
  }

  void _updateIndexFromTab(String tab) {
    final index = _allSlugs.indexOf(tab);
    setState(() {
      _selectedIndex = index != -1 ? index : 0;
    });
  }

  void _onSectionSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go('/app/settings/${_allSlugs[index]}');
  }

  bool _isSectionEnabled(String slug) {
    final controller = TeamContextController.instance;
    switch (slug) {
      case 'profile':
        return controller.canAccessProfileTab;
      case 'login':
        return controller.canAccessLoginTab;
      case 'accessibility':
        return controller.canAccessAccessibilityTab;
      case 'team':
        return controller.canAccessTeamTab;
      case 'billing':
        // RBAC: canAccessBillingTab is now owner-only (changed from isOwner || isAdmin).
        // Admins see the item visually locked rather than hidden.
        return controller.canAccessBillingTab;
      case 'orders':
        return controller.canAccessOrdersTab;
      default:
        return false;
    }
  }

  /// Returns a non-null tooltip string when this slug is visible but gated
  /// for the current user's role, explaining why it is disabled.
  String? _disabledTooltip(String slug, TeamContextController controller) {
    // Only admins see workspace-level items that are then locked.
    // Members and managers don't see billing/orders at all (canAccessTeamTab
    // is already false for them, so they never reach this check).
    if (!controller.isAdmin) return null;

    switch (slug) {
      case 'billing':
        return 'Billing is only accessible to the workspace owner';
      case 'orders':
        return 'Orders are only accessible to the workspace owner';
      default:
        return null;
    }
  }

  Widget _buildContent(int index) {
    final currentSlug = _allSlugs[index];
    switch (currentSlug) {
      case 'profile':
        return const ProfileSection();
      case 'login':
        return const LoginSection();
      case 'accessibility':
        return const AccessibilitySection();
      case 'team':
        return const TeamSection();
      case 'billing':
        return const BillingSection();
      case 'orders':
        return const OrdersSection();
      default:
        return const ProfileSection();
    }
  }

  Icon _getIconForSlug(String slug) {
    switch (slug) {
      case 'profile':
        return const Icon(Icons.person_outline);
      case 'login':
        return const Icon(Icons.lock_outline);
      case 'accessibility':
        return const Icon(Icons.accessibility_new);
      case 'team':
        return const Icon(Icons.group_outlined);
      case 'billing':
        return const Icon(Icons.credit_card);
      case 'orders':
        return const Icon(Icons.receipt_long_outlined);
      default:
        return const Icon(Icons.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return ListenableBuilder(
      listenable: TeamContextController.instance,
      builder: (context, _) {
        final controller = TeamContextController.instance;

        if (controller.isLoading && controller.role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/app/overview'),
            ),
            actions: [_HelpAndResourcesButton()],
          ),
          body: Builder(
            builder: (context) {
              // Safety fallback: if the current tab is no longer accessible
              // after a role change, snap back to Profile.
              int effectiveIndex = _selectedIndex;
              if (!_isSectionEnabled(_allSlugs[effectiveIndex])) {
                effectiveIndex = 0;
              }

              return Row(
                children: [
                  // ── Sidebar ───────────────────────────────────────────────
                  Container(
                    width: isDesktop ? 280 : 80,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                            color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: _allSections.length,
                      itemBuilder: (context, index) {
                        final slug = _allSlugs[index];
                        final label = _allSections[index];
                        final isEnabled = _isSectionEnabled(slug);
                        final isSelected = effectiveIndex == index;
                        final tooltip = _disabledTooltip(slug, controller);

                        // Determine whether this item should appear at all.
                        // Items the current role has no awareness of are hidden.
                        // Items that are visible-but-locked show a lock badge.
                        final isVisible = _isItemVisible(slug, controller);
                        if (!isVisible) return const SizedBox.shrink();

                        final listTile = ListTile(
                          selected: isSelected,
                          enabled: isEnabled,
                          leading: isDesktop
                              ? _getIconForSlug(slug)
                              : _getIconForSlug(slug),
                          title: isDesktop
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: isEnabled
                                            ? null
                                            : TextStyle(
                                                color: Theme.of(context)
                                                    .disabledColor,
                                              ),
                                      ),
                                    ),
                                    // Lock badge for owner-only items that
                                    // admins can see but not access.
                                    if (!isEnabled && tooltip != null)
                                      Icon(
                                        Icons.lock_outline,
                                        size: 14,
                                        color:
                                            Theme.of(context).disabledColor,
                                      ),
                                  ],
                                )
                              : null,
                          onTap: isEnabled
                              ? () => _onSectionSelected(index)
                              : null,
                        );

                        // Wrap in Tooltip when disabled and we have a reason.
                        if (!isEnabled && tooltip != null) {
                          return Tooltip(
                            message: tooltip,
                            child: listTile,
                          );
                        }
                        return listTile;
                      },
                    ),
                  ),

                  // ── Content pane ──────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildContent(effectiveIndex),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Controls whether a sidebar item is rendered at all.
  ///
  /// Visibility rules:
  ///   - All users see personal tabs (profile, login, accessibility).
  ///   - Owner + admin see workspace tabs (team, billing, orders).
  ///     Admins see billing/orders in the sidebar but locked — they need to
  ///     understand the workspace structure even if they can't access billing.
  ///   - Members and managers do not see workspace tabs at all.
  bool _isItemVisible(String slug, TeamContextController controller) {
    switch (slug) {
      case 'profile':
      case 'login':
      case 'accessibility':
        return true; // always visible
      case 'team':
        return controller.canAccessTeamTab;
      case 'billing':
      case 'orders':
        // Admins see billing/orders locked; non-admins without canAccessBillingTab
        // (i.e. managers, members) do not see them at all.
        return controller.canAccessWorkspaceSettings;
      default:
        return false;
    }
  }
}

class _HelpAndResourcesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Help and Resources',
      onSelected: (value) {
        switch (value) {
          case 'privacy':
            context.go('/app/settings/privacy-policy');
          case 'contact':
            context.go('/app/settings/contact-us');
          case 'suggest':
            context.go('/app/settings/suggest-improvements');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
        PopupMenuItem(value: 'contact', child: Text('Contact Us')),
        PopupMenuItem(value: 'suggest', child: Text('Suggest Improvements')),
      ],
    );
  }
}
