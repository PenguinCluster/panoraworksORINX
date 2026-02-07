import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/state/profile_manager.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  final _supabase = Supabase.instance.client;
  final _authService = AuthService();
  Map<String, dynamic> _connections = {};
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final responses = await Future.wait<dynamic>([
        _supabase.from('connected_accounts').select('provider, status, metadata'),
        _supabase.from('profiles').select().eq('id', user.id).maybeSingle(),
      ]);

      final connectionsData = responses[0] as List<dynamic>;
      final profileData = responses[1] as Map<String, dynamic>?;

      final connections = {
        for (var item in connectionsData) item['provider'] as String: item
      };

      if (mounted) {
        setState(() {
          _connections = connections;
          _profile = profileData ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.handle(context, e, customMessage: 'Failed to load profile data');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> updates) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('profiles').update(updates).eq('id', user.id);
      
      // Update local state
      setState(() {
        _profile = {..._profile, ...updates};
      });
      
      // Refresh app-wide state
      await ProfileManager.instance.refreshProfile();
      
      if (mounted) ErrorHandler.showSuccess(context, 'Profile updated successfully');
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to update profile');
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _profile['full_name'] ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.trim() != (_profile['full_name'] ?? '')) {
                await _updateProfile({'full_name': controller.text.trim()});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editEmail() async {
    final user = _supabase.auth.currentUser;
    final controller = TextEditingController(text: user?.email ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You will need to verify your new email address.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (controller.text.trim() != (user?.email ?? '')) {
                await _updateEmail(controller.text.trim());
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEmail(String newEmail) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Confirmation email sent to $newEmail');
      }
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to update email');
    }
  }

  Future<void> _connect(String provider) async {
    try {
      OAuthProvider? oauthProvider;
      if (provider == 'facebook') oauthProvider = OAuthProvider.facebook;
      if (provider == 'discord') oauthProvider = OAuthProvider.discord;
      
      if (oauthProvider != null) {
        await _authService.signInWithOAuth(oauthProvider);
      } else if (provider == 'tiktok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TikTok OAuth integration in progress...'))
        );
      }
    } on AuthException catch (e) {
      if (e.message.contains('provider is not enabled') || e.code == 'provider_disabled') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Provider Not Enabled'),
              content: Text(
                'The $provider provider is not enabled in Supabase Auth.\n\n'
                'Please enable it in Supabase Dashboard → Authentication → Providers, then try again.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to connect $provider');
      }
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to connect $provider');
    }
  }

  Future<void> _disconnect(String provider) async {
    try {
      await _supabase
          .from('connected_accounts')
          .delete()
          .eq('provider', provider)
          .eq('user_id', _supabase.auth.currentUser!.id);
      
      await _fetchData();
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to disconnect $provider');
    }
  }

  Future<void> _updateDiscordMetadata(String channelId) async {
    try {
      await _supabase
          .from('connected_accounts')
          .update({'metadata': {'channel_id': channelId}})
          .eq('provider', 'discord')
          .eq('user_id', _supabase.auth.currentUser!.id);
      
      if (mounted) ErrorHandler.showSuccess(context, 'Discord settings updated');
    } catch (e) {
      if (mounted) ErrorHandler.handle(context, e, customMessage: 'Failed to update Discord settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _supabase.auth.currentUser;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        
        // Profile Picture
        Row(
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload your profile photo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () {}, // Stub for now
                  child: const Text('Upload photo'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),

        _buildEditableField(
          context, 
          'User\'s Name', 
          _profile['full_name'] ?? user?.userMetadata?['full_name'] ?? 'Not set',
          _editName,
        ),
        _buildEditableField(
          context, 
          'User\'s Email address', 
          user?.email ?? '',
          _editEmail,
        ),

        const Text('Language', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _profile['language'] ?? 'English',
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ['English', 'Spanish', 'French', 'German']
              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
              .toList(),
          onChanged: (value) {
            if (value != null) _updateProfile({'language': value});
          },
        ),
        const SizedBox(height: 32),

        const Text('Connected social accounts', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        Column(
          children: [
            _SocialConnectTile(
              provider: 'facebook',
              label: 'Facebook',
              icon: Icons.facebook,
              isConnected: _connections.containsKey('facebook'),
              connectedAt: _connections['facebook']?['created_at'],
              onConnect: () => _connect('facebook'),
              onDisconnect: () => _disconnect('facebook'),
            ),
            _SocialConnectTile(
              provider: 'tiktok',
              label: 'TikTok',
              icon: Icons.music_note,
              isConnected: _connections.containsKey('tiktok'),
              connectedAt: _connections['tiktok']?['created_at'],
              onConnect: () => _connect('tiktok'),
              onDisconnect: () => _disconnect('tiktok'),
            ),
            _SocialConnectTile(
              provider: 'discord',
              label: 'Discord',
              icon: Icons.discord,
              isConnected: _connections.containsKey('discord'),
              connectedAt: _connections['discord']?['created_at'],
              onConnect: () => _connect('discord'),
              onDisconnect: () => _disconnect('discord'),
              extraUI: _connections.containsKey('discord') 
                ? _DiscordSettings(
                    initialChannelId: _connections['discord']?['metadata']?['channel_id'] ?? '',
                    onSave: _updateDiscordMetadata,
                  )
                : null,
            ),
            const Divider(height: 32),
            const Text('Coming Soon', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['YouTube', 'X.com', 'Twitch', 'Reddit', 'Telegram', 'WhatsApp'].map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.grey.withOpacity(0.1),
              )).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableField(BuildContext context, String title, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
          const Divider(),
        ],
      ),
    );
  }
}

class _SocialConnectTile extends StatelessWidget {
  final String provider;
  final String label;
  final IconData icon;
  final bool isConnected;
  final String? connectedAt;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final Widget? extraUI;

  const _SocialConnectTile({
    required this.provider,
    required this.label,
    required this.icon,
    required this.isConnected,
    this.connectedAt,
    required this.onConnect,
    required this.onDisconnect,
    this.extraUI,
  });

  Widget _buildStatusIndicator(bool isConnected, String? connectedAt) {
    if (!isConnected) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Connected since ${connectedAt != null ? DateTime.parse(connectedAt).toLocal().toString().split(' ')[0] : 'recently'}',
            style: const TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: isConnected ? Colors.blue : Colors.grey),
          title: Text(label),
          subtitle: _buildStatusIndicator(isConnected, connectedAt),
          trailing: isConnected
              ? OutlinedButton(
                  onPressed: onDisconnect,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Disconnect'),
                )
              : FilledButton.tonal(
                  onPressed: onConnect,
                  child: const Text('Connect'),
                ),
        ),
        if (extraUI != null) Padding(
          padding: const EdgeInsets.only(left: 48.0, bottom: 16.0),
          child: extraUI!,
        ),
      ],
    );
  }
}

class _DiscordSettings extends StatefulWidget {
  final String initialChannelId;
  final Function(String) onSave;

  const _DiscordSettings({required this.initialChannelId, required this.onSave});

  @override
  State<_DiscordSettings> createState() => _DiscordSettingsState();
}

class _DiscordSettingsState extends State<_DiscordSettings> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialChannelId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Destination Channel/Server ID',
              hintText: 'Enter Discord Channel ID',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => widget.onSave(_controller.text),
          icon: const Icon(Icons.save),
          tooltip: 'Save Discord Settings',
        ),
      ],
    );
  }
}
