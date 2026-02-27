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

  Map<String, dynamic> get teamProfile => {
        'avatarUrl': _workspaceAvatarUrl,
      };

  bool get isOwner => _role == 'owner';
  bool get isAdmin => _role == 'admin';
  bool get isManager => _role == 'manager';
  bool get isMember => _role == 'member';

  bool get canAccessSettings => true;
  bool get canAccessProfileTab => true;
  bool get canAccessLoginTab => true;
  bool get canAccessAccessibilityTab => true;
  bool get canAccessWorkspaceSettings => isOwner || isAdmin;
  bool get canAccessTeamTab => canAccessWorkspaceSettings;
  bool get canAccessBillingTab => canAccessWorkspaceSettings;
  bool get canAccessOrdersTab => canAccessWorkspaceSettings;
  bool get canEditWorkspaceIdentity => isOwner;
  bool get canManageTeamMembers => isOwner || isAdmin;
  bool get canViewConnectedAccounts => isOwner;
  bool get canViewBilling => isOwner || isAdmin;
  bool get isMemberLike => isOwner || isAdmin || isManager || isMember;

  TeamContextController._internal();

  // ─── Core Load ────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    await _fetchAndApply();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await load();
  }

  // ─── Retry-with-Backoff (Bug 1 Fix) ───────────────────────────────────────
  //
  // Called from OverviewScreen after a fresh standalone signup.
  // The Postgres trigger that creates the team + owner row runs synchronously
  // with the auth.users INSERT, but email-confirmation flows can briefly
  // surface a session before the first RPC response has propagated through
  // PostgREST's schema cache. Three quick retries with a short delay is
  // enough to bridge that window without blocking the UI.
  //
  // Usage:
  //   await TeamContextController.instance.loadWithRetry();
  //
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
          'TeamContext: resolved on attempt $attempt. role=$_role teamId=$_teamId',
        );
        return;
      }

      if (attempt < maxAttempts) {
        AppLogger.info(
          'TeamContext: no team on attempt $attempt, retrying in ${delay.inMilliseconds}ms…',
        );
        await Future.delayed(delay);
        delay *= 2; // exponential backoff: 600ms → 1200ms → 2400ms
      }
    }

    AppLogger.error(
      'TeamContext: no team found after $maxAttempts attempts. '
      'This may indicate a trigger failure — check Postgres logs.',
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
