import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Show timer'),
            subtitle: const Text('Display active solving time'),
            value: settings.showTimer,
            onChanged:
                (value) => controller.updateSettings(
                  settings.copyWith(showTimer: value),
                ),
          ),
          SwitchListTile(
            title: const Text('Automatic exclusions'),
            subtitle: const Text('Show soft dots in cells excluded by crowns'),
            value: settings.showAutomaticExclusions,
            onChanged:
                (value) => controller.updateSettings(
                  settings.copyWith(showAutomaticExclusions: value),
                ),
          ),
          SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text('Minimize decorative movement'),
            value: settings.reducedMotion,
            onChanged:
                (value) => controller.updateSettings(
                  settings.copyWith(reducedMotion: value),
                ),
          ),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Private by design'),
            subtitle: Text(
              '$appName uses local device storage only. It has no accounts, analytics, ads, or runtime network services.',
            ),
          ),
        ],
      ),
    );
  }
}
