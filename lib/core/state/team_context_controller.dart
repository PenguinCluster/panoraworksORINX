import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class TeamContextController extends ChangeNotifier {
  static final TeamContextController _instance =
      TeamContextController._internal();
  static TeamContextController get instance => _instance;

  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _hasTeam = false;
  String? _teamId;
  String? _role;
  String? _status;

  String _workspaceDisplayName = 'My Workspace';
  String? _workspaceAvatarUrl;
  String? _brandName;
  String? _brandColor;
  Map<String, dynamic> _workspaceSettings = {};

  String? _error;

  // ─── Public getters ───────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get hasTeam => _hasTeam;
  String? get teamId => _teamId;
  String? get role => _role;
  String? get status => _status;

  String get workspaceDisplayName => _workspaceDisplayName;
  String? get workspaceAvatarUrl => _workspaceAvatarUrl;
  String? get brandName => _brandName;
  String? get brandColor => _brandColor;
  Map<String, dynamic> get workspaceSettings => _workspaceSettings;
  String? get error => _error;

  Map<String, dynamic> get teamProfile => {'avatarUrl': _workspaceAvatarUrl};

  // ─── Role checks ──────────────────────────────────────────────────────────

  bool get isOwner => _role == 'owner';
  bool get isAdmin => _role == 'admin';
  bool get isManager => _role == 'manager';
  bool get isMember => _role == 'member';
  bool get isMemberLike => isOwner || isAdmin || isManager || isMember;

  // ─── Permission matrix ────────────────────────────────────────────────────
  //
  // Role hierarchy:   owner > admin > manager > member
  //
  // ┌─────────────────────────────────┬───────┬───────┬─────────┬────────┐
  // │ Permission                      │ owner │ admin │ manager │ member │
  // ├─────────────────────────────────┼───────┼───────┼─────────┼────────┤
  // │ canAccessSettings               │   ✓   │   ✓   │    ✓    │   ✓    │
  // │ canAccessProfileTab             │   ✓   │   ✓   │    ✓    │   ✓    │
  // │ canAccessLoginTab               │   ✓   │   ✓   │    ✓    │   ✓    │
  // │ canAccessAccessibilityTab       │   ✓   │   ✓   │    ✓    │   ✓    │
  // │ canAccessWorkspaceSettings      │   ✓   │   ✓   │    ✗    │   ✗    │
  // │ canAccessTeamTab                │   ✓   │   ✓   │    ✗    │   ✗    │
  // │ canManageTeamMembers (invite)   │   ✓   │   ✓   │    ✗    │   ✗    │
  // │ canDeleteTeamMembers            │   ✓   │   ✗   │    ✗    │   ✗    │ ← NEW
  // │ canEditWorkspaceIdentity        │   ✓   │   ✗   │    ✗    │   ✗    │
  // │ canViewConnectedAccounts        │   ✓   │   ✗   │    ✗    │   ✗    │
  // │ canAccessBillingTab             │   ✓   │   ✗   │    ✗    │   ✗    │ ← FIXED
  // │ canAccessOrdersTab              │   ✓   │   ✗   │    ✗    │   ✗    │ ← FIXED
  // │ canViewBilling                  │   ✓   │   ✗   │    ✗    │   ✗    │ ← FIXED
  // └─────────────────────────────────┴───────┴───────┴─────────┴────────┘

  // Personal settings — every authenticated user.
  bool get canAccessSettings => true;
  bool get canAccessProfileTab => true;
  bool get canAccessLoginTab => true;
  bool get canAccessAccessibilityTab => true;

  // Workspace-level settings — owner + admin.
  bool get canAccessWorkspaceSettings => isOwner || isAdmin;
  bool get canAccessTeamTab => isOwner || isAdmin;

  // Invite + view team members — owner + admin.
  // Admins are trusted collaborators who can grow the team, but they
  // cannot remove members (see canDeleteTeamMembers below).
  bool get canManageTeamMembers => isOwner || isAdmin;

  // ── canDeleteTeamMembers — OWNER ONLY ──────────────────────────────────────
  // NEW: Separated from canManageTeamMembers to honour the RBAC requirement.
  //
  // Why owner-only?
  //   • Removing a member is a destructive, irreversible workspace action.
  //   • An admin removing another admin (or the owner's other accounts) could
  //     lock the owner out of their own team's configuration.
  //   • Admins retain full invite capability via canManageTeamMembers.
  bool get canDeleteTeamMembers => isOwner;

  // Workspace identity (display name, logo, brand colour) — owner only.
  bool get canEditWorkspaceIdentity => isOwner;

  // Connected social / API accounts — owner only.
  bool get canViewConnectedAccounts => isOwner;

  // ── canAccessBillingTab / canAccessOrdersTab / canViewBilling ─────────────
  // CHANGED from `isOwner || isAdmin` → `isOwner`.
  //
  // Why owner-only?
  //   • Billing involves stored payment methods, subscription tiers, and
  //     invoice history — financially sensitive owner-exclusive data.
  //   • Admins are team-management collaborators, not billing principals.
  //   • The billing tab is visually locked (lock icon + tooltip) for admins
  //     rather than hidden, so they understand the restriction.
  bool get canAccessBillingTab => isOwner;
  bool get canAccessOrdersTab => isOwner;
  bool get canViewBilling => isOwner;

  TeamContextController._internal();

  // ─── Core load ────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    await _fetchAndApply();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async => load();

  // ─── Retry-with-backoff ───────────────────────────────────────────────────
  //
  // Used by OverviewScreen after a fresh standalone signup.
  // Bridges the window between email confirmation and Postgres trigger
  // propagation through PostgREST's schema cache.

  Future<void> loadWithRetry({
    int maxAttempts = 4,
    Duration initialDelay = const Duration(milliseconds: 600),
  }) async {
    Duration delay = initialDelay;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _fetchAndApply();
      _isLoading = false;
      notifyListeners();

      if (_hasTeam) {
        AppLogger.info(
          'TeamContext: resolved on attempt $attempt. '
          'role=$_role teamId=$_teamId',
        );
        return;
      }

      if (attempt < maxAttempts) {
        AppLogger.info(
          'TeamContext: no team on attempt $attempt, '
          'retrying in ${delay.inMilliseconds}ms…',
        );
        await Future.delayed(delay);
        delay *= 2; // 600 → 1200 → 2400 ms
      }
    }

    AppLogger.error(
      'TeamContext: no team found after $maxAttempts attempts. '
      'Check Postgres logs for handle_new_user failures.',
      null,
    );
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  Future<void> _fetchAndApply() async {
    try {
      final response = await _supabase.rpc('get_my_workspace_context');
      if (response != null) {
        _hasTeam = response['has_team'] ?? false;
        _teamId = response['team_id'];
        _role = response['role'];
        _status = response['status'];

        final workspace = response['workspace'];
        if (workspace != null) {
          _workspaceDisplayName =
              workspace['display_name'] ?? 'My Workspace';
          _workspaceAvatarUrl = workspace['avatar_url'];
          _brandName = workspace['brand_name'];
          _brandColor = workspace['brand_color'];
          _workspaceSettings =
              (workspace['settings'] as Map<String, dynamic>?) ?? {};
        }
      } else {
        _hasTeam = false;
      }
    } catch (e) {
      AppLogger.error('TeamContext: RPC failed', e);
      _error = e.toString();
      _hasTeam = false;
    }
  }

  void clear() {
    _isLoading = false;
    _hasTeam = false;
    _teamId = null;
    _role = null;
    _status = null;
    _workspaceDisplayName = 'My Workspace';
    _workspaceAvatarUrl = null;
    _brandName = null;
    _brandColor = null;
    _workspaceSettings = {};
    _error = null;
    notifyListeners();
  }
}
