import 'package:supabase_flutter/supabase_flutter.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._();
  final _supabase = Supabase.instance.client;

  PermissionService._();

  // Cache user role to avoid redundant DB calls?
  // For MVP, we'll fetch on demand or rely on ProfileManager if we integrate it there.
  // Ideally, ProfileManager should hold the current role.

  Future<String> _getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'none';

    // Check team_members for role
    // Assuming single team context for MVP or defaulting to first active team
    final res = await _supabase
        .from('team_members')
        .select('role')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

    if (res != null) {
      return res['role'] as String;
    }

    // Fallback: Check if owner of any team (implicit owner role)
    final ownerRes = await _supabase
        .from('teams')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (ownerRes != null) return 'owner';

    return 'none';
  }

  Future<bool> canAccessSettingsSection(String section) async {
    final role = await _getUserRole();

    // Admin Toggle Logic:
    // If we have an "admin toggle" in DB, we'd check it here.
    // For now, based on requirements:
    // Owner: Full access
    // Admin: Most settings except owner creds (Login section?)
    // Manager: Read/write content (not settings), NO access to Account, Security, Profile unless admin toggle.

    // For MVP, let's strictly enforce the basic tiers:

    if (role == 'owner') return true;

    if (role == 'admin') {
      // Admin restricted from:
      // - "Login" (Security) - Arguably they can manage their OWN login, but maybe not team security settings?
      // Requirement says: "Admin = high-level but cannot remove owner or change owner credentials"
      // "Login" tab usually contains *personal* security (change password, MFA).
      // Everyone should access their OWN "Login" section.
      // So Admin probably has access to all UI sections, but specific ACTIONS (like removing owner) are blocked by RLS/Backend.
      return true;
    }

    if (role == 'manager') {
      // Manager:
      // - Cannot access Account Settings (Profile?), Security (Login?), Profile Editing.
      // "Profile" tab = Personal Profile? Everyone needs to edit their OWN name/avatar.
      // Or does "Account Settings" mean Team Settings?
      // Requirement: "Manager = limited, no access to Account Settings, Security, Profile Editing unless admin toggle enabled"

      // Interpretation:
      // - Profile (Personal): ALLOW (Everyone needs this)
      // - Login (Personal Security): ALLOW (Everyone needs this)
      // - Accessibility: ALLOW
      // - Team & People: READ ONLY? Or BLOCK? Usually BLOCK or Read-Only.
      // - Billing: BLOCK
      // - Orders: BLOCK

      switch (section) {
        case 'profile':
        case 'login':
        case 'accessibility':
          return true; // Personal settings
        case 'team':
        case 'billing':
        case 'orders':
          return false; // Team/Admin settings
        default:
          return false;
      }
    }

    return false; // No role / not logged in
  }
}
