import 'package:flutter/material.dart';

class GetAppScreen extends StatelessWidget {
  const GetAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get the ORINX App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Take ORINX with you',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Download our mobile and desktop applications'),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AppDownloadButton(icon: Icons.apple, label: 'iOS'),
                const SizedBox(width: 24),
                _AppDownloadButton(icon: Icons.android, label: 'Android'),
                const SizedBox(width: 24),
                _AppDownloadButton(icon: Icons.desktop_windows, label: 'Desktop'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDownloadButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AppDownloadButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          iconSize: 48,
          onPressed: () {},
          icon: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
