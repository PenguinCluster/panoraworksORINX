import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/profile_section.dart';
import '../widgets/login_section.dart';
import '../widgets/accessibility_section.dart';
import '../widgets/team_section.dart';
import '../widgets/billing_section.dart';
import '../widgets/orders_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  final List<String> _sections = [
    'Your profile',
    'Login',
    'Accessibility',
    'Team and people',
    'Billing',
    'Orders and invoices',
  ];

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const ProfileSection();
      case 1:
        return const LoginSection();
      case 2:
        return const AccessibilitySection();
      case 3:
        return const TeamSection();
      case 4:
        return const BillingSection();
      case 5:
        return const OrdersSection();
      default:
        return const ProfileSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/overview'),
        ),
        actions: [
          _HelpAndResourcesButton(),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: isDesktop ? 280 : 80,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: ListView.builder(
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return ListTile(
                  selected: isSelected,
                  leading: _getIcon(index),
                  title: isDesktop ? Text(_sections[index]) : null,
                  onTap: () => setState(() => _selectedIndex = index),
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

  Icon _getIcon(int index) {
    switch (index) {
      case 0:
        return const Icon(Icons.person_outline);
      case 1:
        return const Icon(Icons.lock_outline);
      case 2:
        return const Icon(Icons.accessibility_new);
      case 3:
        return const Icon(Icons.group_outlined);
      case 4:
        return const Icon(Icons.credit_card);
      case 5:
        return const Icon(Icons.receipt_long_outlined);
      default:
        return const Icon(Icons.settings);
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
        const PopupMenuItem(value: 'suggest', child: Text('Suggest Improvements')),
      ],
    );
  }
}
