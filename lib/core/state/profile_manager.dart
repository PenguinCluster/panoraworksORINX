import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String language;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.language,
  });

  String get initials {
    if (displayName.isEmpty) return 'U';
    return displayName[0].toUpperCase();
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    String? language,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      language: language ?? this.language,
    );
  }
}

class TeamProfile {
  final String teamId;
  final String workspaceName;
  final String avatarUrl;

  TeamProfile({
    required this.teamId,
    required this.workspaceName,
    required this.avatarUrl,
  });

  String get initials {
    if (workspaceName.isEmpty) return 'W';
    return workspaceName[0].toUpperCase();
  }
}

class ProfileManager {
  static final ProfileManager _instance = ProfileManager._internal();
  static ProfileManager get instance => _instance;

  final ValueNotifier<UserProfile?> profileNotifier = ValueNotifier(null);
  final ValueNotifier<TeamProfile?> workspaceNotifier = ValueNotifier(null);
  final ValueNotifier<String?> userRoleNotifier = ValueNotifier(null);

  final _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _workspaceSubscription;

  ProfileManager._internal() {
    _init();
  }

  void _init() {
    AppLogger.info('Initializing ProfileManager');

    final currentSession = _supabase.auth.currentSession;
    if (currentSession != null) {
      _loadProfile(currentSession.user.id, currentSession.user.email ?? '');
      _subscribeToProfile(currentSession.user.id);
      _loadWorkspace(currentSession.user.id);
    }

    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      AppLogger.info('Auth state change: $event');

      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession) &&
          session != null) {
        _loadProfile(session.user.id, session.user.email ?? '');
        _subscribeToProfile(session.user.id);
        _loadWorkspace(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _clearProfile();
      } else if (event == AuthChangeEvent.userUpdated && session != null) {
        if (profileNotifier.value != null &&
            session.user.email != profileNotifier.value!.email) {
          profileNotifier.value = profileNotifier.value!.copyWith(
            email: session.user.email,
          );
        }
      }
    });
  }

  Future<void> refreshProfile() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      await _loadProfile(currentUser.id, currentUser.email ?? '');
      await _loadWorkspace(currentUser.id);
    }
  }

  Future<void> _loadProfile(String userId, String email) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        profileNotifier.value = UserProfile(
          id: userId,
          email: email,
          displayName:
              data['full_name'] ?? data['username'] ?? email.split('@').first,
          avatarUrl: data['avatar_url'] ?? '',
          language: data['language'] ?? 'English',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to load profile', e);
    }
  }

  void _subscribeToProfile(String userId) {
    if (_profileSubscription != null) {
      _profileSubscription!.cancel();
    }

    AppLogger.info('Subscribing to profile updates for $userId');
    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .limit(1)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (data.isNotEmpty) {
              final profile = data.first;
              AppLogger.info('Realtime profile update received');

              if (profileNotifier.value != null) {
                profileNotifier.value = profileNotifier.value!.copyWith(
                  displayName:
                      profile['full_name'] ?? profile['username'] ?? '',
                  avatarUrl: profile['avatar_url'] ?? '',
                  language: profile['language'] ?? 'English',
                );
              } else {
                final email = _supabase.auth.currentUser?.email ?? '';
                profileNotifier.value = UserProfile(
                  id: userId,
                  email: email,
                  displayName:
                      profile['full_name'] ??
                      profile['username'] ??
                      email.split('@').first,
                  avatarUrl: profile['avatar_url'] ?? '',
                  language: profile['language'] ?? 'English',
                );
              }
            }
          },
          onError: (e) {
            AppLogger.error('Profile subscription error', e);
          },
        );
  }

  Future<void> _loadWorkspace(String userId) async {
    try {
      // 1. Get first active team membership
      final memberRes = await _supabase
          .from('team_members')
          .select('team_id, role')
          .eq('user_id', userId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (memberRes != null) {
        final teamId = memberRes['team_id'] as String;
        final role = memberRes['role'] as String;

        userRoleNotifier.value = role;

        // 2. Get team_profile
        final teamProfileRes = await _supabase
            .from('team_profiles')
            .select()
            .eq('team_id', teamId)
            .maybeSingle();

        if (teamProfileRes != null) {
          workspaceNotifier.value = TeamProfile(
            teamId: teamId,
            workspaceName: teamProfileRes['workspace_name'] ?? 'Workspace',
            avatarUrl: teamProfileRes['avatar_url'] ?? '',
          );

          _subscribeToWorkspace(teamId);
        } else {
          // Fallback: If no team_profile exists (e.g. legacy team), try to fetch from teams table
          final teamRes = await _supabase
              .from('teams')
              .select('name')
              .eq('id', teamId)
              .maybeSingle();

          if (teamRes != null) {
            workspaceNotifier.value = TeamProfile(
              teamId: teamId,
              workspaceName: teamRes['name'] ?? 'Workspace',
              avatarUrl: '',
            );
          }
        }
      } else {
        // Handle case where user has no team (should ideally not happen in this flow if invited/created)
        workspaceNotifier.value = null;
        userRoleNotifier.value = null;
      }
    } catch (e) {
      AppLogger.error('Failed to load workspace', e);
    }
  }

  void _subscribeToWorkspace(String teamId) {
    if (_workspaceSubscription != null) {
      _workspaceSubscription!.cancel();
    }

    AppLogger.info('Subscribing to workspace updates for $teamId');
    _workspaceSubscription = _supabase
        .from('team_profiles')
        .stream(primaryKey: ['team_id'])
        .eq('team_id', teamId)
        .limit(1)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (data.isNotEmpty) {
              final profile = data.first;
              AppLogger.info('Realtime workspace update received');

              workspaceNotifier.value = TeamProfile(
                teamId: teamId,
                workspaceName: profile['workspace_name'] ?? 'Workspace',
                avatarUrl: profile['avatar_url'] ?? '',
              );
            }
          },
          onError: (e) {
            AppLogger.error('Workspace subscription error', e);
          },
        );
  }

  void _clearProfile() {
    profileNotifier.value = null;
    workspaceNotifier.value = null;
    userRoleNotifier.value = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
    _workspaceSubscription?.cancel();
    _workspaceSubscription = null;
  }

  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    _workspaceSubscription?.cancel();
    profileNotifier.dispose();
    workspaceNotifier.dispose();
    userRoleNotifier.dispose();
  }
}
