import 'package:flutter/material.dart';

class OrdersSection extends StatelessWidget {
  const OrdersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orders and invoices', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        // Filters
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Enter invoice',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: 'Any item type',
              items: ['Any item type', 'Subscription', 'One-time']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) {},
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {},
              tooltip: 'Filter by date',
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Transactions
        const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Action')),
            ],
            rows: [
              DataRow(cells: [
                const DataCell(Text('Feb 6, 2026')),
                const DataCell(Text('Subscription')),
                const DataCell(Text('\$0.00')),
                DataCell(IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () {},
                  tooltip: 'Download invoice',
                )),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
