import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/state/team_context_controller.dart';

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
  int _currentPage = 0;
  static const int _rowsPerPage = 10;
  int _totalCount = 0;

  // Filters
  String _searchQuery = '';
  String _typeFilter = 'Any item type';
  DateTimeRange? _dateRange;

  // Caches
  final Map<String, String> _planNamesCache = {};
  final Map<String, Map<String, dynamic>> _subscriptionCache = {};

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final teamId = TeamContextController.instance.teamId;
      if (teamId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      var query = _supabase
          .from('transactions')
          .select('*')
          .eq('team_id', teamId);

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

      final rangeStart = _currentPage * _rowsPerPage;
      final rangeEnd = rangeStart + _rowsPerPage - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(rangeStart, rangeEnd)
          .count(CountOption.exact);

      final data = (response.data as List).cast<Map<String, dynamic>>();
      final count = response.count;

      // Prefetch plans & subscriptions
      final planIdsToFetch = <String>{};
      final subscriptionIdsToFetch = <String>{};

      for (final tx in data) {
        final meta = tx['metadata'] as Map<String, dynamic>?;
        final planId = meta?['plan_id'] as String? ?? tx['plan_id'] as String?;
        if (planId != null && !_planNamesCache.containsKey(planId)) {
          planIdsToFetch.add(planId);
        }
        final subId = meta?['subscription_id'] as String? ?? tx['subscription_id'] as String?;
        if (subId != null) {
          subscriptionIdsToFetch.add(subId);
        }
      }

      if (planIdsToFetch.isNotEmpty) {
        final plansData = await _supabase
            .from('plans')
            .select('id, name')
            .inFilter('id', planIdsToFetch.toList());
        for (final plan in plansData) {
          _planNamesCache[plan['id'] as String] = plan['name'] as String;
        }
      }

      if (subscriptionIdsToFetch.isNotEmpty) {
        final subsData = await _supabase
            .from('subscriptions')
            .select('id, plan_id, current_period_start, current_period_end, plans(id, name)')
            .inFilter('id', subscriptionIdsToFetch.toList());

        for (final sub in subsData) {
          _subscriptionCache[sub['id'] as String] = sub;
          final plan = sub['plans'] as Map<String, dynamic>?;
          if (plan != null) {
            _planNamesCache[plan['id'] as String] = plan['name'] as String;
          }
        }
      }

      // Client-side type filter
      var filtered = data;
      if (_typeFilter == 'Subscription') {
        filtered = filtered
            .where((t) => (t['metadata']?['interval'] ?? t['interval'] ?? '') != '')
            .toList();
      } else if (_typeFilter == 'One-time') {
        filtered = filtered
            .where((t) => (t['metadata']?['interval'] ?? t['interval'] ?? '') == '')
            .toList();
      }

      if (mounted) {
        setState(() {
          _transactions = filtered;
          _totalCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resolvePlanName(Map<String, dynamic> tx) {
    final meta = tx['metadata'] as Map<String, dynamic>?;
    final planId = meta?['plan_id'] as String? ?? tx['plan_id'] as String?;
    final subId = meta?['subscription_id'] as String? ?? tx['subscription_id'] as String?;

    if (planId != null && _planNamesCache.containsKey(planId)) {
      return _planNamesCache[planId]!;
    }
    if (subId != null && _subscriptionCache.containsKey(subId)) {
      final sub = _subscriptionCache[subId]!;
      final plan = sub['plans'] as Map<String, dynamic>?;
      if (plan != null && plan['name'] != null) return plan['name'] as String;
      final subPlanId = sub['plan_id'] as String?;
      if (subPlanId != null && _planNamesCache.containsKey(subPlanId)) {
        return _planNamesCache[subPlanId]!;
      }
    }
    return 'One-time Payment';
  }

  String _resolveBillingPeriod(Map<String, dynamic> tx) {
    final meta = tx['metadata'] as Map<String, dynamic>?;
    String? start = tx['current_period_start'] as String? ?? meta?['current_period_start'] as String?;
    String? end = tx['current_period_end'] as String? ?? meta?['current_period_end'] as String?;

    if (start != null && end != null) {
      final s = DateTime.parse(start).toLocal();
      final e = DateTime.parse(end).toLocal();
      return '${DateFormat('MMM d').format(s)} - ${DateFormat('MMM d, yyyy').format(e)}';
    }
    return '';
  }

  String _resolveFlutterwaveId(Map<String, dynamic> tx) {
    final meta = tx['metadata'] as Map<String, dynamic>?;
    return tx['flutterwave_tx_id'] as String? ??
        meta?['flutterwave_id'] as String? ??
        'N/A';
  }

  Future<pw.Page> _buildInvoicePage(Map<String, dynamic> tx) async {
    final date = DateTime.parse(tx['created_at']).toLocal();
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final reference = tx['reference'] ?? 'N/A';
    final amount = tx['amount'] ?? 0;
    final currency = tx['currency'] ?? 'USD';
    final status = (tx['status'] ?? 'unknown').toString().toLowerCase();

    final teamContext = TeamContextController.instance;
    final workspaceName = teamContext.workspaceDisplayName;
    final avatarUrl = teamContext.teamProfile['avatarUrl'] as String?;

    final planName = _resolvePlanName(tx);
    final periodText = _resolveBillingPeriod(tx);
    final flutterwaveId = _resolveFlutterwaveId(tx);

    pw.ImageProvider? profileImage;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        profileImage = await networkImage(avatarUrl);
      } catch (e) {
        debugPrint('Error loading avatar: $e');
      }
    }

    // Status color in header - FIXED with curly braces (no more lint warnings)
    PdfColor statusColor = PdfColors.grey;
    if (status == 'successful') {
      statusColor = PdfColors.green;
    } else if (status == 'pending') {
      statusColor = PdfColors.orange;
    } else if (status == 'failed') {
      statusColor = PdfColors.red;
    }

    return pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORINX Invoice', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text(status.toUpperCase(), style: pw.TextStyle(color: statusColor, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                if (profileImage != null)
                  pw.Container(
                    width: 50,
                    height: 50,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      image: pw.DecorationImage(image: profileImage),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Reference: $reference'),
            pw.Text('Transaction ID: $flutterwaveId'),
            pw.Text('Date: $formattedDate'),
            if (periodText.isNotEmpty) pw.Text('Billing Period: $periodText'),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(workspaceName),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subscription - $planName'),
                pw.Text('$currency $amount'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text('$currency $amount', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Text('What this contains', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('This document summarizes your ORINX subscription transaction and can be used for record keeping.', style: const pw.TextStyle(fontSize: 10)),
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by ORINX', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadInvoice(Map<String, dynamic> tx) async {
    final pdf = pw.Document();
    pdf.addPage(await _buildInvoicePage(tx));
    final reference = tx['reference'] ?? 'N/A';
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_$reference.pdf',
    );
  }

  Future<void> _downloadSelectedInvoices() async {
    final pdf = pw.Document();
    final selectedTx = _transactions.where((t) => _selectedReferences.contains(t['reference'])).toList();
    for (var tx in selectedTx) {
      pdf.addPage(await _buildInvoicePage(tx));
    }
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoices_selected_$timestamp.pdf',
    );
  }

  void _nextPage() {
    if ((_currentPage + 1) * _rowsPerPage < _totalCount) {
      setState(() {
        _currentPage++;
        _selectedReferences.clear();
      });
      _fetchTransactions();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _selectedReferences.clear();
      });
      _fetchTransactions();
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

  void _selectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedReferences = _transactions.map((t) => t['reference'] as String).toSet();
      } else {
        _selectedReferences.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orders and invoices', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        Row(
          children: [
            if (_selectedReferences.isNotEmpty) ...[
              Text('${_selectedReferences.length} selected'),
              const SizedBox(width: 16),
              TextButton.icon(icon: const Icon(Icons.download), label: const Text('Download Selected'), onPressed: _downloadSelectedInvoices),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(hintText: 'Search reference or status', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _fetchTransactions();
                },
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _typeFilter,
              items: ['Any item type', 'Subscription', 'One-time'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _typeFilter = v);
                  _fetchTransactions();
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.calendar_today, color: _dateRange != null ? Theme.of(context).primaryColor : null),
              onPressed: _selectDateRange,
              tooltip: _dateRange != null ? '${DateFormat.MMMd().format(_dateRange!.start)} - ${DateFormat.MMMd().format(_dateRange!.end)}' : 'Filter by date',
            ),
            if (_dateRange != null)
              IconButton(icon: const Icon(Icons.close), onPressed: () { setState(() => _dateRange = null); _fetchTransactions(); }),
          ],
        ),
        const SizedBox(height: 32),

        const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No transactions found')))
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            onSelectAll: _selectAll,
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Reference')),
                              DataColumn(label: Text('Plan & Period')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: _transactions.map((tx) {
                              final date = DateTime.parse(tx['created_at']).toLocal();
                              final planName = _resolvePlanName(tx);
                              final periodText = _resolveBillingPeriod(tx);
                              final flutterwaveId = _resolveFlutterwaveId(tx);
                              final currency = tx['currency'] ?? 'USD';
                              final amount = tx['amount'] ?? 0;
                              final status = tx['status'] ?? 'pending';
                              final reference = tx['reference'] ?? '';

                              return DataRow(
                                selected: _selectedReferences.contains(reference),
                                onSelectChanged: (v) => _toggleSelection(reference),
                                cells: [
                                  DataCell(Text(DateFormat('yyyy-MM-dd').format(date))),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(reference, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (flutterwaveId != 'N/A')
                                          Text('FLW: $flutterwaveId', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    RichText(
                                      text: TextSpan(
                                        style: DefaultTextStyle.of(context).style,
                                        children: [
                                          TextSpan(text: planName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          if (periodText.isNotEmpty) TextSpan(text: '\n$periodText', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'successful' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(status.toUpperCase(), style: TextStyle(color: status == 'successful' ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  DataCell(Text('$currency $amount')),
                                  DataCell(IconButton(icon: const Icon(Icons.download), onPressed: () => _downloadInvoice(tx), tooltip: 'Download invoice')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Page ${_currentPage + 1} of ${(_totalCount / _rowsPerPage).ceil()}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 16),
                          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 0 ? _prevPage : null),
                          IconButton(icon: const Icon(Icons.chevron_right), onPressed: ((_currentPage + 1) * _rowsPerPage < _totalCount) ? _nextPage : null),
                        ],
                      ),
                    ],
                  ),
      ],
    );
  }
}