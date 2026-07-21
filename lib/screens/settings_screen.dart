import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../content/content_models.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/support_developer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.externalUrlLauncher,
  });
  final AppController controller;
  final ExternalUrlLauncher? externalUrlLauncher;

  Future<void> _resetEntireGame(BuildContext context) async {
    final continueToFinalWarning = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Reset all game data?',
            icon: PixelIcon(
              PixelGlyph.error,
              color: Theme.of(context).colorScheme.error,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: const Text('Reset all game data?'),
            content: const Text(
              'This affects every story arc and all master settings. You will '
              'receive one final warning before anything is deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep my data'),
              ),
              FilledButton(
                key: const ValueKey('confirm-reset-game-first'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
    if (continueToFinalWarning != true || !context.mounted) return;
    final reset = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Final warning: erase everything?',
            icon: PixelIcon(
              PixelGlyph.error,
              color: Theme.of(context).colorScheme.error,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: const Text('Final warning: erase everything?'),
            content: const Text(
              'This permanently deletes progress and story history for every '
              'arc, all records and unlocks, Just Puzzle! data, tutorial '
              'progress, and master settings. This can’t be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep my data'),
              ),
              FilledButton(
                key: const ValueKey('confirm-reset-game-final'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Erase everything'),
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
          title: const Text('Master settings'),
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
            Text('Story arcs', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final arc in controller.availableStoryArcs)
              _SettingPanel(
                child: ListTile(
                  key: ValueKey('story-arc-settings-${arc.id}'),
                  title: Text(arc.title),
                  subtitle: Text(
                    controller.isMapUnlocked(arc.id)
                        ? 'Arc map unlocked · manage progress'
                        : 'Manage this arc’s progress and map',
                  ),
                  trailing: PixelIcon(
                    PixelGlyph.arrowRight,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                    excludeFromSemantics: true,
                  ),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => StoryArcSettingsScreen(
                                controller: controller,
                                arc: arc,
                                externalUrlLauncher: externalUrlLauncher,
                              ),
                        ),
                      ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'All game data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _SettingPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Full game reset',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Erase every arc, puzzle-only run, unlock, and master '
                      'preference. This action requires two confirmations.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('reset-entire-game'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      onPressed: () => _resetEntireGame(context),
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
            SupportDeveloperPanel(
              key: const ValueKey('master-settings-support'),
              externalUrlLauncher: externalUrlLauncher,
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

class StoryArcSettingsScreen extends StatelessWidget {
  const StoryArcSettingsScreen({
    super.key,
    required this.controller,
    required this.arc,
    this.externalUrlLauncher,
  });

  final AppController controller;
  final StoryArc arc;
  final ExternalUrlLauncher? externalUrlLauncher;

  bool get _unlockActionComplete => controller.isMapUnlocked(arc.id);

  Future<void> _unlockEntireMap(BuildContext context) async {
    final unlock = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Unlock ${arc.title} map?',
            icon: PixelIcon(
              PixelGlyph.lock,
              color: Theme.of(context).colorScheme.secondary,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: Text('Unlock ${arc.title} map?'),
            content: Text(
              'Every puzzle and chapter landmark in ${arc.title} will become '
              'available immediately. The finale remains locked until the '
              'final boss is defeated. Other story arcs are not affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep progression'),
              ),
              FilledButton(
                key: ValueKey('confirm-unlock-map-${arc.id}'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Unlock this arc'),
              ),
            ],
          ),
    );
    if (unlock != true || !context.mounted) return;
    await controller.unlockEntireMap(arc.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${arc.title} map unlocked.')));
  }

  Future<void> _resetArc(BuildContext context) async {
    final reset = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Reset ${arc.title}?',
            icon: PixelIcon(
              PixelGlyph.error,
              color: Theme.of(context).colorScheme.error,
              size: 32,
              excludeFromSemantics: true,
            ),
            title: Text('Reset ${arc.title}?'),
            content: Text(
              'This deletes puzzle progress, records, story history, and '
              'unlocks for ${arc.title} only. Master settings, Just Puzzle!, '
              'the tutorial, and all other story arcs are preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep arc progress'),
              ),
              FilledButton(
                key: ValueKey('confirm-reset-arc-${arc.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reset this arc'),
              ),
            ],
          ),
    );
    if (reset == true) await controller.resetStoryArc(arc.id);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder:
        (context, _) => Scaffold(
          appBar: AppBar(
            leading: const PixelBackButton(),
            title: Text('${arc.title} settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Arc progress',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
                        controller.isMapUnlocked(arc.id)
                            ? 'Every puzzle and chapter landmark in this arc is available.'
                                '${controller.isFinaleUnlocked(arc.id) ? ' The final boss has fallen, and the finale is unlocked.' : ' Defeat the final boss to unlock the finale.'}'
                            : 'Open this arc’s puzzles and landmarks without '
                                'finishing them in order. The finale will stay '
                                'locked until the final boss is defeated.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: ValueKey('unlock-entire-map-${arc.id}'),
                        onPressed:
                            _unlockActionComplete
                                ? null
                                : () => _unlockEntireMap(context),
                        icon: PixelIcon(
                          _unlockActionComplete
                              ? PixelGlyph.check
                              : PixelGlyph.lock,
                          color:
                              _unlockActionComplete
                                  ? Theme.of(context).disabledColor
                                  : Theme.of(context).colorScheme.secondary,
                          size: 16,
                          excludeFromSemantics: true,
                        ),
                        label: Text(
                          _unlockActionComplete
                              ? 'This arc’s map is unlocked'
                              : 'Unlock this arc’s map',
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
                        'Reset ${arc.title}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Start this story arc again without changing anything else.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: ValueKey('reset-story-arc-${arc.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () => _resetArc(context),
                        icon: const PixelIcon(
                          PixelGlyph.reset,
                          size: 16,
                          excludeFromSemantics: true,
                        ),
                        label: const Text('Reset this story arc'),
                      ),
                    ],
                  ),
                ),
              ),
              SupportDeveloperPanel(
                key: ValueKey('story-arc-settings-support-${arc.id}'),
                externalUrlLauncher: externalUrlLauncher,
              ),
            ],
          ),
        ),
  );
}

class _SettingPanel extends StatelessWidget {
  const _SettingPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16, right: 4),
    child: PixelPanel(
      padding: EdgeInsets.zero,
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}
