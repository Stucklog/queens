import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../content/content_models.dart';
import '../core/models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';
import 'challenge_screen.dart';
import 'game_screen.dart';
import 'rules_screen.dart';
import 'settings_screen.dart';
import 'story_scene_screen.dart';

final Uri buyMeACoffeeUri = Uri.https('buymeacoffee.com', '/philosophyforge');

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    super.key,
    required this.controller,
    this.arc,
    this.externalUrlLauncher,
  });

  final AppController controller;
  final StoryArc? arc;
  final ExternalUrlLauncher? externalUrlLauncher;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _markerKey = GlobalKey(debugLabel: 'journey marker');
  double? _displayedMarkerPosition;
  int _walkFrame = 0;
  Completer<void>? _movementSkip;
  bool _moving = false;
  final Set<String> _presentationPrecaches = {};

  StoryArc get _arc => widget.arc ?? widget.controller.originArc!;

  @override
  void initState() {
    super.initState();
    _displayedMarkerPosition =
        widget.controller.frontierPuzzleFor(_arc)?.order.toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) => _arriveOnMap());
  }

  @override
  void dispose() {
    _movementSkip?.complete();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _arriveOnMap() async {
    await _scrollToMarker();
    if (!mounted) return;
    unawaited(
      _precachePuzzlePresentation(widget.controller.recommendedPuzzleFor(_arc)),
    );
    final progress = widget.controller.journeyProgressFor(_arc);
    final chapter =
        progress.frontierPuzzle == null
            ? _arc.chapters.last
            : _arc.chapterForOrder(progress.frontierPuzzle!.order);
    final reached = progress.completedCount >= chapter.startOrder - 1;
    if (reached && !widget.controller.hasSeenStoryBeat(chapter.storyBeatId)) {
      await _showChapter(chapter);
    }
  }

  Future<void> _openPuzzle(PuzzleDefinition puzzle) async {
    if (!widget.controller.openPuzzle(puzzle)) return;
    unawaited(_precachePuzzlePresentation(puzzle));
    final outcome = await Navigator.of(context).push<PuzzleCompletionOutcome>(
      MaterialPageRoute(
        builder:
            (_) => GameScreen(controller: widget.controller, puzzle: puzzle),
      ),
    );
    if (!mounted || outcome == null || !outcome.advancedJourney) {
      if (mounted) setState(() {});
      return;
    }
    await _moveAfter(outcome);
  }

  Future<void> _moveAfter(PuzzleCompletionOutcome outcome) async {
    await _waitUntilMapIsVisible();
    if (!mounted) return;
    final nextPuzzle = outcome.nextPuzzle;
    if (nextPuzzle != null) {
      unawaited(_precachePuzzlePresentation(nextPuzzle));
    }
    setState(() {
      _displayedMarkerPosition = outcome.puzzle.order.toDouble();
      _moving = true;
      _movementSkip = Completer<void>();
    });
    await _scrollToMarker();
    if (!mounted) return;

    final reduced = MediaQuery.disableAnimationsOf(context);
    final target = outcome.nextPuzzle?.order.toDouble();
    if (reduced) {
      setState(() => _displayedMarkerPosition = target);
    } else {
      const steps = 7;
      for (var step = 1; step <= steps; step++) {
        await Future.any<void>([
          Future<void>.delayed(const Duration(milliseconds: 100)),
          _movementSkip!.future,
        ]);
        if (!mounted) return;
        if (_movementSkip!.isCompleted) break;
        final sameChapter =
            target != null &&
            _arc.chapterForOrder(outcome.puzzle.order).id ==
                _arc.chapterForOrder(target.round()).id;
        setState(() {
          _walkFrame = (step - 1) % 4;
          _displayedMarkerPosition =
              sameChapter
                  ? outcome.puzzle.order +
                      (target - outcome.puzzle.order) * step / steps
                  : step == steps
                  ? target
                  : outcome.puzzle.order.toDouble();
        });
      }
      if (mounted) {
        setState(() {
          _displayedMarkerPosition = target;
          _walkFrame = 0;
        });
      }
    }
    if (!mounted) return;
    setState(() {
      _moving = false;
      _movementSkip = null;
    });
    await _scrollToMarker();
    if (!mounted) return;

    if (outcome.isJourneyComplete) {
      if (!widget.controller.hasSeenStoryBeat(_arc.finaleScene.id)) {
        unawaited(
          precachePixelArtAssets(context, [
            _arc.finaleScene.artAsset,
            PixelStoryKnightSprite.assetPath,
            PixelQueenSprite.assetPath,
          ]),
        );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => StorySceneScreen.finale(
                  controller: widget.controller,
                  arc: _arc,
                ),
          ),
        );
      }
      if (mounted) setState(() {});
      return;
    }

    final chapter = outcome.enteredChapter;
    if (chapter != null &&
        !widget.controller.hasSeenStoryBeat(chapter.storyBeatId)) {
      await _showChapter(chapter);
    }
    if (!mounted || outcome.nextPuzzle == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${_arc.chapterForOrder(outcome.nextPuzzle!.order).title} · Puzzle ${outcome.nextPuzzle!.order}',
          ),
          action: SnackBarAction(
            label: 'Next puzzle',
            onPressed: () => _openPuzzle(outcome.nextPuzzle!),
          ),
        ),
      );
  }

  Future<void> _waitUntilMapIsVisible() async {
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (animation == null || animation.status == AnimationStatus.dismissed) {
      return;
    }
    final ready = Completer<void>();
    void listen(AnimationStatus status) {
      if (status == AnimationStatus.dismissed && !ready.isCompleted) {
        ready.complete();
      }
    }

    animation.addStatusListener(listen);
    if (animation.status == AnimationStatus.dismissed && !ready.isCompleted) {
      ready.complete();
    }
    await ready.future;
    animation.removeStatusListener(listen);
  }

  Future<void> _scrollToMarker() async {
    await WidgetsBinding.instance.endOfFrame;
    final target = _markerKey.currentContext;
    if (!mounted || target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .42,
      duration: Duration.zero,
    );
  }

  Future<void> _showChapter(JourneyChapter chapter) async {
    final scene = _arc.sceneById(chapter.sceneId);
    unawaited(precachePixelArtAssets(context, [scene.artAsset]));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => StorySceneScreen.chapter(
              controller: widget.controller,
              chapter: chapter,
              arc: _arc,
            ),
      ),
    );
  }

  Future<void> _showOpening() async {
    final scene = _arc.openingScene;
    unawaited(
      precachePixelArtAssets(context, [
        scene.artAsset,
        PixelStoryKnightSprite.assetPath,
      ]),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => StorySceneScreen.fromContent(
              controller: widget.controller,
              scene: scene,
              chapter: _arc.chapters.first,
              recordSeenOnComplete: false,
            ),
      ),
    );
  }

  Future<void> _precachePuzzlePresentation(PuzzleDefinition puzzle) async {
    final encounter = _arc.encounterForPuzzle(puzzle);
    if (encounter == null || !_presentationPrecaches.add(encounter.id)) return;
    try {
      await Future.wait([
        precachePixelArtAssets(context, [encounter.spriteAsset]),
        PixelKnightSprite.preloadFinishers(),
      ]);
    } on Object {
      // The puzzle remains playable with its true-error sprite fallbacks.
    }
  }

  Future<void> _openChallenge() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChallengeScreen(controller: widget.controller),
    ),
  );

  Future<void> _openSupportPage() async {
    var opened = false;
    try {
      opened = await (widget.externalUrlLauncher ?? _launchExternalUrl)(
        buyMeACoffeeUri,
      );
    } on Object {
      opened = false;
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the support page.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.journeyProgressFor(_arc);
    final activeChapter =
        progress.frontierPuzzle == null
            ? _arc.chapters.last
            : _arc.chapterForOrder(progress.frontierPuzzle!.order);
    final themed = RegaliaTheme.forChapter(activeChapter);
    return Theme(
      data: themed,
      child: Builder(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Row(
                  children: [
                    CrownMark(size: 24),
                    SizedBox(width: 7),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          appNameUppercase,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  PixelIconButton(
                    glyph: PixelGlyph.book,
                    tooltip: 'How to play',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RulesScreen(),
                          ),
                        ),
                  ),
                  PixelIconButton(
                    key: const ValueKey('buy-me-a-coffee'),
                    glyph: PixelGlyph.cup,
                    tooltip: 'Support Queen’s Regalia',
                    onPressed: _openSupportPage,
                  ),
                  PixelIconButton(
                    glyph: PixelGlyph.gear,
                    tooltip: 'Story arc settings',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => StoryArcSettingsScreen(
                                  controller: widget.controller,
                                  arc: _arc,
                                ),
                          ),
                        ),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _JourneyHeader(
                          controller: widget.controller,
                          arc: _arc,
                          progress: progress,
                          onContinue:
                              () => _openPuzzle(
                                widget.controller.recommendedPuzzleFor(_arc),
                              ),
                          onChallenge: _openChallenge,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                              children: [
                                _OpeningLandmark(
                                  arc: _arc,
                                  onReplay: _showOpening,
                                ),
                                for (final chapter in _arc.chapters)
                                  _RouteSection(
                                    controller: widget.controller,
                                    arc: _arc,
                                    chapter: chapter,
                                    markerPosition: _displayedMarkerPosition,
                                    moving: _moving,
                                    walkFrame: _walkFrame,
                                    markerKey:
                                        _displayedMarkerPosition != null &&
                                                chapter.contains(
                                                  _displayedMarkerPosition!
                                                      .round(),
                                                )
                                            ? _markerKey
                                            : null,
                                    onOpen: _openPuzzle,
                                    onLandmark: () => _showChapter(chapter),
                                  ),
                                _FinalLandmark(
                                  key:
                                      progress.isJourneyComplete &&
                                              _displayedMarkerPosition == null
                                          ? _markerKey
                                          : null,
                                  controller: widget.controller,
                                  arc: _arc,
                                  reached: widget.controller.isFinaleUnlocked(
                                    _arc.id,
                                  ),
                                ),
                                const SizedBox(height: 64),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_moving)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: SafeArea(
                        child: PixelPanel(
                          padding: EdgeInsets.zero,
                          color: Theme.of(context).colorScheme.inverseSurface,
                          borderColor:
                              Theme.of(context).colorScheme.onInverseSurface,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              customBorder: const PixelOrganicBorder(),
                              onTap: () {
                                if (!(_movementSkip?.isCompleted ?? true)) {
                                  _movementSkip!.complete();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    PixelKnightSprite(
                                      animation: KnightAnimation.walk,
                                      frame: _walkFrame,
                                      width: 24,
                                      height: 36,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Crossing the realm… tap to skip',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onInverseSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}

Future<bool> _launchExternalUrl(Uri uri) => launchUrl(
  uri,
  mode: LaunchMode.externalApplication,
  webOnlyWindowName: '_blank',
);

class _OpeningLandmark extends StatelessWidget {
  const _OpeningLandmark({required this.arc, required this.onReplay});

  final StoryArc arc;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
    child: Semantics(
      button: true,
      label:
          '${arc.openingScene.title}. Replay the prologue without changing progress.',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: PixelOrganicBorder(
          side: BorderSide(
            color: Theme.of(context).colorScheme.secondary,
            width: 3,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          key: const ValueKey('intro-landmark'),
          onTap: onReplay,
          customBorder: const PixelOrganicBorder(),
          child: SizedBox(
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PixelLandscape(
                  chapter: arc.chapters.first,
                  brightness: Theme.of(context).brightness,
                  sceneKind: PixelSceneKind.opening,
                  placement: PixelArtPlacement.banner,
                  assetPath: arc.openingScene.artAsset,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xf2151d3b), Color(0x99151d3b)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      PixelIcon(
                        PixelGlyph.book,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 24,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replay the prologue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              '${arc.openingScene.title} · Story only',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const PixelIcon(
                        PixelGlyph.arrowRight,
                        color: Colors.white,
                        size: 24,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.controller,
    required this.arc,
    required this.progress,
    required this.onContinue,
    required this.onChallenge,
  });

  final AppController controller;
  final StoryArc arc;
  final JourneyProgress progress;
  final VoidCallback onContinue;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    final target = controller.recommendedPuzzleFor(arc);
    final title =
        progress.isJourneyComplete
            ? 'The realms remain open'
            : arc.chapterForOrder(target.order).title;
    final label =
        progress.isJourneyComplete
            ? progress.assistedCount > 0
                ? 'Replay earliest assisted'
                : 'Replay puzzle one'
            : controller.hasActiveBoard(target)
            ? 'Continue journey'
            : 'Continue journey';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: PixelOrganicBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                ),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .22),
                  offset: const Offset(5, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text(
                        '${progress.completedCount}/${arc.catalog.puzzles.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (
                          var segment = 0;
                          segment < arc.chapters.length;
                          segment++
                        ) ...[
                          Expanded(
                            child: ColoredBox(
                              color:
                                  progress.completedCount >=
                                          arc.chapters[segment].endOrder
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          if (segment < arc.chapters.length - 1)
                            const SizedBox(width: 2),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '${progress.cleanCount} clean · ${progress.assistedCount} assisted',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('continue-journey'),
                    onPressed: onContinue,
                    icon: PixelIcon(
                      PixelGlyph.arrowRight,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 16,
                      excludeFromSemantics: true,
                    ),
                    label: Text(label),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('open-challenge-mode'),
                    onPressed: onChallenge,
                    icon: PixelIcon(
                      PixelGlyph.star,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 16,
                      excludeFromSemantics: true,
                    ),
                    label: Text(
                      controller.hasChallenge
                          ? 'Resume Just Puzzle!'
                          : 'Just Puzzle!',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({
    required this.controller,
    required this.arc,
    required this.chapter,
    required this.markerPosition,
    required this.moving,
    required this.walkFrame,
    required this.markerKey,
    required this.onOpen,
    required this.onLandmark,
  });

  final AppController controller;
  final StoryArc arc;
  final JourneyChapter chapter;
  final double? markerPosition;
  final bool moving;
  final int walkFrame;
  final GlobalKey? markerKey;
  final ValueChanged<PuzzleDefinition> onOpen;
  final VoidCallback onLandmark;

  @override
  Widget build(BuildContext context) {
    final progress = controller.journeyProgressFor(arc);
    final reached =
        controller.isMapUnlocked(arc.id) ||
        progress.completedCount >= chapter.startOrder - 1;
    final puzzles =
        arc.catalog.puzzles
            .where((puzzle) => chapter.contains(puzzle.order))
            .toList();
    final chapterTheme = RegaliaTheme.forChapter(chapter);
    return Theme(
      data: chapterTheme,
      child: Builder(
        builder:
            (context) => LayoutBuilder(
              builder: (context, constraints) {
                const horizontalPadding = 18.0;
                final width = constraints.maxWidth - horizontalPadding * 2;
                final layout = _RouteLayout(
                  width: width,
                  count: puzzles.length,
                  columns: 4,
                );
                Offset? markerOrigin;
                if (markerPosition != null &&
                    chapter.contains(markerPosition!.round())) {
                  final local = (markerPosition! - chapter.startOrder).clamp(
                    0.0,
                    puzzles.length - 1.0,
                  );
                  final lower = local.floor();
                  final upper = local.ceil();
                  markerOrigin = Offset.lerp(
                    layout.origins[lower],
                    layout.origins[upper],
                    local - lower,
                  );
                }
                return SizedBox(
                  height: layout.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: PixelLandscape(
                          chapter: chapter,
                          brightness: Theme.of(context).brightness,
                          placement: PixelArtPlacement.route,
                        ),
                      ),
                      Positioned(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        top: 18,
                        child: Semantics(
                          button: reached,
                          enabled: reached,
                          label:
                              reached
                                  ? '${chapter.title} landmark. Replay location scene.'
                                  : '${chapter.title} landmark. Reach puzzle ${chapter.startOrder} to unlock this scene.',
                          child: Material(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: .9),
                            shape: const PixelOrganicBorder(
                              side: BorderSide(width: 3),
                            ),
                            child: InkWell(
                              key: ValueKey('landmark-${chapter.id}'),
                              onTap: reached ? onLandmark : null,
                              customBorder: const PixelOrganicBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chapter.title,
                                            style:
                                                Theme.of(
                                                  context,
                                                ).textTheme.headlineSmall,
                                          ),
                                          Text(
                                            '${chapter.difficulty.label} · ${chapter.size} × ${chapter.size} · ${chapter.startOrder}–${chapter.endOrder}',
                                          ),
                                        ],
                                      ),
                                    ),
                                    PixelIcon(
                                      reached
                                          ? PixelGlyph.arrowRight
                                          : PixelGlyph.lock,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      size: 24,
                                      excludeFromSemantics: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: horizontalPadding,
                        top: 0,
                        width: width,
                        height: layout.height,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RoutePainter(
                              points: layout.points,
                              color: chapter.palette.secondary,
                            ),
                          ),
                        ),
                      ),
                      for (var index = 0; index < puzzles.length; index++)
                        Positioned(
                          left: horizontalPadding + layout.origins[index].dx,
                          top: layout.origins[index].dy,
                          child: _PuzzleNode(
                            puzzle: puzzles[index],
                            controller: controller,
                            arc: arc,
                            onOpen: onOpen,
                          ),
                        ),
                      if (markerOrigin != null)
                        Positioned(
                          key: markerKey,
                          left: horizontalPadding + markerOrigin.dx + 7,
                          top: markerOrigin.dy - 56,
                          child: IgnorePointer(
                            child: Semantics(
                              image: true,
                              label:
                                  'Crown bearer at puzzle ${markerPosition!.round()}',
                              child: PixelKnightSprite(
                                animation:
                                    moving
                                        ? KnightAnimation.walk
                                        : KnightAnimation.bounce,
                                frame: moving ? walkFrame : null,
                                width: 44,
                                height: 66,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _PuzzleNode extends StatelessWidget {
  const _PuzzleNode({
    required this.puzzle,
    required this.controller,
    required this.arc,
    required this.onOpen,
  });

  final PuzzleDefinition puzzle;
  final AppController controller;
  final StoryArc arc;
  final ValueChanged<PuzzleDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    final boss = arc.bossForPuzzle(puzzle);
    final encounter = arc.encounterForPuzzle(puzzle);
    final record = controller.recordFor(puzzle.id);
    final canOpen = controller.canOpenPuzzle(puzzle);
    final current = controller.frontierPuzzleFor(arc)?.id == puzzle.id;
    final active = controller.hasActiveBoard(puzzle);
    final available =
        canOpen &&
        !current &&
        !active &&
        record.status != CompletionStatus.cleanSolved &&
        record.status != CompletionStatus.assistedSolved;
    final status =
        current && active
            ? 'current, in progress'
            : current
            ? 'current'
            : active
            ? 'in-progress replay'
            : available
            ? 'available'
            : switch (record.status) {
              CompletionStatus.cleanSolved => 'clean',
              CompletionStatus.assistedSolved => 'assisted',
              _ => 'locked',
            };
    final prerequisite = math.max(1, puzzle.order - 1);
    final nodeName =
        boss != null
            ? '${boss.name} chapter boss'
            : encounter != null
            ? 'Puzzle ${puzzle.order} with ${encounter.name} encounter'
            : 'Puzzle ${puzzle.order}';
    final explanation =
        canOpen
            ? '$nodeName, $status.'
            : '$nodeName, locked. Complete puzzle $prerequisite first.';
    final colors = Theme.of(context).colorScheme;
    final glyph =
        boss != null && !active && record.status == CompletionStatus.newPuzzle
            ? PixelGlyph.star
            : encounter != null &&
                !active &&
                record.status == CompletionStatus.newPuzzle
            ? PixelGlyph.challenge
            : active
            ? PixelGlyph.ellipsis
            : current
            ? PixelGlyph.arrowRight
            : available
            ? PixelGlyph.arrowRight
            : switch (record.status) {
              CompletionStatus.cleanSolved => PixelGlyph.crown,
              CompletionStatus.assistedSolved => PixelGlyph.star,
              _ => PixelGlyph.lock,
            };
    final fill =
        current
            ? colors.primary
            : active
            ? colors.surfaceContainerHigh
            : available
            ? colors.surfaceContainerHigh
            : record.status == CompletionStatus.cleanSolved
            ? colors.secondary
            : record.status == CompletionStatus.assistedSolved
            ? colors.tertiary
            : colors.surfaceContainerHighest;
    final foreground =
        current ||
                (!active &&
                    (record.status == CompletionStatus.cleanSolved ||
                        record.status == CompletionStatus.assistedSolved))
            ? colors.onPrimary
            : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: canOpen,
      label: explanation,
      child: Tooltip(
        message: explanation,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const PixelOrganicBorder.compact(),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .26),
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Material(
            color: fill,
            shape: PixelOrganicBorder.compact(
              side: BorderSide(
                color: current ? colors.secondary : colors.outlineVariant,
                width: current ? 4 : 2,
              ),
            ),
            child: InkWell(
              key: ValueKey('puzzle-node-${puzzle.order}'),
              onTap: canOpen ? () => onOpen(puzzle) : null,
              customBorder: const PixelOrganicBorder.compact(),
              child: SizedBox.square(
                dimension: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PixelIcon(
                      glyph,
                      color: foreground,
                      size: 16,
                      excludeFromSemantics: true,
                    ),
                    Text(
                      boss == null ? '${puzzle.order}' : 'BOSS',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: boss == null ? 12 : 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinalLandmark extends StatelessWidget {
  const _FinalLandmark({
    super.key,
    required this.controller,
    required this.arc,
    required this.reached,
  });

  final AppController controller;
  final StoryArc arc;
  final bool reached;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth * .56).clamp(210.0, 300.0);
        return SizedBox(
          height: height,
          child: Semantics(
            button: reached,
            enabled: reached,
            label:
                reached
                    ? '${arc.finaleScene.title}. Replay the finale.'
                    : '${arc.title} finale awaits. Complete puzzle ${arc.catalog.puzzles.last.order} to reach it.',
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: PixelOrganicBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                key: const ValueKey('final-landmark'),
                customBorder: const PixelOrganicBorder(),
                onTap:
                    reached
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => StorySceneScreen.finale(
                                  controller: controller,
                                  arc: arc,
                                ),
                          ),
                        )
                        : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: PixelLandscape(
                        chapter: arc.chapters.last,
                        brightness: Theme.of(context).brightness,
                        sceneKind:
                            reached
                                ? PixelSceneKind.finale
                                : PixelSceneKind.panorama,
                        placement: PixelArtPlacement.banner,
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x16080d20), Color(0xaa080d20)],
                          ),
                        ),
                      ),
                    ),
                    if (reached) ...[
                      Positioned(
                        left: constraints.maxWidth * .08,
                        bottom: 12,
                        child: const PixelKnightSprite(
                          animation: KnightAnimation.bounce,
                          loop: true,
                          width: 44,
                          height: 66,
                        ),
                      ),
                      Positioned(
                        right: constraints.maxWidth * .08,
                        bottom: 12,
                        child: const PixelQueenSprite(
                          width: 46,
                          height: 72,
                          faceLeft: true,
                        ),
                      ),
                    ],
                    Positioned(
                      left: 14,
                      right: 14,
                      top: 14,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: .92),
                          shape: PixelOrganicBorder(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PixelIcon(
                                reached ? PixelGlyph.crown : PixelGlyph.lock,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 24,
                                excludeFromSemantics: true,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  reached
                                      ? arc.finaleScene.title
                                      : 'Finale awaits',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _RouteLayout {
  _RouteLayout({
    required this.width,
    required this.count,
    required this.columns,
  }) {
    final rows = (count / columns).ceil();
    const nodeSize = 56.0;
    const top = 132.0;
    const rowGap = 88.0;
    final gap = columns == 1 ? 0.0 : (width - nodeSize) / (columns - 1);
    for (var index = 0; index < count; index++) {
      final row = index ~/ columns;
      final logicalColumn = index % columns;
      final column = row.isEven ? logicalColumn : columns - 1 - logicalColumn;
      final origin = Offset(column * gap, top + row * rowGap);
      origins.add(origin);
      points.add(origin + const Offset(nodeSize / 2, nodeSize / 2));
    }
    height = top + rows * rowGap + 8;
  }

  final double width;
  final int count;
  final int columns;
  final List<Offset> origins = [];
  final List<Offset> points = [];
  late final double height;
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint =
        Paint()
          ..color = color.withValues(alpha: .48)
          ..isAntiAlias = false;
    for (var index = 1; index < points.length; index++) {
      final from = points[index - 1];
      final to = points[index];
      if ((from.dy - to.dy).abs() < 1) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(from.dx, to.dx),
            from.dy - 4,
            math.max(from.dx, to.dx),
            from.dy + 4,
          ),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
            from.dx - 4,
            math.min(from.dy, to.dy),
            from.dx + 4,
            math.max(from.dy, to.dy),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
