import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/routing/app_router.dart';
import 'core/state/app_settings_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Load settings
  await AppSettingsController.instance.loadSettings();

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
