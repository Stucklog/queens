import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../app/arc_theme.dart';
import '../app/bestiary.dart';
import '../app/branding.dart';
import '../app/journey.dart';
import '../content/content_models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';
import '../widgets/support_developer.dart';
import 'academy_screen.dart';
import 'bestiary_screen.dart';
import 'challenge_screen.dart';
import 'journey_screen.dart';
import 'settings_screen.dart';
import 'story_scene_screen.dart';

/// The stable entry point for installed content after the tutorial.
///
/// Available packages open normally. The web edition also renders lightweight
/// previews for manifest entries that intentionally belong to the paid apps;
/// their full story packages are never loaded.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.externalUrlLauncher,
  });

  final AppController controller;
  final ExternalUrlLauncher? externalUrlLauncher;

  Future<void> _openArc(BuildContext context, StoryArc arc) async {
    final openingUnseen = !controller.hasSeenStoryBeat(arc.openingScene.id);
    unawaited(
      precachePixelArtAssets(context, [
        arc.chapters.first.artAsset,
        if (openingUnseen) ...[
          ...arc.openingScene.assetPaths,
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

  Future<void> _openStoryEntry(
    BuildContext context,
    ArcAvailability entry,
  ) async {
    final arc = entry.arc;
    if (arc != null) {
      await _openArc(context, arc);
      return;
    }
    final storefront = entry.storefront;
    if (entry.status != ContentAvailabilityStatus.notInEdition ||
        storefront == null ||
        !controller.showsLockedPreviewFor(entry)) {
      return;
    }
    unawaited(
      precachePixelArtAssets(context, storefront.prologuePreview.assetPaths),
    );
    var completedPreview = false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => StorySceneScreen.fromContent(
              controller: controller,
              scene: storefront.prologuePreview,
              palette: JourneyPalette(
                primary: Color(storefront.theme.primaryColor),
                secondary: Color(storefront.theme.secondaryColor),
                theme: ArcThemeColors.fromStorefront(
                  background: Color(storefront.theme.backgroundColor),
                  surface: Color(storefront.theme.surfaceColor),
                ),
              ),
              recordSeenOnComplete: false,
              onCompleted: () => completedPreview = true,
            ),
      ),
    );
    if (!context.mounted || !completedPreview) return;
    await _showAppsOnlyDialog(context, storefront.title);
  }

  Future<void> _showAppsOnlyDialog(BuildContext context, String storyTitle) =>
      showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              key: const ValueKey('apps-only-story-dialog'),
              title: const Text('Continue in the app'),
              content: Text(
                '$storyTitle is available in the one-time-purchase apps. '
                'Your purchase includes every story arc.',
              ),
              actions: [
                if (controller.storefrontLinks case final links?) ...[
                  TextButton(
                    key: const ValueKey('open-app-store'),
                    onPressed:
                        () => _launchStore(
                          dialogContext,
                          links.appStore,
                          'App Store',
                        ),
                    child: const Text('App Store'),
                  ),
                  TextButton(
                    key: const ValueKey('open-play-store'),
                    onPressed:
                        () => _launchStore(
                          dialogContext,
                          links.playStore,
                          'Google Play',
                        ),
                    child: const Text('Google Play'),
                  ),
                ],
                FilledButton(
                  key: const ValueKey('close-apps-only-dialog'),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
      );

  Future<void> _launchStore(
    BuildContext context,
    Uri uri,
    String storeName,
  ) async {
    var opened = false;
    try {
      opened = await (externalUrlLauncher ?? _launchExternalStoreUrl)(uri);
    } on Object {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $storeName.')));
    }
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
    final storyEntries = controller.storyArcEntries
        .where(
          (entry) =>
              entry.isAvailable ||
              (entry.status == ContentAvailabilityStatus.notInEdition &&
                  controller.showsLockedPreviewFor(entry)),
        )
        .toList(growable: false);
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
            if (storyEntries.isEmpty)
              const _UnavailableStoryPanel()
            else
              for (final entry in storyEntries) ...[
                _StoryArcTile(
                  entry: entry,
                  onPressed: () => _openStoryEntry(context, entry),
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

Future<bool> _launchExternalStoreUrl(Uri uri) => launchUrl(
  uri,
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);

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
  const _StoryArcTile({required this.entry, required this.onPressed});

  final ArcAvailability entry;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final descriptor = entry.descriptor!;
    final storefront = descriptor.storefront;
    final arc = entry.arc;
    final chapter = arc?.chapters.first;
    final locked = !entry.isAvailable;
    final tileBackground = Color(storefront.theme.backgroundColor);
    final tileSurface = Color(storefront.theme.surfaceColor);
    final accent = Color(storefront.theme.secondaryColor);
    final foreground =
        ThemeData.estimateBrightnessForColor(tileBackground) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Semantics(
      button: true,
      label:
          locked
              ? '${storefront.title}. Locked story. Preview prologue.'
              : '${storefront.title}. Open story map.',
      child: Material(
        key: ValueKey('story-arc-tile-${descriptor.arcId}'),
        color: tileSurface,
        shape: PixelOrganicBorder(side: BorderSide(color: accent, width: 3)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onPressed,
          customBorder: const PixelOrganicBorder(),
          child: SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (chapter != null)
                  PixelLandscape(
                    chapter: chapter,
                    brightness: chapter.palette.theme.brightness,
                    placement: PixelArtPlacement.banner,
                    assetPath: storefront.tileArtAsset,
                  )
                else
                  _StorefrontTileArt(storefront: storefront),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tileBackground.withValues(alpha: .14),
                        tileBackground.withValues(alpha: .52),
                        tileBackground.withValues(alpha: .95),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
                if (storefront.tileForegroundAsset case final asset?)
                  Positioned(
                    right: 17,
                    bottom: 12,
                    width: 82,
                    height: 123,
                    child: Image.asset(
                      asset,
                      key: const ValueKey('home-story-main-character'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      excludeFromSemantics: true,
                      errorBuilder:
                          (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                if (locked)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tileBackground.withValues(alpha: .9),
                        border: Border.all(color: accent, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: PixelIcon(
                          PixelGlyph.lock,
                          key: ValueKey('locked-story-${descriptor.arcId}'),
                          color: accent,
                          size: 24,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 18,
                  right:
                      storefront.tileForegroundAsset == null || locked
                          ? 18
                          : 92,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ArcTitle(title: storefront.title, color: foreground),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              locked
                                  ? storefront.lockedTileSubtitle
                                  : storefront.tileSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PixelIcon(
                            locked ? PixelGlyph.lock : PixelGlyph.arrowRight,
                            color: accent,
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

class _StorefrontTileArt extends StatelessWidget {
  const _StorefrontTileArt({required this.storefront});

  final ArcStorefrontContent storefront;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Color(storefront.theme.backgroundColor),
    child: Image.asset(
      storefront.tileArtAsset,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -.1),
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
      errorBuilder:
          (context, error, stackTrace) => DecoratedBox(
            key: const ValueKey('storefront-art-error-fallback'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(storefront.theme.primaryColor),
                  Color(storefront.theme.backgroundColor),
                ],
              ),
            ),
          ),
    ),
  );
}

class _ArcTitle extends StatelessWidget {
  const _ArcTitle({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium!.copyWith(
      color: color,
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
