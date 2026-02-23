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

  // Workspace Identity
  String _workspaceDisplayName = 'My Workspace';
  String? _workspaceAvatarUrl;
  String? _brandName;
  String? _brandColor;
  Map<String, dynamic> _workspaceSettings = {};

  String? _error;

  // Getters
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

  // Role Helpers
  bool get isOwner => _role == 'owner';
  bool get isAdmin => _role == 'admin';
  bool get isManager => _role == 'manager';
  bool get isMember => _role == 'member';

  // --- Centralized RBAC Permissions ---

  /// Can the user access the Settings area at all?
  /// Now true for everyone, as everyone has personal settings.
  bool get canAccessSettings => true;

  // Tab Access
  bool get canAccessProfileTab => true;
  bool get canAccessLoginTab => true;
  bool get canAccessAccessibilityTab => true;

  /// Workspace-level tabs (Team, Billing, Orders)
  /// Only Owners and Admins can access these.
  bool get canAccessWorkspaceSettings => isOwner || isAdmin;

  bool get canAccessTeamTab => canAccessWorkspaceSettings;
  bool get canAccessBillingTab => canAccessWorkspaceSettings;
  bool get canAccessOrdersTab => canAccessWorkspaceSettings;

  // Feature Permissions

  /// Can edit workspace name, logo, brand?
  /// Only Owner. Admins are read-only.
  bool get canEditWorkspaceIdentity => isOwner;

  /// Can invite/remove members?
  /// Owner and Admin.
  bool get canManageTeamMembers => isOwner || isAdmin;

  /// Can view/manage connected accounts (Integrations)?
  /// Only Owner.
  bool get canViewConnectedAccounts => isOwner;

  /// Can view detailed billing info?
  /// Owner and Admin.
  bool get canViewBilling => isOwner || isAdmin;

  // ------------------------------------

  bool get isMemberLike => isOwner || isAdmin || isManager || isMember;

  TeamContextController._internal();

  /// Load workspace context from Supabase RPC
  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.rpc('get_my_workspace_context');

      if (response != null) {
        _hasTeam = response['has_team'] ?? false;
        _teamId = response['team_id'];
        _role = response['role'];
        _status = response['status'];

        final workspace = response['workspace'];
        if (workspace != null) {
          _workspaceDisplayName = workspace['display_name'] ?? 'My Workspace';
          _workspaceAvatarUrl = workspace['avatar_url'];
          _brandName = workspace['brand_name'];
          _brandColor = workspace['brand_color'];
          _workspaceSettings = workspace['settings'] ?? {};
        }
      } else {
        _hasTeam = false;
      }
    } catch (e) {
      AppLogger.error('Failed to load team context', e);
      _error = e.toString();
      _hasTeam = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the context (useful after updates)
  Future<void> refresh() async {
    await load();
  }

  /// Clear context (on logout)
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
