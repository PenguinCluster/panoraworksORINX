import 'package:flutter/material.dart';

class PlansPricingScreen extends StatefulWidget {
  const PlansPricingScreen({super.key});

  @override
  State<PlansPricingScreen> createState() => _PlansPricingScreenState();
}

class _PlansPricingScreenState extends State<PlansPricingScreen> {
  bool _isAnnual = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans and Pricing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            // Monthly/Annual Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Monthly'),
                Switch(
                  value: _isAnnual,
                  onChanged: (v) => setState(() => _isAnnual = v),
                ),
                const Text('Annual (-20%)'),
              ],
            ),
            const SizedBox(height: 48),

            // Pricing Cards
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _PricingCard(
                  title: 'O',
                  price: _isAnnual ? '3' : '5',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Basic features', '1 user', 'Limited support'],
                ),
                _PricingCard(
                  title: 'R',
                  price: _isAnnual ? '10' : '15',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Advanced features', '5 users', 'Priority support'],
                ),
                _PricingCard(
                  title: 'I',
                  price: _isAnnual ? '20' : '25',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Pro features', 'Unlimited users', '24/7 support'],
                ),
                _PricingCard(
                  title: 'N',
                  price: _isAnnual ? '45' : '50',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Enterprise features', 'Custom analytics', 'Dedicated manager'],
                ),
                const _PricingCard(
                  title: 'X',
                  price: 'Contact Sales',
                  period: '',
                  features: ['Custom solutions', 'Full white-label', 'On-premise option'],
                  isContact: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isContact;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.isContact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (!isContact) ...[
            Text('\$$price', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(period, style: const TextStyle(color: Colors.grey)),
          ] else
            Text(price, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(f, textAlign: TextAlign.center),
              )),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            child: Text(isContact ? 'Contact Us' : 'Select Plan'),
          ),
        ],
      ),
    );
  }
}
