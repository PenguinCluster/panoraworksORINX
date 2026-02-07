import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/error_handler.dart';

class ContentHubScreen extends StatefulWidget {
  const ContentHubScreen({super.key});

  @override
  State<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends State<ContentHubScreen> {
  final _supabase = Supabase.instance.client;
  final _contentController = TextEditingController();
  List<String> _selectedPlatforms = [];
  DateTime? _scheduledAt;
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
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
              Text('Content Hub', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              FilledButton.icon(
                onPressed: _showCreatePostDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Post'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Text('Posts', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _supabase.from('posts').stream(primaryKey: ['id']).order('created_at'),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading posts: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final posts = snapshot.data ?? [];
              if (posts.isEmpty) return const Center(child: Text('No posts yet. Create your first post!'));
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(post['content'] ?? 'No content'),
                      subtitle: Text('Status: ${post['status']} | Platforms: ${(post['platforms'] as List).join(', ')}'),
                      trailing: post['status'] == 'scheduled' ? const Icon(Icons.schedule, color: Colors.blue) : null,
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

  void _showCreatePostDialog() async {
    try {
      final connections = await _supabase.from('connected_accounts').select('provider');
      final enabledPlatforms = connections.map((c) => c['provider'] as String).toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create New Post'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'What\'s on your mind?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Platforms:'),
                  Wrap(
                    spacing: 8,
                    children: ['facebook', 'tiktok', 'discord'].map((p) {
                      final isEnabled = enabledPlatforms.contains(p);
                      return FilterChip(
                        label: Text(p),
                        selected: _selectedPlatforms.contains(p),
                        onSelected: isEnabled ? (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedPlatforms.add(p);
                            } else {
                              _selectedPlatforms.remove(p);
                            }
                          });
                        } : null,
                      );
                    }).toList(),
                  ),
                  if (enabledPlatforms.isEmpty) 
                    const Text('Connect accounts in Settings to enable platforms.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(_scheduledAt == null ? 'Schedule Post' : 'Scheduled: ${_scheduledAt.toString()}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setDialogState(() => _scheduledAt = date);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: _isLoading ? null : () async {
                  if (_contentController.text.trim().isEmpty) {
                    ErrorHandler.handle(context, 'Please enter content', customMessage: 'Post content cannot be empty');
                    return;
                  }
                  if (_selectedPlatforms.isEmpty) {
                    ErrorHandler.handle(context, 'No platforms selected', customMessage: 'Please select at least one platform');
                    return;
                  }
                  
                  setDialogState(() => _isLoading = true);
                  try {
                    await _savePost();
                    if (mounted) {
                      Navigator.pop(context);
                      ErrorHandler.showSuccess(context, 'Post saved successfully');
                    }
                  } catch (e) {
                    if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to save post');
                  } finally {
                    if (mounted) setDialogState(() => _isLoading = false);
                  }
                },
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Post'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to load connected accounts');
    }
  }

  Future<void> _savePost() async {
    await _supabase.from('posts').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'content': _contentController.text.trim(),
      'platforms': _selectedPlatforms,
      'status': _scheduledAt == null ? 'draft' : 'scheduled',
      'scheduled_at': _scheduledAt?.toIso8601String(),
    });
    _contentController.clear();
    _selectedPlatforms = [];
    _scheduledAt = null;
  }
}
