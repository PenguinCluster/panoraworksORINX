import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/logger.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
    String? emailRedirectTo,
  }) async {
    AppLogger.info('Attempting signup for $email');
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username, // Remove the 'if' and the key-value pair will 
        'full_name': fullName, // still be null if the variables are null.
      }..removeWhere((key, value) => value == null), // Optional: clean up nulls
      emailRedirectTo: emailRedirectTo,
    );
    AppLogger.info('Signup successful for $email');
    return response;
}

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    AppLogger.info('Attempting signin for $email');
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    AppLogger.info('Signin successful for $email');
    return response;
  }

  // Sign in with OAuth
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    AppLogger.info('Attempting OAuth signin with ${provider.name}');
    return await _supabase.auth.signInWithOAuth(
      provider,
      redirectTo: 'https://seftogufmytdplmopzjx.supabase.co/auth/v1/callback',
    );
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    AppLogger.info('Attempting password reset for $email');
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://seftogufmytdplmopzjx.supabase.co/auth/v1/callback',
    );
    AppLogger.info('Password reset email sent to $email');
  }

  // Sign out
  Future<void> signOut() async {
    AppLogger.info('Signing out user');
    await _supabase.auth.signOut();
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get session
  Session? get currentSession => _supabase.auth.currentSession;
}
