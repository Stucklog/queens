import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/challenge.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../core/models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';
import 'game_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  bool _playing = false;
  bool _advancing = false;

  Future<void> _start(ChallengeMode mode) async {
    final started = await widget.controller.startChallenge(mode);
    if (started && mounted) await _playLoop();
  }

  Future<void> _playLoop() async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      while (mounted) {
        var session = widget.controller.challengeSession;
        if (session == null) return;
        if (session.currentCompleted) {
          setState(() => _advancing = true);
          final next = await widget.controller.advanceChallenge();
          if (!mounted) return;
          setState(() => _advancing = false);
          if (next == null) {
            _generationMessage();
            return;
          }
          session = widget.controller.challengeSession!;
        }
        if (!widget.controller.openChallengePuzzle()) return;
        final outcome = await Navigator.of(
          context,
        ).push<PuzzleCompletionOutcome>(
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  controller: widget.controller,
                  puzzle: session!.currentPuzzle,
                  playMode: PuzzlePlayMode.challenge,
                  challengeNumber: session.currentNumber,
                ),
          ),
        );
        if (!mounted || outcome?.isChallenge != true) return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _playing = false;
          _advancing = false;
        });
      }
    }
  }

  void _generationMessage() {
    final error = widget.controller.challengeGenerationError;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error == null
                ? 'The next board is still being prepared.'
                : 'The next board could not be prepared. Tap again to retry.',
          ),
        ),
      );
  }

  Future<void> _newRun(ChallengeMode mode) async {
    final replace = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'Begin a new Just Puzzle! run?',
            title: const Text('Begin a new Just Puzzle! run?'),
            content: const Text(
              'The current board and Just Puzzle! run statistics will be replaced.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep this run'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('New run'),
              ),
            ],
          ),
    );
    if ((replace ?? false) && mounted) await _start(mode);
  }

  Future<void> _endRun() async {
    final end = await showDialog<bool>(
      context: context,
      builder:
          (context) => PixelDialog(
            semanticLabel: 'End this Just Puzzle! run?',
            title: const Text('End this Just Puzzle! run?'),
            content: const Text(
              'The generated board and statistics for this run will be cleared.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep playing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End run'),
              ),
            ],
          ),
    );
    if ((end ?? false) && mounted) await widget.controller.abandonChallenge();
  }

  @override
  Widget build(BuildContext context) {
    if (_playing) return _content(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final session = widget.controller.challengeSession;
    final chapter =
        session == null
            ? widget.controller.challengeVisualChapter(DifficultyTier.easy, 1)
            : widget.controller.challengeVisualChapter(
              session.currentPuzzle.tier,
              session.currentNumber,
            );
    return Theme(
      data: RegaliaTheme.forChapter(chapter),
      child: Builder(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                leading: const PixelBackButton(),
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CrownMark(size: 24),
                    SizedBox(width: 8),
                    Text('JUST PUZZLE!'),
                  ],
                ),
              ),
              body: SafeArea(
                child:
                    session == null
                        ? _ChallengeSetup(
                          controller: widget.controller,
                          onStart: _start,
                        )
                        : _ChallengeRun(
                          controller: widget.controller,
                          session: session,
                          chapter: chapter,
                          advancing: _advancing,
                          onPlay: _playLoop,
                          onNewRun: _newRun,
                          onEndRun: _endRun,
                        ),
              ),
            ),
      ),
    );
  }
}

class _ChallengeSetup extends StatelessWidget {
  const _ChallengeSetup({required this.controller, required this.onStart});

  final AppController controller;
  final ValueChanged<ChallengeMode> onStart;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
    children: [
      SizedBox(
        height: 190,
        child: PixelStoryScene(
          chapter: controller.challengeVisualChapter(DifficultyTier.easy, 1),
          kind: PixelSceneKind.panorama,
          placement: PixelArtPlacement.banner,
          semanticLabel:
              'The Regalia bearer stands before an endless road of shifting trials.',
        ),
      ),
      const SizedBox(height: 26),
      Text(
        'The Endless Crucible',
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose a difficulty. Every board is generated and verified on this device, then the next waits behind it.',
        textAlign: TextAlign.center,
      ),
      if (controller.isStartingChallenge) ...[
        const SizedBox(height: 22),
        const PixelProgressBar(semanticLabel: 'Forging the first board'),
        const SizedBox(height: 10),
        const Text('Forging the first board…', textAlign: TextAlign.center),
      ],
      if (controller.challengeGenerationError != null) ...[
        const SizedBox(height: 16),
        Text(
          'That board could not be generated. Choose a difficulty to try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 18),
      for (final mode in ChallengeMode.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ModeButton(
            mode: mode,
            enabled: !controller.isStartingChallenge,
            onPressed: () => onStart(mode),
          ),
        ),
    ],
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.enabled,
    required this.onPressed,
  });

