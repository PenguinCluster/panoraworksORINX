import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../screens/plans_pricing_screen.dart';

class BillingSection extends StatefulWidget {
  const BillingSection({super.key});

  @override
  State<BillingSection> createState() => _BillingSectionState();
}

class _BillingSectionState extends State<BillingSection> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _plan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscription();
  }

  Future<void> _fetchSubscription() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final subData = await _supabase
          .from('subscriptions')
          .select('*, plans(*)')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _subscription = subData;
          _plan = subData?['plans'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final planName = _plan?['name'] ?? 'Free';
    final endDate = _subscription?['current_period_end'];
    final formattedDate = endDate != null
        ? DateFormat.yMMMMd().format(DateTime.parse(endDate))
        : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),

        // Plan Card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Plan: $planName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const PlansPricingDialog(),
                        );
                      },
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _subscription != null
                      ? 'Your next billing date is $formattedDate'
                      : 'You are currently on the free plan.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Payment Method
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('No payment method on file.'),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
          child: const Text('Add payment method'),
        ),
        const Divider(height: 48),

        // Billing Details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Billing details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(onPressed: () {}, child: const Text('Update')),
          ],
        ),
        const Text('John Doe\n123 Tech Lane\nInnovation City, IC 12345'),
      ],
    );
  }
}
