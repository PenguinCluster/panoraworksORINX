import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/error_handler.dart';

class PlansPricingScreen extends StatelessWidget {
  const PlansPricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans and Pricing')),
      body: const PlansPricingContent(),
    );
  }
}

class PlansPricingDialog extends StatelessWidget {
  const PlansPricingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plans and Pricing',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Expanded(child: PlansPricingContent()),
          ],
        ),
      ),
    );
  }
}

class PlansPricingContent extends StatefulWidget {
  const PlansPricingContent({super.key});

  @override
  State<PlansPricingContent> createState() => _PlansPricingContentState();
}

class _PlansPricingContentState extends State<PlansPricingContent> {
  bool _isAnnual = false;
  bool _isLoading = false;

  // =========================
  // Billing popup controllers
  // =========================
  final _billingFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Nigeria');
  final _postalCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  // 1) Show billing form modal
  Future<Map<String, dynamic>?> _showBillingDialog({
    required String defaultName,
  }) async {
    _nameCtrl.text = defaultName.isNotEmpty ? defaultName : _nameCtrl.text;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Billing details'),
        content: Form(
          key: _billingFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _addr1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Address line 1',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _addr2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Address line 2 (optional)',
                  ),
                ),
                TextFormField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _stateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'State (optional)',
                  ),
                ),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: const InputDecoration(labelText: 'Country'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _postalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Postal code (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_billingFormKey.currentState!.validate()) {
                Navigator.pop(ctx, {
                  'full_name': _nameCtrl.text.trim(),
                  'address_line1': _addr1Ctrl.text.trim(),
                  'address_line2': _addr2Ctrl.text.trim(),
                  'city': _cityCtrl.text.trim(),
                  'state': _stateCtrl.text.trim(),
                  'country': _countryCtrl.text.trim(),
                  'postal_code': _postalCtrl.text.trim(),
                });
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // 2) Save billing profile in Supabase
  Future<void> _saveBillingProfile(
    String userId,
    Map<String, dynamic> billing,
  ) async {
    final client = Supabase.instance.client;
    await client.from('billing_profiles').upsert({
      'user_id': userId,
      'full_name': billing['full_name'],
      'address_line1': billing['address_line1'],
      'address_line2': billing['address_line2'],
      'city': billing['city'],
      'state': billing['state'],
      'country': billing['country'],
      'postal_code': billing['postal_code'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // 3) Initiate payment (popup -> save -> invoke -> open link)
  Future<void> _initiatePayment(String planName) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      final session = client.auth.currentSession;

      if (user == null || session == null) {
        throw Exception('User not logged in');
      }

      // Default name: from userMetadata or email prefix
      String defaultName =
          (user.userMetadata?['full_name'] as String?)?.trim() ?? '';
      if (defaultName.isEmpty) {
        defaultName = (user.email ?? '').split('@').first;
      }

      // A) popup billing form
      final billing = await _showBillingDialog(defaultName: defaultName);
      if (billing == null) return; // user cancelled

      // B) save to DB
      await _saveBillingProfile(user.id, billing);

      // C) fetch plan
      final plans = await client.from('plans').select().eq('name', planName);
      if (plans.isEmpty) throw Exception('Plan not found');

      final plan = plans.first;
      final amount = _isAnnual ? plan['price_annual'] : plan['price_monthly'];

      // D) invoke edge function
      final response = await client.functions.invoke(
        'flutterwave-init',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        body: {
          'email': user.email,
          'name': billing['full_name'], // prefill name (if provider shows it)
          'amount': amount,
          'plan_id': plan['id'],
          'user_id': user.id,
          'interval': _isAnnual ? 'yearly' : 'monthly',
          'billing_profile': billing, // attaches to meta / transaction
        },
      );

      debugPrint('flutterwave-init status: ${response.status}');
      debugPrint('flutterwave-init data: ${response.data}');

      final raw = response.data;
      final Map<String, dynamic> resp = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : (raw as Map<String, dynamic>);

      if (response.status != 200) {
        throw Exception(
          resp['error'] ?? resp['message'] ?? 'Payment initialization failed',
        );
      }
      if (resp['status'] != 'success') {
        throw Exception(resp['message'] ?? 'Payment initialization failed');
      }

      final link = resp['data']?['link'];
      if (link == null) throw Exception('Payment link missing from response');

      final uri = Uri.parse(link);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not launch payment link');
    } catch (e) {
      if (mounted)
        ErrorHandler.handle(
          context,
          e,
          customMessage: 'Failed to start payment',
        );
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
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      _PricingCard(
                        title: 'O',
                        price: _isAnnual ? '36' : '5',
                        period: _isAnnual ? '/yr' : '/mo',
                        features: const [
                          'Basic features',
                          '1 user',
                          'Limited support',
                        ],
                        onSelect: () => _initiatePayment('O'),
                      ),
                      _PricingCard(
                        title: 'R',
                        price: _isAnnual ? '120' : '15',
                        period: _isAnnual ? '/yr' : '/mo',
                        features: const [
                          'Advanced features',
                          '5 users',
                          'Priority support',
                        ],
                        onSelect: () => _initiatePayment('R'),
                      ),
                      _PricingCard(
                        title: 'I',
                        price: _isAnnual ? '240' : '25',
                        period: _isAnnual ? '/yr' : '/mo',
                        features: const [
                          'Pro features',
                          'Unlimited users',
                          '24/7 support',
                        ],
                        onSelect: () => _initiatePayment('I'),
                      ),
                      _PricingCard(
                        title: 'N',
                        price: _isAnnual ? '540' : '50',
                        period: _isAnnual ? '/yr' : '/mo',
                        features: const [
                          'Enterprise features',
                          'Custom analytics',
                          'Dedicated manager',
                        ],
                        onSelect: () => _initiatePayment('N'),
                      ),
                      _PricingCard(
                        title: 'X',
                        price: 'Contact Sales',
                        period: '',
                        features: const [
                          'Custom solutions',
                          'Full white-label',
                          'On-premise option',
                        ],
                        isContact: true,
                        onSelect: () {},
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
          Text(
            title,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!isContact) ...[
            Text(
              '\$$price',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(period, style: const TextStyle(color: Colors.grey)),
          ] else
            Text(
              price,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(f, textAlign: TextAlign.center),
            ),
          ),
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
