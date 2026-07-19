import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The complete encounter-introduction timeline.
///
/// Entrance, hold, and exit are parts of one deadline. This keeps the default
/// presentation at two seconds total instead of adding transitions around a
/// two-second hold.
@immutable
class EncounterCutsceneTiming {
  const EncounterCutsceneTiming({
    this.entrance = const Duration(milliseconds: 450),
    this.hold = const Duration(milliseconds: 1050),
    this.exit = const Duration(milliseconds: 500),
    this.reducedMotion = const Duration(milliseconds: 240),
  });

  static const standard = EncounterCutsceneTiming();

  final Duration entrance;
  final Duration hold;
  final Duration exit;

  /// A brief static title card replaces the moving presentation when motion
  /// reduction is enabled, so accessibility settings never add a two-second
  /// input delay.
  final Duration reducedMotion;

  Duration get total => entrance + hold + exit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncounterCutsceneTiming &&
          other.entrance == entrance &&
          other.hold == hold &&
          other.exit == exit &&
          other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(entrance, hold, exit, reducedMotion);
}

/// Full-screen, reusable battle introduction with configurable art and timing.
///
/// [background] is the only blurred layer. The supplied [knightArt] and
/// [enemyArt] remain crisp and can be sprites, illustrations, or test doubles.
class EncounterCutscene extends StatefulWidget {
  const EncounterCutscene({
    super.key,
    required this.background,
    required this.knightArt,
    required this.enemyArt,
    required this.enemyName,
    required this.onFinished,
    this.knightName = 'CROWN-BEARER',
    this.encounterLabel = 'ENEMY ENCOUNTER',
    this.timing = EncounterCutsceneTiming.standard,
    this.accentColor,
    this.energyColor,
  });

  final Widget background;
  final Widget knightArt;
  final Widget enemyArt;
  final String knightName;
  final String enemyName;
  final String encounterLabel;
  final EncounterCutsceneTiming timing;
  final Color? accentColor;
  final Color? energyColor;
  final VoidCallback onFinished;

  @override
  State<EncounterCutscene> createState() => _EncounterCutsceneState();
}

