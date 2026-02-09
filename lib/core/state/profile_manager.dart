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

class ProfileManager {
  static final ProfileManager _instance = ProfileManager._internal();
  static ProfileManager get instance => _instance;

  final ValueNotifier<UserProfile?> profileNotifier = ValueNotifier(null);
  final _supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  ProfileManager._internal() {
    _init();
  }

  void _init() {
    AppLogger.info('Initializing ProfileManager');

    // Initial load: Only if user is logged in AND session is established.
    // The synchronous check _supabase.auth.currentUser might return a user
    // even if the session is stale or not fully hydrated for realtime.
    // Ideally we wait for the first auth state event.

    final currentSession = _supabase.auth.currentSession;
    if (currentSession != null) {
      _loadProfile(currentSession.user.id, currentSession.user.email ?? '');
      _subscribeToProfile(currentSession.user.id);
    }

    // Listen for auth changes
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      AppLogger.info('Auth state change: $event');

      if ((event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession) &&
          session != null) {
        // Ensure we don't double subscribe if ID hasn't changed, but refresh token might need resub?
        // Supabase Flutter SDK handles channel rejoin on token refresh usually,
        // but explicit resubscription is safer if channel died.
        _loadProfile(session.user.id, session.user.email ?? '');
        _subscribeToProfile(session.user.id);
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
    }
  }

  Future<void> _loadProfile(String userId, String email) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
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
    // Avoid creating duplicate subscriptions for the same user
    if (_profileSubscription != null) {
      // We could check if it's the same stream, but it's simpler to cancel and recreate
      // to ensure the auth token used is fresh (from the new session)
      _profileSubscription!.cancel();
    }

    AppLogger.info('Subscribing to profile updates for $userId');
    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
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
                // Should normally not happen if loaded first, but handle safety
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

  void _clearProfile() {
    profileNotifier.value = null;
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    profileNotifier.dispose();
  }
}
