import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/bestiary.dart';
import '../app/branding.dart';
import '../content/content_models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';
import 'academy_screen.dart';
import 'bestiary_screen.dart';
import 'challenge_screen.dart';
import 'journey_screen.dart';
import 'settings_screen.dart';
import 'story_scene_screen.dart';

/// The stable entry point for installed content after the tutorial.
///
/// Only arcs reported as available by the content registry are rendered. A
/// missing or invalid package therefore cannot displace another story arc or
/// the independently entitled Just Puzzle mode.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _openArc(BuildContext context, StoryArc arc) async {
    final openingUnseen = !controller.hasSeenStoryBeat(arc.openingScene.id);
    unawaited(
      precachePixelArtAssets(context, [
        arc.chapters.first.artAsset,
        if (openingUnseen) ...[
          arc.openingScene.artAsset,
          PixelStoryKnightSprite.assetPath,
        ],
      ]),
    );
    if (openingUnseen) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => StorySceneScreen.fromContent(
                controller: controller,
                scene: arc.openingScene,
                chapter: arc.chapters.first,
              ),
        ),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => JourneyScreen(controller: controller, arc: arc),
      ),
    );
  }

  void _openJustPuzzle(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ChallengeScreen(controller: controller)),
  );

  void _openAcademy(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => AcademyScreen(controller: controller)),
  );

  void _openBestiary(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => BestiaryScreen(controller: controller)),
  );

  void _openMasterSettings(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SettingsScreen(controller: controller)),
  );

  @override
  Widget build(BuildContext context) {
    final arcs = controller.availableStoryArcs.toList(growable: false);
    final bestiaryProgress = [
      for (final arc in arcs)
        BestiaryArcProgress.derive(arc: arc, recordFor: controller.recordFor),
    ];
    final bestiaryTotal = bestiaryProgress.fold<int>(
      0,
      (total, arc) => total + arc.totalCount,
    );
    final bestiaryDefeated = bestiaryProgress.fold<int>(
      0,
      (total, arc) => total + arc.defeatedCount,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CrownMark(size: 28),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                appNameUppercase,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (controller.academyAvailable)
            PixelIconButton(
              key: const ValueKey('open-academy'),
              glyph: PixelGlyph.book,
              tooltip: 'Academy',
              onPressed: () => _openAcademy(context),
            ),
          PixelIconButton(
            key: const ValueKey('open-master-settings'),
            glyph: PixelGlyph.gear,
            tooltip: 'Master settings',
            onPressed: () => _openMasterSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('home-content-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'Choose your story',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (arcs.isEmpty)
              const _UnavailableStoryPanel()
            else
              for (final arc in arcs) ...[
                _StoryArcTile(
                  arc: arc,
                  onPressed: () => _openArc(context, arc),
                ),
                const SizedBox(height: 16),
              ],
            if (controller.justPuzzleAvailable) ...[
              _JustPuzzleTile(
                hasRun: controller.hasChallenge,
                onPressed: () => _openJustPuzzle(context),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              key: const ValueKey('master-settings-button'),
              onPressed: () => _openMasterSettings(context),
              icon: PixelIcon(
                PixelGlyph.gear,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
                excludeFromSemantics: true,
              ),
              label: const Text('Master settings'),
            ),
            if (arcs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _BestiaryTile(
                defeated: bestiaryDefeated,
                total: bestiaryTotal,
                onPressed: () => _openBestiary(context),
              ),
            ],
            if (controller.academyAvailable) ...[
              const SizedBox(height: 16),
              _AcademyTile(
                completed: controller.academyCompletedCount,
                total: controller.academyLessons.length,
                onPressed: () => _openAcademy(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BestiaryTile extends StatelessWidget {
  const _BestiaryTile({
    required this.defeated,
    required this.total,
    required this.onPressed,
  });

  final int defeated;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PixelPanel(
    padding: EdgeInsets.zero,
    borderColor: Theme.of(context).colorScheme.secondary,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('open-bestiary-home'),
        onTap: onPressed,
        customBorder: const PixelOrganicBorder(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              PixelIcon(
                PixelGlyph.shield,
                color: Theme.of(context).colorScheme.secondary,
                size: 32,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bestiary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      defeated == total && total > 0
                          ? 'All $total foes defeated · replay their animations'
                          : '$defeated of $total foes defeated',
                      key: const ValueKey('home-bestiary-progress'),
                    ),
                  ],
                ),
              ),
              PixelIcon(
                PixelGlyph.arrowRight,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AcademyTile extends StatelessWidget {
  const _AcademyTile({
    required this.completed,
    required this.total,
    required this.onPressed,
  });

  final int completed;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PixelPanel(
    padding: EdgeInsets.zero,
    borderColor: Theme.of(context).colorScheme.secondary,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('open-academy-home'),
        onTap: onPressed,
        customBorder: const PixelOrganicBorder(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              PixelIcon(
                PixelGlyph.book,
                color: Theme.of(context).colorScheme.secondary,
                size: 32,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed == total
                          ? 'All techniques mastered · replay anytime'
                          : '$completed of $total lessons mastered',
                    ),
                  ],
                ),
              ),
              PixelIcon(
                PixelGlyph.arrowRight,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StoryArcTile extends StatelessWidget {
  const _StoryArcTile({required this.arc, required this.onPressed});

  final StoryArc arc;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final chapter = arc.chapters.first;
    return Semantics(
      button: true,
      label: '${arc.title}. Open story map.',
      child: Material(
        key: ValueKey('story-arc-tile-${arc.id}'),
        color: Theme.of(context).colorScheme.surface,
        shape: PixelOrganicBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 3,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onPressed,
          customBorder: const PixelOrganicBorder(),
          child: SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PixelLandscape(
                  chapter: chapter,
                  brightness: Theme.of(context).brightness,
                  placement: PixelArtPlacement.banner,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x24080d20),
                        Color(0x66080d20),
                        Color(0xf2080d20),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
                const Positioned(
                  right: 17,
                  bottom: 12,
                  child: PixelKnightSprite(
                    key: ValueKey('home-story-main-character'),
                    animation: KnightAnimation.bounce,
                    width: 82,
                    height: 123,
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 92,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ArcTitle(title: arc.title),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Begin in ${chapter.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PixelIcon(
                            PixelGlyph.arrowRight,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 24,
                            excludeFromSemantics: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcTitle extends StatelessWidget {
  const _ArcTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium!.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w900,
      height: 1.02,
      shadows: const [Shadow(color: Colors.black, offset: Offset(3, 3))],
    );
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _JustPuzzleTile extends StatelessWidget {
  const _JustPuzzleTile({required this.hasRun, required this.onPressed});

  final bool hasRun;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => PixelPanel(
    padding: EdgeInsets.zero,
    borderColor: Theme.of(context).colorScheme.secondary,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('open-just-puzzle-home'),
        onTap: onPressed,
        customBorder: const PixelOrganicBorder(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              PixelIcon(
                PixelGlyph.star,
                color: Theme.of(context).colorScheme.secondary,
                size: 32,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Just Puzzle!',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasRun
                          ? 'Resume your puzzle-only run'
                          : 'Play without story progression',
                    ),
                  ],
                ),
              ),
              PixelIcon(
                PixelGlyph.arrowRight,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UnavailableStoryPanel extends StatelessWidget {
  const _UnavailableStoryPanel();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Story content unavailable',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'No installed story package could be opened. Other content and saved progress are safe.',
          ),
        ],
      ),
    ),
  );
}
