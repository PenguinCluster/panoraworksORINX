import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../screens/plans_pricing_screen.dart';
import '../../../core/state/team_context_controller.dart';

class BillingSection extends StatefulWidget {
  /// Pass true when the user has just returned from Flutterwave.
  /// SettingsScreen reads ?payment=success from the URL and forwards it here.
  final bool paymentJustCompleted;

  const BillingSection({super.key, this.paymentJustCompleted = false});

  @override
  State<BillingSection> createState() => _BillingSectionState();
}

class _BillingSectionState extends State<BillingSection> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _billingProfile;
  Map<String, dynamic>? _lastTransaction;

  bool _isLoading = true;
  bool _showSuccessBanner = false;

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 10;
  static const Duration _pollInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _setupRealtimeListener();

    if (widget.paymentJustCompleted) {
      _showSuccessBanner = true;
      _startPolling();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ─── Realtime ──────────────────────────────────────────────────────────────
  // Subscribes to any INSERT/UPDATE on subscriptions for this team.
  // When the webhook fires and the RPC upserts the row, Postgres emits the
  // change and Supabase pushes it here within ~500 ms — no manual refresh needed.
  void _setupRealtimeListener() {
    final teamId = TeamContextController.instance.teamId;
    if (teamId == null) return;

    _channel = _supabase
        .channel('billing_section_$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (payload) {
            debugPrint(
              'BillingSection: realtime event=${payload.eventType} on subscriptions',
            );
            if (mounted) _fetchAll();
          },
        )
        .subscribe((status, [err]) {
          debugPrint('BillingSection realtime: $status $err');
        });
  }

  // ─── Polling fallback ──────────────────────────────────────────────────────
  // After a redirect from Flutterwave the webhook may take a few seconds.
  // Poll every 3 s up to 30 s; stop as soon as an active subscription appears.
  void _startPolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      _pollCount++;
      await _fetchAll();
      if (_subscription != null || _pollCount >= _maxPolls) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }

  // ─── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchAll() async {
    try {
      await Future.wait([
        _fetchSubscription(),
        _fetchBillingProfile(),
        _fetchLastTransaction(),
      ]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubscription() async {
    try {
      final teamId = TeamContextController.instance.teamId;
      if (teamId == null) return;

      final subData = await _supabase
          .from('subscriptions')
          .select('*, plans(*)')
          .eq('team_id', teamId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .maybeSingle();

      if (mounted) {
        _subscription = subData;
        _plan = subData?['plans'];
      }
    } catch (e) {
      debugPrint('Error loading subscription: $e');
    }
  }

  Future<void> _fetchBillingProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('billing_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) _billingProfile = data;
    } catch (e) {
      debugPrint('Error loading billing profile: $e');
    }
  }

  Future<void> _fetchLastTransaction() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('transactions')
          .select('metadata')
          .eq('user_id', user.id)
          .eq('status', 'successful')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) _lastTransaction = data;
    } catch (e) {
      debugPrint('Error loading last transaction: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _formatAddress(Map<String, dynamic> p) {
    final parts = <String>[
      (p['full_name'] as String? ?? '').trim(),
      (p['address_line1'] as String? ?? '').trim(),
      if ((p['address_line2'] as String? ?? '').trim().isNotEmpty)
        (p['address_line2'] as String).trim(),
      [
        (p['city'] as String? ?? '').trim(),
        (p['state'] as String? ?? '').trim(),
        (p['postal_code'] as String? ?? '').trim(),
      ].where((s) => s.isNotEmpty).join(', '),
      (p['country'] as String? ?? '').trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.join('\n');
  }

  /// Reads card info from transactions.metadata.card written by the webhook.
  /// Flutterwave card shape: { first_6digits, last_4digits, issuer, type, ... }
  String? _cardSummary() {
    final meta = _lastTransaction?['metadata'] as Map<String, dynamic>?;
    if (meta == null) return null;

    final card = meta['card'] as Map<String, dynamic>?;
    if (card != null) {
      final first6   = card['first_6digits'] as String?;
      final last4    = card['last_4digits'] as String?;
      final cardType = (card['type'] as String? ?? '').toUpperCase();
      final issuer   = (card['issuer'] as String? ?? '');

      if (last4 != null) {
        final pan = first6 != null
            ? '${first6.substring(0, 4)} •••• •••• $last4'
            : '•••• •••• •••• $last4';
        return '$cardType  $pan${issuer.isNotEmpty ? '\n$issuer' : ''}';
      }
    }

    final paymentType = meta['payment_type'] as String?;
    if (paymentType != null && paymentType != 'unknown') {
      return paymentType.toUpperCase().replaceAll('_', ' ');
    }
    return null;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final planName      = _plan?['name'] ?? 'Free';
    final endDate       = _subscription?['current_period_end'];
    final formattedDate = endDate != null
        ? DateFormat.yMMMMd().format(DateTime.parse(endDate))
        : 'N/A';

    final cardSummary       = _cardSummary();
    final hasBillingProfile = _billingProfile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // ── Payment-success banner ──────────────────────────────────────────
        if (_showSuccessBanner) ...[
          _SuccessBanner(
            isWaiting: _subscription == null,
            onDismiss: () => setState(() => _showSuccessBanner = false),
          ),
          const SizedBox(height: 16),
        ],

        // ── Current Plan Card ───────────────────────────────────────────────
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
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const PlansPricingDialog(),
                      ).then((_) {
                        if (mounted) {
                          setState(() => _isLoading = true);
                          _fetchAll();
                        }
                      }),
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

        // ── Payment Method ──────────────────────────────────────────────────
        const Text(
          'Payment method',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (cardSummary != null)
          _PaymentMethodCard(summary: cardSummary)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No payment method on file.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const PlansPricingDialog(),
                ),
                child: const Text('Add payment method'),
              ),
            ],
          ),
        const Divider(height: 48),

        // ── Billing Details ─────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Billing details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PlansPricingDialog(),
              ).then((_) {
                if (mounted) {
                  setState(() => _isLoading = true);
                  _fetchAll();
                }
              }),
              child: const Text('Update'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasBillingProfile)
          Text(
            _formatAddress(_billingProfile!),
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          const Text(
            'No billing details on file.',
            style: TextStyle(color: Colors.grey),
          ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final String summary;
  const _PaymentMethodCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.credit_card, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a spinner while the webhook is still in-flight, then a green check
/// once the Realtime listener or polling detects the new subscription row.
class _SuccessBanner extends StatelessWidget {
  final bool isWaiting;
  final VoidCallback onDismiss;
  const _SuccessBanner({required this.isWaiting, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final bgColor   = isWaiting ? Colors.blue.shade50  : Colors.green.shade50;
    final border    = isWaiting ? Colors.blue.shade200 : Colors.green.shade200;
    final textColor = isWaiting ? Colors.blue.shade800 : Colors.green.shade800;
    final message   = isWaiting
        ? 'Payment received — activating your plan…'
        : 'Your plan has been upgraded successfully!';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (isWaiting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue.shade600,
              ),
            )
          else
            Icon(Icons.check_circle_rounded, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isWaiting)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
