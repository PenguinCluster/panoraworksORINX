import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/state/app_settings_controller.dart';
import 'core/state/team_context_controller.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'dart:html' as html; // Added for minimal web redirect on root+code

Future<void> _bootstrapAuthFromUrlIfPresent() async {
  final uri = Uri.base;
  final hasCode = uri.queryParameters.containsKey('code') || uri.queryParameters.containsKey('error');
  final hasTokenInFragment = uri.fragment.contains('access_token=') ||
      uri.fragment.contains('refresh_token=') ||
      uri.fragment.contains('type=invite') ||
      uri.fragment.contains('type=recovery');

  if (!hasCode && !hasTokenInFragment) return;

  debugPrint('AuthBootstrap: Detected auth params in URL.');

  // FIX BUG 1: If landed on root with code/token (standalone confirmation), force /auth/callback
  if (uri.path == '/' && (hasCode || hasTokenInFragment)) {
    final callbackUri = Uri.parse('/auth/callback').replace(
      queryParameters: uri.queryParameters,
      fragment: uri.fragment,
    );
    debugPrint('AuthBootstrap: Redirecting root+code to callback: ${callbackUri.toString()}');
    html.window.location.replace(callbackUri.toString());
    return;
  }

  try {
    final auth = Supabase.instance.client.auth;
    await auth.getSessionFromUrl(uri);
    final session = auth.currentSession;
    debugPrint('AuthBootstrap: getSessionFromUrl completed. sessionPresent=${session != null}');
  } catch (e) {
    debugPrint('AuthBootstrap: getSessionFromUrl failed: $e');
    String? refreshToken;
    try {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      refreshToken = fragmentParams['refresh_token'];
    } catch (_) {}
    if (refreshToken != null && refreshToken.isNotEmpty) {
      debugPrint('AuthBootstrap: Found refresh_token in fragment. Using setSession().');
      try {
        await Supabase.instance.client.auth.setSession(refreshToken);
      } catch (e2) {
        debugPrint('AuthBootstrap: setSession failed: $e2');
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await _bootstrapAuthFromUrlIfPresent();

  await AppSettingsController.instance.loadSettings();

  await TeamContextController.instance.load();

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed ||
        event == AuthChangeEvent.userUpdated) {
      TeamContextController.instance.load();
    } else if (event == AuthChangeEvent.signedOut) {
      TeamContextController.instance.clear();
    }
  });

  runApp(const OrinxApp());
}

class OrinxApp extends StatelessWidget {
  const OrinxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, child) {
        final settings = AppSettingsController.instance;

        return MaterialApp.router(
          title: 'ORINX',
          themeMode: settings.themeMode,
          theme: _buildTheme(Brightness.light, settings),
          darkTheme: _buildTheme(Brightness.dark, settings),
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness, AppSettingsController settings) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
    final highContrast = settings.highContrast;

    Color seedColor = Colors.blue;
    if (highContrast) {
      seedColor = isDark ? Colors.cyanAccent : Colors.blue[900]!;
    }

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      surface: highContrast ? (isDark ? Colors.black : Colors.white) : null,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      // useMaterial3: true, // deprecated after v3.13.0-0.2.pre; ThemeData constructor now handles this
      pageTransitionsTheme: settings.reduceMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : null,
      dividerTheme: highContrast
          ? const DividerThemeData(thickness: 2, color: Colors.black)
          : null,
    );
  }
}