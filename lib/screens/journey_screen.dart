import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../app/branding.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../core/models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
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
    this.externalUrlLauncher,
  });

  final AppController controller;
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

  @override
  void initState() {
    super.initState();
    _displayedMarkerPosition =
        widget.controller.frontierPuzzle?.order.toDouble();
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
    final progress = widget.controller.journeyProgress;
    final chapter =
        progress.frontierPuzzle == null
            ? journeyChapters.last
            : chapterForOrder(progress.frontierPuzzle!.order);
    final reached = progress.completedCount >= chapter.startOrder - 1;
    if (reached && !widget.controller.hasSeenStoryBeat(chapter.storyBeatId)) {
      await _showChapter(chapter);
    }
  }

  Future<void> _openPuzzle(PuzzleDefinition puzzle) async {
    if (!widget.controller.openPuzzle(puzzle)) return;
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
            chapterForOrder(outcome.puzzle.order).id ==
                chapterForOrder(target.round()).id;
        setState(() {
          _walkFrame = step.isEven ? 0 : 1;
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
      if (!widget.controller.hasSeenStoryBeat(StoryBeatIds.finale)) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => StorySceneScreen.finale(controller: widget.controller),
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
            '${chapterForOrder(outcome.nextPuzzle!.order).title} · Puzzle ${outcome.nextPuzzle!.order}',
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

  Future<void> _showChapter(JourneyChapter chapter) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => StorySceneScreen.chapter(
                controller: widget.controller,
                chapter: chapter,
              ),
        ),
      );

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
    final progress = widget.controller.journeyProgress;
    final activeChapter =
        progress.frontierPuzzle == null
            ? journeyChapters.last
            : chapterForOrder(progress.frontierPuzzle!.order);
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
                  IconButton(
                    tooltip: 'How to play',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RulesScreen(),
                          ),
                        ),
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  IconButton(
                    key: const ValueKey('buy-me-a-coffee'),
                    tooltip: 'Support Queen’s Regalia',
                    onPressed: _openSupportPage,
                    icon: const Icon(Icons.local_cafe_outlined),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SettingsScreen(
                                  controller: widget.controller,
                                ),
                          ),
                        ),
                    icon: const Icon(Icons.settings_outlined),
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
                          progress: progress,
                          onContinue:
                              () => _openPuzzle(
                                widget.controller.recommendedPuzzle(),
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
                                for (final chapter in journeyChapters)
                                  _RouteSection(
                                    controller: widget.controller,
                                    chapter: chapter,
                                    markerPosition: _displayedMarkerPosition,
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
                                  reached: progress.isJourneyComplete,
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
                        child: Material(
                          color: Theme.of(context).colorScheme.inverseSurface,
                          child: InkWell(
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

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.controller,
    required this.progress,
    required this.onContinue,
    required this.onChallenge,
  });

  final AppController controller;
  final JourneyProgress progress;
  final VoidCallback onContinue;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    final target = controller.recommendedPuzzle();
    final title =
        progress.isJourneyComplete
            ? 'The realms remain open'
            : chapterForOrder(target.order).title;
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
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              ),
              boxShadow: [
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
                        '${progress.completedCount}/120',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (var segment = 0; segment < 12; segment++) ...[
                          Expanded(
                            child: ColoredBox(
                              color:
                                  progress.completedCount >= (segment + 1) * 10
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          if (segment < 11) const SizedBox(width: 2),
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
                    icon: PixelStatusIcon(
                      glyph: PixelStatusGlyph.arrow,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 18,
                    ),
                    label: Text(label),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('open-challenge-mode'),
                    onPressed: onChallenge,
                    icon: PixelStatusIcon(
                      glyph: PixelStatusGlyph.star,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 18,
                    ),
                    label: Text(
                      controller.hasChallenge
                          ? 'Resume challenge mode'
                          : 'Challenge mode',
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
    required this.chapter,
    required this.markerPosition,
    required this.walkFrame,
    required this.markerKey,
    required this.onOpen,
    required this.onLandmark,
  });

  final AppController controller;
  final JourneyChapter chapter;
  final double? markerPosition;
  final int walkFrame;
  final GlobalKey? markerKey;
  final ValueChanged<PuzzleDefinition> onOpen;
  final VoidCallback onLandmark;

  @override
  Widget build(BuildContext context) {
    final progress = controller.journeyProgress;
    final reached = progress.completedCount >= chapter.startOrder - 1;
    final puzzles =
        controller.catalog!.puzzles
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
                            shape: const RoundedRectangleBorder(
                              side: BorderSide(width: 3),
                            ),
                            child: InkWell(
                              key: ValueKey('landmark-${chapter.id}'),
                              onTap: reached ? onLandmark : null,
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
                                    PixelStatusIcon(
                                      glyph:
                                          reached
                                              ? PixelStatusGlyph.arrow
                                              : PixelStatusGlyph.lock,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      size: 26,
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
                                frame: walkFrame,
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
    required this.onOpen,
  });

  final PuzzleDefinition puzzle;
  final AppController controller;
  final ValueChanged<PuzzleDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    final record = controller.recordFor(puzzle.id);
    final canOpen = controller.canOpenPuzzle(puzzle);
    final current = controller.frontierPuzzle?.id == puzzle.id;
    final active = controller.hasActiveBoard(puzzle);
    final status =
        current && active
            ? 'current, in progress'
            : current
            ? 'current'
            : active
            ? 'in-progress replay'
            : switch (record.status) {
              CompletionStatus.cleanSolved => 'clean',
              CompletionStatus.assistedSolved => 'assisted',
              _ => 'locked',
            };
    final prerequisite = math.max(1, puzzle.order - 1);
    final explanation =
        canOpen
            ? 'Puzzle ${puzzle.order}, $status.'
            : 'Puzzle ${puzzle.order}, locked. Complete puzzle $prerequisite first.';
    final colors = Theme.of(context).colorScheme;
    final glyph =
        active
            ? PixelStatusGlyph.dots
            : current
            ? PixelStatusGlyph.arrow
            : switch (record.status) {
              CompletionStatus.cleanSolved => PixelStatusGlyph.crown,
              CompletionStatus.assistedSolved => PixelStatusGlyph.star,
              _ => PixelStatusGlyph.lock,
            };
    final fill =
        current
            ? colors.primary
            : active
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
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .26),
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: current ? colors.secondary : colors.outlineVariant,
                width: current ? 4 : 2,
              ),
            ),
            child: InkWell(
              key: ValueKey('puzzle-node-${puzzle.order}'),
              onTap: canOpen ? () => onOpen(puzzle) : null,
              child: SizedBox.square(
                dimension: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PixelStatusIcon(glyph: glyph, color: foreground, size: 18),
                    Text(
                      '${puzzle.order}',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
    required this.reached,
  });

  final AppController controller;
  final bool reached;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 250,
    child: Semantics(
      button: reached,
      enabled: reached,
      label:
          reached
              ? 'Dawn has returned to the realms. Replay the finale.'
              : 'The Queen waits in the Empyrean Citadel. Complete puzzle 120 to reach the Sky Throne.',
      child: InkWell(
        key: const ValueKey('final-landmark'),
        onTap:
            reached
                ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => StorySceneScreen.finale(controller: controller),
                  ),
                )
                : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: PixelLandscape(
                chapter: journeyChapters.last,
                brightness: Theme.of(context).brightness,
                sceneKind:
                    reached ? PixelSceneKind.finale : PixelSceneKind.panorama,
                placement: PixelArtPlacement.banner,
              ),
            ),
            if (reached) ...[
              const Positioned(
                left: 64,
                bottom: 25,
                child: PixelKnightSprite(width: 50, height: 75),
              ),
              const Positioned(
                right: 64,
                bottom: 25,
                child: PixelQueenSprite(width: 54, height: 84),
              ),
            ],
            Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .9),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelStatusIcon(
                    glyph:
                        reached
                            ? PixelStatusGlyph.crown
                            : PixelStatusGlyph.lock,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 25,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      reached ? 'The Dawn Returns' : 'The Sky Throne Awaits',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
