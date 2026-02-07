import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/error_handler.dart';

class PlansPricingScreen extends StatefulWidget {
  const PlansPricingScreen({super.key});

  @override
  State<PlansPricingScreen> createState() => _PlansPricingScreenState();
}

class _PlansPricingScreenState extends State<PlansPricingScreen> {
  bool _isAnnual = false;
  bool _isLoading = false;

  Future<void> _initiatePayment(String planName, String price) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Simple mapping for MVP - in real app, fetch plan ID from DB
      final plans = await Supabase.instance.client.from('plans').select().eq('name', planName);
      if (plans.isEmpty) throw Exception('Plan not found');
      
      final plan = plans.first;
      final amount = _isAnnual ? plan['price_annual'] : plan['price_monthly'];

      final response = await Supabase.instance.client.functions.invoke(
        'flutterwave-init',
        body: {
          'email': user.email,
          'amount': amount,
          'plan_id': plan['id'],
          'user_id': user.id,
          'interval': _isAnnual ? 'yearly' : 'monthly',
        },
      );

      final data = response.data as Map<String, dynamic>?;

if (data == null) {
  throw Exception('Empty response from payment service');
}

final link = data['payment_link'] as String?;
if (link == null || link.isEmpty) {
  // Show the backend error if present
  final backendError = data['error'] ?? data['flutterwave_body'] ?? 'Payment initialization failed';
  throw Exception(backendError.toString());
}

final uri = Uri.parse(link);
if (await canLaunchUrl(uri)) {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
} else {
  throw Exception('Could not launch payment link');
}
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to start payment');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans and Pricing')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
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
                  price: _isAnnual ? '36' : '5',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Basic features', '1 user', 'Limited support'],
                  onSelect: () => _initiatePayment('O', _isAnnual ? '36' : '5'),
                ),
                _PricingCard(
                  title: 'R',
                  price: _isAnnual ? '120' : '15',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Advanced features', '5 users', 'Priority support'],
                  onSelect: () => _initiatePayment('R', _isAnnual ? '120' : '15'),
                ),
                _PricingCard(
                  title: 'I',
                  price: _isAnnual ? '240' : '25',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Pro features', 'Unlimited users', '24/7 support'],
                  onSelect: () => _initiatePayment('I', _isAnnual ? '240' : '25'),
                ),
                _PricingCard(
                  title: 'N',
                  price: _isAnnual ? '540' : '50',
                  period: _isAnnual ? '/yr' : '/mo',
                  features: const ['Enterprise features', 'Custom analytics', 'Dedicated manager'],
                  onSelect: () => _initiatePayment('N', _isAnnual ? '540' : '50'),
                ),
                _PricingCard(
                  title: 'X',
                  price: 'Contact Sales',
                  period: '',
                  features: const ['Custom solutions', 'Full white-label', 'On-premise option'],
                  isContact: true,
                  onSelect: () {}, // Implement contact flow
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
  final VoidCallback onSelect;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.isContact = false,
    required this.onSelect,
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
            onPressed: onSelect,
            child: Text(isContact ? 'Contact Us' : 'Select Plan'),
          ),
        ],
      ),
    );
  }
}
