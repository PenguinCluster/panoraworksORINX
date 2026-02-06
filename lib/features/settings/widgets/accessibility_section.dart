import 'package:flutter/material.dart';

class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accessibility', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),
        const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
            ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_brightness)),
          ],
          selected: const {ThemeMode.system},
          onSelectionChanged: (value) {},
        ),
      ],
    );
  }
}
