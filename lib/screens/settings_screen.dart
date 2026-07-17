import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../widgets/pixel_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    return Scaffold(
      appBar: AppBar(
        leading: const PixelBackButton(),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingPanel(
            child: PixelToggleTile(
              title: const Text('Show timer'),
              subtitle: const Text('Display active solving time'),
              value: settings.showTimer,
              onChanged:
                  (value) => controller.updateSettings(
                    settings.copyWith(showTimer: value),
                  ),
            ),
          ),
          _SettingPanel(
            child: PixelToggleTile(
              title: const Text('Automatic exclusions'),
              subtitle: const Text(
                'Show pixel sparks in cells excluded by crowns',
              ),
              value: settings.showAutomaticExclusions,
              onChanged:
                  (value) => controller.updateSettings(
                    settings.copyWith(showAutomaticExclusions: value),
                  ),
            ),
          ),
          _SettingPanel(
            child: PixelToggleTile(
              title: const Text('Reduce motion'),
              subtitle: const Text('Minimize decorative movement'),
              value: settings.reducedMotion,
              onChanged:
                  (value) => controller.updateSettings(
                    settings.copyWith(reducedMotion: value),
                  ),
            ),
          ),
          const SizedBox(height: 24),
          PixelPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelIcon(
                  PixelGlyph.shield,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 32,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Private by design',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '$appName uses local device storage only. It has no accounts, analytics, ads, or runtime network services.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingPanel extends StatelessWidget {
  const _SettingPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16, right: 4),
    child: PixelPanel(padding: EdgeInsets.zero, child: child),
  );
}
