import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/services/permission_service.dart';
import '../widgets/profile_section.dart';
import '../widgets/login_section.dart';
import '../widgets/accessibility_section.dart';
import '../widgets/team_section.dart';
import '../widgets/billing_section.dart';
import '../widgets/orders_section.dart';

class SettingsScreen extends StatefulWidget {
  final String initialTab;
  const SettingsScreen({super.key, this.initialTab = 'profile'});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _selectedIndex;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;
  String _userRole = 'none';

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

  // Dynamically filtered lists based on permissions
  List<String> _visibleSections = [];
  List<String> _visibleSlugs = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // 1. Fetch Role
    final user = _supabase.auth.currentUser;
    if (user != null) {
      // Logic duplicated from PermissionService for local state,
      // or we could expose getRole from service.
      // Let's rely on a quick check here to filter UI.
      final memberRes = await _supabase
          .from('team_members')
          .select('role')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (memberRes != null) {
        _userRole = memberRes['role'];
      } else {
        // Owner check
        final teamRes = await _supabase
            .from('teams')
            .select('id')
            .eq('owner_id', user.id)
            .maybeSingle();
        if (teamRes != null) _userRole = 'owner';
      }
    }

    // 2. Filter Sections
    _visibleSections.clear();
    _visibleSlugs.clear();

    for (int i = 0; i < _allSlugs.length; i++) {
      final slug = _allSlugs[i];
      // Managers blocked from Team, Billing, Orders
      // Unless we implement fine-grained "admin toggle" later.
      if (_userRole == 'manager' &&
          (slug == 'team' || slug == 'billing' || slug == 'orders')) {
        continue;
      }
      _visibleSections.add(_allSections[i]);
      _visibleSlugs.add(slug);
    }

    // 3. Set Initial Tab
    if (mounted) {
      setState(() {
        _isLoading = false;
        _updateIndexFromTab(widget.initialTab);
      });
    }
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _updateIndexFromTab(widget.initialTab);
    }
  }

  void _updateIndexFromTab(String tab) {
    // If tab is not visible/allowed, default to profile
    if (!_visibleSlugs.contains(tab)) {
      if (_visibleSlugs.isNotEmpty) {
        _selectedIndex = 0;
        // Optionally redirect URL to valid slug?
      } else {
        _selectedIndex = 0;
      }
      return;
    }

    final index = _visibleSlugs.indexOf(tab);
    setState(() {
      _selectedIndex = index != -1 ? index : 0;
    });
  }

  void _onSectionSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go('/app/settings/${_visibleSlugs[index]}');
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_visibleSlugs.isEmpty) return const SizedBox.shrink();

    final currentSlug = _visibleSlugs[_selectedIndex];

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

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: Row(
        children: [
          // Sidebar
          Container(
            width: isDesktop ? 280 : 80,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: ListView.builder(
              itemCount: _visibleSections.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                final slug = _visibleSlugs[index];
                return ListTile(
                  selected: isSelected,
                  leading: _getIconForSlug(slug),
                  title: isDesktop ? Text(_visibleSections[index]) : null,
                  onTap: () => _onSectionSelected(index),
                );
              },
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
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
