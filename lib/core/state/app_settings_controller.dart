import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettingsController with ChangeNotifier {
  static final AppSettingsController instance =
      AppSettingsController._internal();
  final _supabase = Supabase.instance.client;

  AppSettingsController._internal();

  ThemeMode _themeMode = ThemeMode.system;
  bool _reduceMotion = false;
  bool _highContrast = false;

  ThemeMode get themeMode => _themeMode;
  bool get reduceMotion => _reduceMotion;
  bool get highContrast => _highContrast;

  Future<void> loadSettings() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select('accessibility_prefs')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && data['accessibility_prefs'] != null) {
        final prefs = data['accessibility_prefs'] as Map<String, dynamic>;
        _themeMode = _parseThemeMode(prefs['theme_mode']);
        _reduceMotion = prefs['reduce_motion'] ?? false;
        _highContrast = prefs['high_contrast'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persistSetting('theme_mode', _themeModeToString(mode));
  }

  Future<void> updateReduceMotion(bool value) async {
    _reduceMotion = value;
    notifyListeners();
    await _persistSetting('reduce_motion', value);
  }

  Future<void> updateHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    await _persistSetting('high_contrast', value);
  }

  Future<void> _persistSetting(String key, dynamic value) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Optimistic update: Fetch current prefs to merge
      final currentData = await _supabase
          .from('profiles')
          .select('accessibility_prefs')
          .eq('id', user.id)
          .maybeSingle();

      final currentPrefs =
          (currentData?['accessibility_prefs'] as Map<String, dynamic>?) ?? {};
      currentPrefs[key] = value;

      await _supabase
          .from('profiles')
          .update({'accessibility_prefs': currentPrefs})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error persisting setting $key: $e');
    }
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
