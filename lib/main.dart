import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/state/app_settings_controller.dart';
import 'core/state/team_context_controller.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

Future<void> _bootstrapAuthFromUrlIfPresent() async {
  final uri = Uri.base;
  final hasCode = uri.queryParameters.containsKey('code');
  final hasTokenInQuery = uri.queryParameters.containsKey('access_token');
  final hasTokenInFragment =
      uri.fragment.contains('access_token=') ||
      uri.fragment.contains('refresh_token=') ||
      uri.fragment.contains('type=invite') ||
      uri.fragment.contains('type=recovery');

  if (!hasCode && !hasTokenInQuery && !hasTokenInFragment) return;

  debugPrint('AuthBootstrap: Detected auth params in URL.');
  debugPrint('AuthBootstrap: URI=$uri');
  debugPrint('AuthBootstrap: query=${uri.query}');
  debugPrint('AuthBootstrap: fragment=${uri.fragment}');

  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
    final session = Supabase.instance.client.auth.currentSession;
    debugPrint(
      'AuthBootstrap: getSessionFromUrl completed. sessionPresent=${session != null}',
    );
  } catch (e) {
    debugPrint('AuthBootstrap: getSessionFromUrl failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // IMPORTANT: Parse auth code/token BEFORE the router can normalize the URL.
  // This is especially critical for invite/recovery flows that use URL fragments.
  await _bootstrapAuthFromUrlIfPresent();

  // Load settings
  await AppSettingsController.instance.loadSettings();

  // Initialize Team Context
  await TeamContextController.instance.load();

  // Listen for auth state changes to update team context
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

    // High Contrast Adjustments
    Color seedColor = Colors.blue;
    if (highContrast) {
      // Use higher contrast colors if needed, but for MVP standard seed often works well.
      // We can enforce specific background/text colors.
      seedColor = isDark ? Colors.cyanAccent : Colors.blue[900]!;
    }

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      // Force higher contrast surfaces if highContrast is on
      background: highContrast ? (isDark ? Colors.black : Colors.white) : null,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Reduce Motion: Disable page transitions
      pageTransitionsTheme: settings.reduceMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android:
                    FadeUpwardsPageTransitionsBuilder(), // Or NoAnimationPageTransitionsBuilder if custom
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : null,
      // High Contrast: Strengthen borders/dividers
      dividerTheme: highContrast
          ? const DividerThemeData(thickness: 2, color: Colors.black)
          : null,
    );
  }
}
