import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        if (username != null) 'username': username,
        if (fullName != null) 'full_name': fullName,
      },
    );
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with OAuth
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    return await _supabase.auth.signInWithOAuth(
      provider,
      redirectTo: 'https://seftogufmytdplmopzjx.supabase.co/auth/v1/callback',
    );
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://seftogufmytdplmopzjx.supabase.co/auth/v1/callback',
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get session
  Session? get currentSession => _supabase.auth.currentSession;
}
