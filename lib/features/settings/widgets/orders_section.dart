import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrdersSection extends StatefulWidget {
  const OrdersSection({super.key});

  @override
  State<OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<OrdersSection> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  Set<String> _selectedReferences = {};
  bool _isLoading = true;

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'Any item type';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      var query = _supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id);

      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'reference.ilike.%$_searchQuery%,status.ilike.%$_searchQuery%',
        );
      }

      if (_dateRange != null) {
        query = query
            .gte('created_at', _dateRange!.start.toIso8601String())
            .lte('created_at', _dateRange!.end.toIso8601String());
      }

      final data = await query.order('created_at', ascending: false);

      // Client-side filtering for type if needed (robustness)
      var filtered = List<Map<String, dynamic>>.from(data);
      if (_typeFilter == 'Subscription') {
        filtered = filtered
            .where((t) => (t['metadata']?['interval'] ?? '') != '')
            .toList();
      } else if (_typeFilter == 'One-time') {
        filtered = filtered
            .where((t) => (t['metadata']?['interval'] ?? '') == '')
            .toList();
      }

      if (mounted) {
        setState(() {
          _transactions = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchTransactions();
    }
  }

  void _toggleSelection(String reference) {
    setState(() {
      if (_selectedReferences.contains(reference)) {
        _selectedReferences.remove(reference);
      } else {
        _selectedReferences.add(reference);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedReferences.length == _transactions.length) {
        _selectedReferences.clear();
      } else {
        _selectedReferences = _transactions
            .map((t) => t['reference'] as String)
            .toSet();
      }
    });
  }

  Future<String> _getPlanName(String? planId) async {
    if (planId == null) return 'Unknown Plan';
    try {
      final data = await _supabase
          .from('plans')
          .select('name')
          .eq('id', planId)
          .maybeSingle();
      return data?['name'] as String? ?? 'Unknown Plan';
    } catch (e) {
      return 'Unknown Plan';
    }
  }

  Future<pw.Page> _buildInvoicePage(
    Map<String, dynamic> tx,
    pw.Document pdf,
  ) async {
    final date = DateTime.parse(tx['created_at']).toLocal();
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final reference = tx['reference'] ?? 'N/A';
    final amount = tx['amount'] ?? 0;
    final currency = tx['currency'] ?? 'USD';
    final status = tx['status'] ?? 'unknown';

    // Fetch User Details
    final user = _supabase.auth.currentUser;
    final userEmail = user?.email ?? 'N/A';
    // Ideally fetch name from profiles/billing_profiles table if needed
    // For now, using email as primary identifier as requested

    // Fetch Plan Name
    final meta = tx['metadata'] as Map<String, dynamic>?;
    final planId = meta?['plan_id'];
    final planName = await _getPlanName(planId);

    return pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                'ORINX Invoice',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Reference: $reference'),
            pw.Text('Date: $formattedDate'),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text(
              'Bill To:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(userEmail),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Description',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Amount',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subscription - Plan $planName'),
                pw.Text('$currency $amount'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '$currency $amount',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Status: ${status.toUpperCase()}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'What this contains',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'This document summarizes your ORINX subscription transaction and can be used for record keeping.',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by ORINX',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadInvoice(Map<String, dynamic> tx) async {
    final pdf = pw.Document();
    pdf.addPage(await _buildInvoicePage(tx, pdf));
    final reference = tx['reference'] ?? 'N/A';
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_$reference.pdf',
    );
  }

  Future<void> _downloadSelectedInvoices() async {
    final pdf = pw.Document();

    final selectedTx = _transactions
        .where((t) => _selectedReferences.contains(t['reference']))
        .toList();

    for (var tx in selectedTx) {
      pdf.addPage(await _buildInvoicePage(tx, pdf));
    }

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoices_selected_$timestamp.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orders and invoices',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),

        // Filters
        Row(
          children: [
            if (_transactions.isNotEmpty)
              Checkbox(
                value:
                    _selectedReferences.length == _transactions.length &&
                    _transactions.isNotEmpty,
                onChanged: (v) => _selectAll(),
                tristate:
                    _selectedReferences.isNotEmpty &&
                    _selectedReferences.length != _transactions.length,
              ),
            if (_selectedReferences.isNotEmpty) ...[
              Text('${_selectedReferences.length} selected'),
              const SizedBox(width: 16),
              TextButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download Selected'),
                onPressed: _downloadSelectedInvoices,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Search reference or status',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _fetchTransactions(); // Debounce in real app
                },
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _typeFilter,
              items: [
                'Any item type',
                'Subscription',
                'One-time',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _typeFilter = v);
                  _fetchTransactions();
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                Icons.calendar_today,
                color: _dateRange != null
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              onPressed: _selectDateRange,
              tooltip: _dateRange != null
                  ? '${DateFormat.MMMd().format(_dateRange!.start)} - ${DateFormat.MMMd().format(_dateRange!.end)}'
                  : 'Filter by date',
            ),
            if (_dateRange != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _dateRange = null);
                  _fetchTransactions();
                },
              ),
          ],
        ),
        const SizedBox(height: 32),

        // Transactions
        const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No transactions found'),
                ),
              )
            : SizedBox(
                width: double.infinity,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Reference')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _transactions.map((tx) {
                    final date = DateTime.parse(tx['created_at']).toLocal();
                    final meta = tx['metadata'] as Map<String, dynamic>?;
                    final type = (meta?['interval'] != null)
                        ? 'Subscription'
                        : 'One-time';
                    final currency = tx['currency'] ?? 'USD';
                    final amount = tx['amount'] ?? 0;
                    final status = tx['status'] ?? 'pending';
                    final reference = tx['reference'] ?? '';

                    return DataRow(
                      selected: _selectedReferences.contains(reference),
                      onSelectChanged: (v) => _toggleSelection(reference),
                      cells: [
                        DataCell(
                          Checkbox(
                            value: _selectedReferences.contains(reference),
                            onChanged: (v) => _toggleSelection(reference),
                          ),
                        ),
                        DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                        DataCell(Text(reference)),
                        DataCell(Text(type)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'successful'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: status == 'successful'
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('$currency $amount')),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadInvoice(tx),
                            tooltip: 'Download invoice',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }
}
