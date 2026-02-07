import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/error_handler.dart';

class KeywordMonitoringScreen extends StatefulWidget {
  const KeywordMonitoringScreen({super.key});

  @override
  State<KeywordMonitoringScreen> createState() => _KeywordMonitoringScreenState();
}

class _KeywordMonitoringScreenState extends State<KeywordMonitoringScreen> {
  final _supabase = Supabase.instance.client;
  final _keywordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keyword Monitoring', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              FilledButton.icon(
                onPressed: _showAddKeywordDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Keyword'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text('Monitored Keywords', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('monitored_keywords').stream(primaryKey: ['id']),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final keywords = snapshot.data ?? [];
              
              if (keywords.isEmpty) return const Text('No keywords monitored yet.');

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: keywords.map((kw) => Chip(
                  label: Text(kw['keyword']),
                  onDeleted: () => _deleteKeyword(kw['id']),
                  deleteIcon: const Icon(Icons.close, size: 18),
                )).toList(),
              );
            },
          ),

          const SizedBox(height: 48),
          
          Text('Simulated Monitoring Results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.rss_feed, color: Colors.orange),
                  title: Text('Found mention of a monitored keyword in result ${index + 1}'),
                  subtitle: const Text('Source: Social Media | 15m ago'),
                  trailing: TextButton(onPressed: () {}, child: const Text('View')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddKeywordDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Monitored Keyword'),
          content: TextField(
            controller: _keywordController,
            decoration: const InputDecoration(labelText: 'Keyword or Tag', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: _isLoading ? null : () async {
                if (_keywordController.text.trim().isEmpty) {
                  ErrorHandler.handle(context, 'Keyword empty', customMessage: 'Please enter a keyword');
                  return;
                }
                setDialogState(() => _isLoading = true);
                try {
                  await _saveKeyword();
                  if (mounted) {
                    Navigator.pop(context);
                    ErrorHandler.showSuccess(context, 'Keyword added');
                  }
                } catch (e) {
                  if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to add keyword');
                } finally {
                  if (mounted) setDialogState(() => _isLoading = false);
                }
              },
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveKeyword() async {
    await _supabase.from('monitored_keywords').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'keyword': _keywordController.text.trim(),
    });
    _keywordController.clear();
  }

  Future<void> _deleteKeyword(String id) async {
    try {
      await _supabase.from('monitored_keywords').delete().eq('id', id);
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to delete keyword');
    }
  }
}
