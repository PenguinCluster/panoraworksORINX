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

  /// True when the user has just been redirected back from Flutterwave
  /// (the router reads ?payment=success from the URL and sets this).
  final bool paymentSuccess;

  const SettingsScreen({
    super.key,
    this.initialTab = 'profile',
    this.paymentSuccess = false,
  });

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
        return controller.canAccessBillingTab;
      case 'orders':
        return controller.canAccessOrdersTab;
      default:
        return false;
    }
  }

  String? _disabledTooltip(String slug, TeamContextController controller) {
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
        // Forward paymentSuccess so BillingSection shows the banner and starts
        // polling/realtime immediately when the user lands here post-payment.
        return BillingSection(
          paymentJustCompleted:
              widget.paymentSuccess && currentSlug == 'billing',
        );
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

  bool _isItemVisible(String slug, TeamContextController controller) {
    switch (slug) {
      case 'profile':
      case 'login':
      case 'accessibility':
        return true;
      case 'team':
        return controller.canAccessTeamTab;
      case 'billing':
      case 'orders':
        return controller.canAccessWorkspaceSettings;
      default:
        return false;
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

        // Safety fallback: snap to Profile if current tab is no longer accessible
        final visibleSlugs = _allSlugs
            .where((s) => _isItemVisible(s, controller))
            .toList();
        if (_selectedIndex < _allSlugs.length &&
            !_isItemVisible(_allSlugs[_selectedIndex], controller)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedIndex = 0);
          });
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
          body: isDesktop
              ? Row(
                  children: [
                    SizedBox(
                      width: 240,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _allSlugs.length,
                        itemBuilder: (context, index) {
                          final slug = _allSlugs[index];
                          if (!_isItemVisible(slug, controller)) {
                            return const SizedBox.shrink();
                          }
                          final enabled = _isSectionEnabled(slug);
                          final tooltip = _disabledTooltip(slug, controller);
                          return Tooltip(
                            message: tooltip ?? '',
                            child: ListTile(
                              leading: _getIconForSlug(slug),
                              title: Text(_allSections[index]),
                              selected: _selectedIndex == index,
                              enabled: enabled,
                              onTap: enabled
                                  ? () => _onSectionSelected(index)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: _buildContent(_selectedIndex),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(_selectedIndex),
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
