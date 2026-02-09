import 'package:flutter/material.dart';
import '../../../../core/state/app_settings_controller.dart';

class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({super.key});

  Future<void> _updateSetting(
    BuildContext context,
    String label,
    Future<void> Function() updateFn,
  ) async {
    await updateFn();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label updated'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, child) {
        final settings = AppSettingsController.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accessibility',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_brightness),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                _updateSetting(
                  context,
                  'Theme',
                  () => settings.updateThemeMode(newSelection.first),
                );
              },
            ),
            const SizedBox(height: 32),

            const Text('Visual', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Reduce Motion'),
              subtitle: const Text('Minimize animations and transitions'),
              value: settings.reduceMotion,
              onChanged: (val) {
                _updateSetting(
                  context,
                  'Reduce Motion',
                  () => settings.updateReduceMotion(val),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('High Contrast'),
              subtitle: const Text('Increase contrast for better legibility'),
              value: settings.highContrast,
              onChanged: (val) {
                _updateSetting(
                  context,
                  'High Contrast',
                  () => settings.updateHighContrast(val),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        );
      },
    );
  }
}
