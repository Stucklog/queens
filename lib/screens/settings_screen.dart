import 'package:flutter/material.dart';

import '../app/app_controller.dart';

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
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
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged:
                        (value) => controller.updateSettings(
                          settings.copyWith(themeMode: value.single),
                        ),
                  ),
                ],
              ),
            ),
          ),
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
              'Regalia uses local device storage only. It has no accounts, analytics, ads, or runtime network services.',
            ),
          ),
        ],
      ),
    );
  }
}
