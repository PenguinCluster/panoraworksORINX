import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Policy', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Last updated: February 6, 2026', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              
              _section('1. Introduction', 
                'Welcome to ORINX. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you visit our website and tell you about your privacy rights and how the law protects you.'),
              
              _section('2. Data We Collect', 
                'We may collect, use, store and transfer different kinds of personal data about you which we have grouped together follows:\n'
                '• Identity Data: includes first name, last name, username or similar identifier.\n'
                '• Contact Data: includes email address.\n'
                '• Technical Data: includes internet protocol (IP) address, your login data, browser type and version, time zone setting and location, browser plug-in types and versions, operating system and platform, and other technology on the devices you use to access this website.\n'
                '• Usage Data: includes information about how you use our website and services.'),
              
              _section('3. How We Use Your Data', 
                'We will only use your personal data when the law allows us to. Most commonly, we will use your personal data in the following circumstances:\n'
                '• Where we need to perform the contract we are about to enter into or have entered into with you.\n'
                '• Where it is necessary for our legitimate interests (or those of a third party) and your interests and fundamental rights do not override those interests.\n'
                '• Where we need to comply with a legal obligation.'),
              
              _section('4. Third-Party Integrations', 
                'Our Service may contain links to other sites that are not operated by us. If you click a third party link, you will be directed to that third party\'s site. We strongly advise you to review the Privacy Policy of every site you visit. We have no control over and assume no responsibility for the content, privacy policies or practices of any third party sites or services (e.g., Facebook, Discord, TikTok integrations).'),
              
              _section('5. Data Retention', 
                'We will only retain your personal data for as long as reasonably necessary to fulfill the purposes we collected it for, including for the purposes of satisfying any legal, regulatory, tax, accounting or reporting requirements.'),
              
              _section('6. Your Legal Rights', 
                'Under certain circumstances, you have rights under data protection laws in relation to your personal data, including the right to request access, correction, erasure, restriction, transfer, to object to processing, to portability of data and (where the lawful ground of processing is consent) to withdraw consent.'),
              
              _section('7. Contact Us', 
                'If you have any questions about this privacy policy or our privacy practices, please contact us via the "Contact Us" form in the Settings menu.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