class _EncounterCutsceneState extends State<EncounterCutscene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_handleAnimationStatus);
  Timer? _deadline;
  bool _started = false;
  bool _reducedMotion = false;
  bool _completionDelivered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_started || reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _beginTimeline();
    }
  }

  @override
  void didUpdateWidget(EncounterCutscene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_completionDelivered && oldWidget.timing != widget.timing) {
      _beginTimeline();
    }
  }

  void _beginTimeline() {
    _started = true;
    _deadline?.cancel();
    _controller.stop();
    _controller.value = 0;
    final duration =
        _reducedMotion ? widget.timing.reducedMotion : widget.timing.total;
    if (duration == Duration.zero) {
      _controller.duration = const Duration(microseconds: 1);
      _deadline = Timer(Duration.zero, _deliverCompletion);
      return;
    }
    _controller.duration = duration;
    _deadline = Timer(duration, _deliverCompletion);
    _controller.forward();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _deliverCompletion();
  }

  void _deliverCompletion() {
    if (!mounted || _completionDelivered) return;
    _completionDelivered = true;
    _deadline?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? colors.secondary;
    final energy = widget.energyColor ?? colors.primary;
    return BlockSemantics(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        namesRoute: true,
        liveRegion: true,
        label:
            '${widget.encounterLabel}. ${widget.knightName} versus ${widget.enemyName}.',
        child: ExcludeSemantics(
          child: AbsorbPointer(
            child: Material(
              key: const ValueKey('encounter-cutscene'),
              color: Colors.black,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _reducedMotion ? .52 : _controller.value;
                  return _EncounterCutsceneFrame(
                    progress: progress,
                    reducedMotion: _reducedMotion,
                    timing: widget.timing,
                    background: widget.background,
                    knightArt: widget.knightArt,
                    enemyArt: widget.enemyArt,
                    knightName: widget.knightName,
                    enemyName: widget.enemyName,
                    encounterLabel: widget.encounterLabel,
                    accent: accent,
                    energy: energy,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EncounterCutsceneFrame extends StatelessWidget {
  const _EncounterCutsceneFrame({
    required this.progress,
    required this.reducedMotion,
    required this.timing,
    required this.background,
    required this.knightArt,
    required this.enemyArt,
    required this.knightName,
    required this.enemyName,
    required this.encounterLabel,
    required this.accent,
    required this.energy,
  });

  final double progress;
  final bool reducedMotion;
  final EncounterCutsceneTiming timing;
  final Widget background;
  final Widget knightArt;
  final Widget enemyArt;
  final String knightName;
  final String enemyName;
  final String encounterLabel;
  final Color accent;
  final Color energy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final totalMicros = math.max(1, timing.total.inMicroseconds);
      final entranceEnd = timing.entrance.inMicroseconds / totalMicros;
      final exitStart =
          (timing.entrance + timing.hold).inMicroseconds / totalMicros;
      final entrance =
          reducedMotion
              ? 1.0
              : Curves.easeOutCubic.transform(
                _segmentProgress(progress, 0, entranceEnd),
              );
      final exit =
          reducedMotion
              ? 0.0
              : Curves.easeInCubic.transform(
                _segmentProgress(progress, exitStart, 1),
              );
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final halfHeight = height / 2;
      final backgroundMotion = reducedMotion ? 0.0 : progress;
      final panelOpacity = (entrance * (1 - exit * .88)).clamp(0.0, 1.0);
      final dividerOpacity = (entrance * (1 - exit)).clamp(0.0, 1.0);
      final curtainOpacity = math.max(1 - entrance, exit).clamp(0.0, 1.0);

      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: RepaintBoundary(
              child: ImageFiltered(
                key: const ValueKey('encounter-cutscene-blurred-background'),
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 7,
                  sigmaY: 7,
                  tileMode: ui.TileMode.clamp,
                ),
                child: Transform.translate(
                  key: const ValueKey('encounter-cutscene-background-motion'),
                  offset: Offset(
                    -18 + backgroundMotion * 36,
                    math.sin(backgroundMotion * math.pi * 2) * 8,
                  ),
                  child: Transform.scale(
                    scale: 1.18,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        background,
                        CustomPaint(
                          painter: _EncounterEnergyPainter(
                            progress: backgroundMotion,
                            accent: accent,
                            energy: energy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const ColoredBox(color: Color(0x52000000)),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: halfHeight,
            child: ClipRect(
              child: Opacity(
                opacity: panelOpacity,
                child: Transform.translate(
                  offset: Offset(
                    (1 - entrance) * width * .72,
                    -exit * halfHeight,
                  ),
                  child: _EncounterCombatantPanel(
                    key: const ValueKey('encounter-cutscene-enemy-panel'),
                    artKey: const ValueKey('encounter-cutscene-enemy-art'),
                    art: enemyArt,
                    name: enemyName,
                    eyebrow: encounterLabel,
                    enemySide: true,
                    accent: accent,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: halfHeight,
            child: ClipRect(
              child: Opacity(
                opacity: panelOpacity,
                child: Transform.translate(
                  offset: Offset(
                    -(1 - entrance) * width * .72,
                    exit * halfHeight,
                  ),
                  child: _EncounterCombatantPanel(
                    key: const ValueKey('encounter-cutscene-knight-panel'),
                    artKey: const ValueKey('encounter-cutscene-knight-art'),
                    art: knightArt,
                    name: knightName,
                    eyebrow: 'THE REGALIA ANSWERS',
                    enemySide: false,
                    accent: accent,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: halfHeight - 2,
            height: 4,
            child: Opacity(
              opacity: dividerOpacity,
              child: ColoredBox(color: accent),
            ),
          ),
          Center(
            child: Opacity(
              opacity: dividerOpacity,
              child: Transform.scale(
                scale: .7 + entrance * .3,
                child: _VersusBadge(accent: accent),
              ),
            ),
          ),
          if (!reducedMotion && exit > 0 && exit < 1)
            ColoredBox(
              color: energy.withValues(alpha: math.sin(exit * math.pi) * .26),
            ),
          if (curtainOpacity > 0)
            ColoredBox(
              key: const ValueKey('encounter-cutscene-curtain'),
              color: Colors.black.withValues(alpha: curtainOpacity),
            ),
        ],
      );
    },
  );
}

class _EncounterCombatantPanel extends StatelessWidget {
  const _EncounterCombatantPanel({
    super.key,
    required this.artKey,
    required this.art,
    required this.name,
    required this.eyebrow,
    required this.enemySide,
    required this.accent,
  });

  final Key artKey;
  final Widget art;
  final String name;
  final String eyebrow;
  final bool enemySide;
  final Color accent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final artExtent = math
          .min(constraints.maxHeight * .78, constraints.maxWidth * .54)
          .clamp(104.0, 260.0);
      final textWidth = (constraints.maxWidth * .45).clamp(118.0, 260.0);
      final nameStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: .95,
        shadows: const [Shadow(color: Colors.black, offset: Offset(3, 3))],
      );
      final eyebrowStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
        shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2))],
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: enemySide ? Alignment.centerLeft : Alignment.centerRight,
            end: enemySide ? Alignment.centerRight : Alignment.centerLeft,
            colors: [const Color(0x9c080d20), accent.withValues(alpha: .17)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment:
                  enemySide
                      ? const Alignment(.72, .08)
                      : const Alignment(-.72, -.02),
              child: SizedBox.square(
                key: artKey,
                dimension: artExtent,
                child: FittedBox(fit: BoxFit.contain, child: art),
              ),
            ),
            Align(
              alignment:
                  enemySide
                      ? const Alignment(-.78, .08)
                      : const Alignment(.78, -.02),
              child: SizedBox(
                width: textWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      enemySide
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                  children: [
                    Text(
                      eyebrow,
                      maxLines: 2,
                      textAlign: enemySide ? TextAlign.left : TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: eyebrowStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 2,
                      textAlign: enemySide ? TextAlign.left : TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _VersusBadge extends StatelessWidget {
  const _VersusBadge({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('encounter-cutscene-versus'),
    width: 48,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xff080d20),
      border: Border.all(color: accent, width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0xaa000000), offset: Offset(4, 4)),
      ],
    ),
    child: Text(
      'VS',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

class _EncounterEnergyPainter extends CustomPainter {
  const _EncounterEnergyPainter({
    required this.progress,
    required this.accent,
    required this.energy,
  });

  final double progress;
  final Color accent;
  final Color energy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: .18),
            const Color(0x22080d20),
            energy.withValues(alpha: .12),
          ],
        ).createShader(Offset.zero & size),
    );

    final streak =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square
          ..strokeWidth = math.max(8, size.shortestSide * .035);
    final travel = size.width + size.height * .48;
    for (var index = 0; index < 12; index++) {
      final topHalf = index.isEven;
      final phase = (progress * (topHalf ? 1.8 : -1.55) + index * .137) % 1;
      final x = -size.height * .25 + phase * travel;
      final yBand = (index ~/ 2 + .5) / 6;
      final y =
          topHalf ? yBand * size.height * .5 : size.height * (.5 + yBand * .5);
      streak.color = (index % 3 == 0 ? energy : accent).withValues(
        alpha: index.isEven ? .19 : .13,
      );
      canvas.drawLine(
        Offset(x, y + size.height * .1),
        Offset(x + size.height * .3, y - size.height * .1),
        streak,
      );
    }
  }

  @override
  bool shouldRepaint(_EncounterEnergyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.energy != energy;
}

double _segmentProgress(double value, double start, double end) {
  if (end <= start) return value >= end ? 1 : 0;
  return ((value - start) / (end - start)).clamp(0.0, 1.0);
}

/// Keeps the destination out of the tree until the intro releases input.
///
/// This is useful for puzzle screens that start timers or request focus from
/// `initState`: neither side effect can begin during the encounter cutscene.
class EncounterCutsceneTransition extends StatefulWidget {
  const EncounterCutsceneTransition({
    super.key,
    required this.cutsceneBuilder,
    required this.destinationBuilder,
  });

  final Widget Function(BuildContext context, VoidCallback onFinished)
  cutsceneBuilder;
  final WidgetBuilder destinationBuilder;

  @override
  State<EncounterCutsceneTransition> createState() =>
      _EncounterCutsceneTransitionState();
}

class _EncounterCutsceneTransitionState
    extends State<EncounterCutsceneTransition> {
  bool _finished = false;

  void _finish() {
    if (!mounted || _finished) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) =>
      _finished
          ? KeyedSubtree(
            key: const ValueKey('encounter-cutscene-destination'),
            child: widget.destinationBuilder(context),
          )
          : widget.cutsceneBuilder(context, _finish);
}
