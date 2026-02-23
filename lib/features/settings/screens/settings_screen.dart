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

    // Use centralized RBAC checks
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
        return controller.canAccessBillingTab;
      case 'orders':
        return controller.canAccessOrdersTab;
      default:
        return false;
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

        // If context is still loading, show loading.
        // Or if we don't have a role yet (and assume we need one).
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
              // Safety check: If current tab is disabled for this role, fallback to Profile
              int effectiveIndex = _selectedIndex;
              final currentSlug = _allSlugs[effectiveIndex];

              if (!_isSectionEnabled(currentSlug)) {
                effectiveIndex = 0; // Default to Profile
              }

              return Row(
                children: [
                  // Sidebar
                  Container(
                    width: isDesktop ? 280 : 80,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: _allSections.length,
                      itemBuilder: (context, index) {
                        final slug = _allSlugs[index];
                        final isEnabled = _isSectionEnabled(slug);
                        final isSelected = effectiveIndex == index;

                        return ListTile(
                          selected: isSelected,
                          enabled: isEnabled,
                          leading: _getIconForSlug(slug),
                          title: isDesktop ? Text(_allSections[index]) : null,
                          onTap: isEnabled
                              ? () => _onSectionSelected(index)
                              : null,
                        );
                      },
                    ),
                  ),
                  // Content
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
}

class _HelpAndResourcesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.help_outline),
      tooltip: 'Help and Resources',
      onSelected: (value) {
        if (value == 'privacy') {
          context.go('/app/settings/privacy-policy');
        } else if (value == 'contact') {
          context.go('/app/settings/contact-us');
        } else if (value == 'suggest') {
          context.go('/app/settings/suggest-improvements');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'privacy', child: Text('Privacy Policy')),
        const PopupMenuItem(value: 'contact', child: Text('Contact Us')),
        const PopupMenuItem(
          value: 'suggest',
          child: Text('Suggest Improvements'),
        ),
      ],
    );
  }
}