  final ChallengeMode mode;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey('challenge-mode-${mode.name}'),
    onPressed: enabled ? onPressed : null,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      alignment: Alignment.centerLeft,
    ),
    child: Row(
      children: [
        PixelIcon(
          switch (mode) {
            ChallengeMode.mixed => PixelGlyph.star,
            _ => PixelGlyph.crown,
          },
          color: Theme.of(context).colorScheme.secondary,
          size: 32,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.label, style: Theme.of(context).textTheme.titleMedium),
              Text(mode.description),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PixelIcon(
          PixelGlyph.arrowRight,
          color: Theme.of(context).colorScheme.onSurface,
          size: 24,
          excludeFromSemantics: true,
        ),
      ],
    ),
  );
}

class _ChallengeRun extends StatelessWidget {
  const _ChallengeRun({
    required this.controller,
    required this.session,
    required this.chapter,
    required this.advancing,
    required this.onPlay,
    required this.onNewRun,
    required this.onEndRun,
  });

  final AppController controller;
  final ChallengeSession session;
  final JourneyChapter chapter;
  final bool advancing;
  final VoidCallback onPlay;
  final ValueChanged<ChallengeMode> onNewRun;
  final VoidCallback onEndRun;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
    children: [
      SizedBox(
        height: 190,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: PixelOrganicBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              ),
            ),
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: PixelOrganicBorder()),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PixelLandscape(
                  chapter: chapter,
                  brightness: Theme.of(context).brightness,
                  placement: PixelArtPlacement.banner,
                ),
                const Align(
                  alignment: Alignment(-.58, .72),
                  child: PixelKnightSprite(
                    animation: KnightAnimation.bounce,
                    width: 72,
                    height: 108,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _Stat(label: 'RUN', value: '${session.completedCount}'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(label: 'CLEAN', value: '${session.cleanCount}'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(label: 'ASSISTED', value: '${session.assistedCount}'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
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
              color: Colors.black.withValues(alpha: .2),
              offset: const Offset(5, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Just Puzzle! ${session.currentNumber}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${session.mode.difficultyLabelFor(session.currentPuzzle.tier)} · ${session.currentPuzzle.size} × ${session.currentPuzzle.size} · ${session.mode.label} run',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey('play-challenge'),
              onPressed:
                  controller.isStartingChallenge ||
                          advancing ||
                          (session.currentCompleted &&
                              session.queuedPuzzle == null &&
                              controller.isPreparingChallenge)
                      ? null
                      : onPlay,
              icon: PixelIcon(
                PixelGlyph.arrowRight,
                color: Theme.of(context).colorScheme.onSecondary,
                size: 24,
                excludeFromSemantics: true,
              ),
              label: Text(
                session.currentCompleted
                    ? 'Next puzzle'
                    : session.board.cells.every(
                      (cell) => cell == ManualCellState.empty,
                    )
                    ? 'Play puzzle'
                    : 'Continue puzzle',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (controller.isStartingChallenge) ...[
        const PixelProgressBar(semanticLabel: 'Forging the new puzzle run'),
        const SizedBox(height: 10),
        const Text('Forging the new run without interrupting this one…'),
        const SizedBox(height: 18),
      ],
      Row(
        children: [
          PixelIcon(
            switch (session.queuedPuzzle) {
              null => PixelGlyph.ellipsis,
              _ => PixelGlyph.crown,
            },
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.preparedPuzzles.length ==
                      ChallengeSession.preparedCapacity
                  ? 'Two verified boards are ready.'
                  : session.queuedPuzzle != null &&
                      controller.isPreparingChallenge
                  ? 'The next board is ready while another is prepared.'
                  : session.queuedPuzzle != null
                  ? 'The next verified board is ready.'
                  : controller.challengeGenerationError != null
                  ? 'The next board needs another generation attempt.'
                  : 'Preparing the next verified board…',
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        'Start a different run',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in ChallengeMode.values)
            OutlinedButton(
              onPressed:
                  controller.isStartingChallenge ? null : () => onNewRun(mode),
              child: Text(mode.label),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: controller.isStartingChallenge ? null : onEndRun,
        child: const Text('End this run'),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: PixelOrganicBorder.compact(
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface,
          width: 2,
        ),
      ),
    ),
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
