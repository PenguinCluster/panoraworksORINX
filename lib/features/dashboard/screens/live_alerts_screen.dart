import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/state/team_context_controller.dart';

class LiveAlertsScreen extends StatefulWidget {
  const LiveAlertsScreen({super.key});

  @override
  State<LiveAlertsScreen> createState() => _LiveAlertsScreenState();
}

class _LiveAlertsScreenState extends State<LiveAlertsScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _conditionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamId = TeamContextController.instance.teamId;
    if (teamId == null) return const Center(child: Text('No active workspace'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Alerts',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateRuleDialog,
                icon: const Icon(Icons.add_alert),
                label: const Text('Create Alert Rule'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            'Alert Rules',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase
                .from('alert_rules')
                .stream(primaryKey: ['id'])
                .eq('team_id', teamId), // CHANGED: Filter by team_id
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final rules = snapshot.data ?? [];

              if (rules.isEmpty)
                return const Center(
                  child: Text('No alert rules yet. Create one!'),
                );

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return Card(
                    child: ListTile(
                      title: Text(rule['name']),
                      subtitle: Text('Condition: ${rule['condition']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_circle_outline),
                            onPressed: () => _sendTestAlert(rule),
                            tooltip: 'Send Test Alert',
                          ),
                          Switch(
                            value: rule['is_active'],
                            onChanged: (val) => _toggleRule(rule['id'], val),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Alert Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Rule Name'),
              ),
              TextField(
                controller: _conditionController,
                decoration: const InputDecoration(
                  labelText: 'Condition (e.g. mention of ORINX)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_nameController.text.trim().isEmpty ||
                          _conditionController.text.trim().isEmpty) {
                        ErrorHandler.handle(
                          context,
                          'Missing fields',
                          customMessage: 'Please fill all fields',
                        );
                        return;
                      }
                      setDialogState(() => _isLoading = true);
                      try {
                        await _saveRule();
                        if (mounted) {
                          Navigator.pop(context);
                          ErrorHandler.showSuccess(
                            context,
                            'Alert rule created',
                          );
                        }
                      } catch (e) {
                        if (mounted)
                          ErrorHandler.handle(
                            context,
                            e,
                            customMessage: 'Failed to create rule',
                          );
                      } finally {
                        if (mounted) setDialogState(() => _isLoading = false);
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Rule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRule() async {
    final teamId = TeamContextController.instance.teamId;
    if (teamId == null) return;

    await _supabase.from('alert_rules').insert({
      'team_id': teamId, // CHANGED: Use team_id
      'user_id': _supabase.auth.currentUser!.id,
      'name': _nameController.text.trim(),
      'condition': _conditionController.text.trim(),
    });
    _nameController.clear();
    _conditionController.clear();
  }

  Future<void> _toggleRule(String id, bool val) async {
    try {
      await _supabase
          .from('alert_rules')
          .update({'is_active': val})
          .eq('id', id);
    } catch (e) {
      if (mounted)
        ErrorHandler.handle(context, e, customMessage: 'Failed to toggle rule');
    }
  }

  Future<void> _sendTestAlert(Map<String, dynamic> rule) async {
    final teamId = TeamContextController.instance.teamId;
    if (teamId == null) return;

    try {
      final connections = await _supabase
          .from('connected_accounts')
          .select()
          .eq('provider', 'discord')
          .eq('team_id', teamId) // CHANGED: Filter by team_id
          .maybeSingle();

      if (connections != null &&
          connections['metadata']?['channel_id'] != null) {
        ErrorHandler.showSuccess(
          context,
          'Test alert for "${rule['name']}" sent to Discord channel: ${connections['metadata']['channel_id']}',
        );
      } else {
        ErrorHandler.handle(
          context,
          'Discord not configured',
          customMessage: 'Connect Discord in Settings to send real alerts.',
        );
      }
    } catch (e) {
      if (mounted)
        ErrorHandler.handle(
          context,
          e,
          customMessage: 'Failed to send test alert',
        );
    }
  }
}
