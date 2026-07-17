import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../widgets/pixel_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  Future<void> _unlockEntireMap(BuildContext context) async {
    final unlock = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Unlock the entire map?',
            icon: PixelIcon(
              PixelGlyph.lock,
              color: Theme.of(context).colorScheme.secondary,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: const Text('Unlock the entire map?'),
            content: const Text(
              'All 120 puzzles and every chapter landmark will become '
              'available immediately. This can’t be reversed without '
              'completely resetting the game.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep progression'),
              ),
              FilledButton(
                key: const ValueKey('confirm-unlock-map'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Unlock map'),
              ),
            ],
          ),
    );
    if (unlock != true || !context.mounted) return;
    await controller.unlockEntireMap();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Entire map unlocked.')));
  }

  Future<void> _resetGame(BuildContext context) async {
    final reset = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Completely reset the game?',
            icon: PixelIcon(
              PixelGlyph.error,
              color: Theme.of(context).colorScheme.error,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: const Text('Completely reset the game?'),
            content: const Text(
              'This permanently deletes all progress, records, settings, '
              'story history, and challenge data, then reloads the game from '
              'the beginning. This can’t be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('confirm-reset-game'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset game'),
              ),
            ],
          ),
    );
    if (reset == true) await controller.resetGame();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
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
            Text('Game data', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SettingPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Map access',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.fullMapUnlocked
                          ? 'All puzzles and chapter landmarks are available.'
                          : 'Open every puzzle and chapter landmark without '
                              'finishing the journey in order.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('unlock-entire-map'),
                      onPressed:
                          controller.fullMapUnlocked
                              ? null
                              : () => _unlockEntireMap(context),
                      icon: PixelIcon(
                        controller.fullMapUnlocked
                            ? PixelGlyph.check
                            : PixelGlyph.lock,
                        color:
                            controller.fullMapUnlocked
                                ? Theme.of(context).disabledColor
                                : Theme.of(context).colorScheme.secondary,
                        size: 16,
                        excludeFromSemantics: true,
                      ),
                      label: Text(
                        controller.fullMapUnlocked
                            ? 'Entire map unlocked'
                            : 'Unlock entire map',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _SettingPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Reset game',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Erase everything stored by the game and start again.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('reset-entire-game'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: () => _resetGame(context),
                      icon: const PixelIcon(
                        PixelGlyph.reset,
                        size: 16,
                        excludeFromSemantics: true,
                      ),
                      label: const Text('Completely reset game'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
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
    },
  );
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
