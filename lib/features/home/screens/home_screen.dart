import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); // Unused
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            _Header(isDesktop: isDesktop),

            // Hero Section
            _HeroSection(isDesktop: isDesktop),

            // Features Section
            _FeaturesSection(isDesktop: isDesktop),

            // Footer
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDesktop;
  const _Header({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 20,
      ),
      child: Row(
        children: [
          // Logo placeholder
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'ORINX',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const Spacer(),
          if (isDesktop) ...[
            TextButton(onPressed: () {}, child: const Text('Features')),
            TextButton(onPressed: () {}, child: const Text('About')),
            TextButton(onPressed: () {}, child: const Text('Contact')),
            const SizedBox(width: 20),
          ],
          FilledButton.tonal(
            onPressed: () => context.push('/login'),
            child: const Text('Log In'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => context.push('/signup'),
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isDesktop;
  const _HeroSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 80,
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            'Accelerate Your Workflow with ORINX',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: isDesktop ? 600 : double.infinity,
            child: Text(
              'The next-generation platform by PANORAWORKS designed to streamline your business operations and enhance team collaboration.',
              textAlign: isDesktop ? TextAlign.left : TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () => context.push('/signup'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                ),
                child: const Text('Get Started for Free', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                ),
                child: const Text('View Demo', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  final bool isDesktop;
  const _FeaturesSection({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 80,
      ),
      child: Column(
        children: [
          Text(
            'Powerful Features',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 48),
          if (isDesktop)
            Row(
              children: const [
                Expanded(child: _FeatureCard(icon: Icons.speed, title: 'High Performance', description: 'Experience lightning fast response times and smooth interactions.')),
                SizedBox(width: 24),
                Expanded(child: _FeatureCard(icon: Icons.security, title: 'Enterprise Security', description: 'Your data is protected with industry-standard encryption.')),
                SizedBox(width: 24),
                Expanded(child: _FeatureCard(icon: Icons.cloud_done, title: 'Cloud Integration', description: 'Seamlessly sync your data across all your devices.')),
              ],
            )
          else
            Column(
              children: const [
                _FeatureCard(icon: Icons.speed, title: 'High Performance', description: 'Experience lightning fast response times and smooth interactions.'),
                SizedBox(height: 24),
                _FeatureCard(icon: Icons.security, title: 'Enterprise Security', description: 'Your data is protected with industry-standard encryption.'),
                SizedBox(height: 24),
                _FeatureCard(icon: Icons.cloud_done, title: 'Cloud Integration', description: 'Seamlessly sync your data across all your devices.'),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 20,
        vertical: 60,
      ),
      child: Column(
        children: [
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORINX', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('A product by PANORAWORKS'),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          IconButton(onPressed: () {}, icon: const Icon(Icons.facebook)),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.camera_alt)),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.alternate_email)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Expanded(child: _FooterColumn(title: 'Product', links: ['Features', 'Pricing', 'API'])),
                const Expanded(child: _FooterColumn(title: 'Company', links: ['About Us', 'Careers', 'Contact'])),
                const Expanded(child: _FooterColumn(title: 'Legal', links: ['Privacy Policy', 'Terms of Service', 'Cookie Policy'])),
              ],
            )
          else
            Column(
              children: [
                Text('ORINX', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const _FooterColumn(title: 'Product', links: ['Features', 'Pricing', 'API']),
                const _FooterColumn(title: 'Company', links: ['About Us', 'Careers', 'Contact']),
                const _FooterColumn(title: 'Legal', links: ['Privacy Policy', 'Terms of Service', 'Cookie Policy']),
              ],
            ),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            '© 2026 PANORAWORKS. All rights reserved.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {},
                child: Text(link, style: Theme.of(context).textTheme.bodyMedium),
              ),
            )),
      ],
    );
  }
}
