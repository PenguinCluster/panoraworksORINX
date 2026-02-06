import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BillingSection extends StatelessWidget {
  const BillingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Billing', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                    const Text('Current Plan: Free', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    FilledButton(
                      onPressed: () => context.push('/app/settings/pricing'),
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Your next billing date is March 6, 2026'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Payment Method
        const Text('Payment method', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('No payment method on file.'),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () {}, child: const Text('Add payment method')),
        const Divider(height: 48),

        // Billing Details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Billing details', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('Update')),
          ],
        ),
        const Text('John Doe\n123 Tech Lane\nInnovation City, IC 12345'),
      ],
    );
  }
}
