import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/journey.dart';
import 'combat_presentation.dart';
import 'pixel_art.dart';

/// The authored timing for the three-shot boss-finisher sequence.
@immutable
class BossFinisherTiming {
  const BossFinisherTiming({
    required this.finalMove,
    required this.panToBoss,
    required this.bossDefeat,
    required this.panToKnight,
    required this.victory,
    required this.exit,
    required this.reducedMotion,
  });

  final Duration finalMove;
  final Duration panToBoss;
  final Duration bossDefeat;
  final Duration panToKnight;
  final Duration victory;
  final Duration exit;

  /// A static victory card replaces the camera moves when motion is reduced.
  final Duration reducedMotion;

  Duration get bossDefeatStart => finalMove + panToBoss;
  Duration get panToKnightStart => bossDefeatStart + bossDefeat;
  Duration get victoryStart => panToKnightStart + panToKnight;
  Duration get exitStart => victoryStart + victory;
  Duration get total => exitStart + exit;

  BossFinisherPhase phaseAt(Duration elapsed) {
    if (elapsed < finalMove) return BossFinisherPhase.finalMove;
    if (elapsed < bossDefeatStart) return BossFinisherPhase.panToBoss;
    if (elapsed < panToKnightStart) return BossFinisherPhase.bossDefeat;
    if (elapsed < victoryStart) return BossFinisherPhase.panToKnight;
    return BossFinisherPhase.victory;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BossFinisherTiming &&
          other.finalMove == finalMove &&
          other.panToBoss == panToBoss &&
          other.bossDefeat == bossDefeat &&
          other.panToKnight == panToKnight &&
          other.victory == victory &&
          other.exit == exit &&
          other.reducedMotion == reducedMotion;

  @override
  int get hashCode => Object.hash(
    finalMove,
    panToBoss,
    bossDefeat,
    panToKnight,
    victory,
    exit,
    reducedMotion,
  );
}

enum BossFinisherPhase {
  finalMove,
  panToBoss,
  bossDefeat,
  panToKnight,
  victory,
}

/// The authored move, effects tier, and complete deadline for one boss finish.
///
/// Later bosses gain a longer move, more deliberate camera beats, and stronger
/// effects without hard-coding chapter IDs into the presentation widget.
@immutable
class BossFinisherPresentation {
  const BossFinisherPresentation({
    required this.spectacleLevel,
    required this.finisher,
    required this.specialMoveName,
    required this.timing,
    required this.effectLevel,
  }) : assert(spectacleLevel >= 1 && spectacleLevel <= 8),
       assert(effectLevel >= 1 && effectLevel <= 8);

  factory BossFinisherPresentation.forSpectacle(int spectacleLevel) {
    final level = spectacleLevel.clamp(1, 8);
    final finisher = finisherForSpectacle(level);
    return _forSelection(
      level: level,
      finisher: finisher,
      specialMoveName: _specialMoveName(finisher),
    );
  }

  factory BossFinisherPresentation.forEncounter(CombatEncounter encounter) {
    final style = encounter.finisherStyle;
    return _forSelection(
      level: style.effectLevel,
      finisher: finisherForTrack(style.track),
      specialMoveName: style.moveName,
    );
  }

  static BossFinisherPresentation _forSelection({
    required int level,
    required KnightAnimation finisher,
    required String specialMoveName,
  }) {
    final pan = Duration(milliseconds: 340 + level * 20);
    return BossFinisherPresentation(
      spectacleLevel: level,
      finisher: finisher,
      specialMoveName: specialMoveName,
      effectLevel: level,
      timing: BossFinisherTiming(
        finalMove:
            finisher.presentationDuration +
            Duration(milliseconds: 110 + level * 10),
        panToBoss: pan,
        bossDefeat:
            finisher.presentationDuration + const Duration(milliseconds: 120),
        panToKnight: pan,
        victory:
            KnightAnimation.special.presentationDuration +
            Duration(milliseconds: 170 + level * 10),
        exit: Duration(milliseconds: 200 + level * 12),
        reducedMotion: Duration(milliseconds: 260 + level * 14),
      ),
    );
  }

  final int spectacleLevel;
  final KnightAnimation finisher;
  final String specialMoveName;
  final BossFinisherTiming timing;
  final int effectLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BossFinisherPresentation &&
          other.spectacleLevel == spectacleLevel &&
          other.finisher == finisher &&
          other.specialMoveName == specialMoveName &&
          other.timing == timing &&
          other.effectLevel == effectLevel;

  @override
  int get hashCode => Object.hash(
    spectacleLevel,
    finisher,
    specialMoveName,
    timing,
    effectLevel,
  );
}

/// A full-screen, three-shot encounter victory.
///
/// The camera begins on the knight's complete special move, pans to the
/// opponent for its defeat animation, then returns to the knight's victory
/// stance. Only one combatant owns the screen at a time; this intentionally
/// does not reuse the split-screen encounter-introduction composition.
class BossFinisherCutscene extends StatefulWidget {
  BossFinisherCutscene({
    super.key,
    required this.boss,
    required this.background,
    required this.onFinished,
    BossFinisherPresentation? presentation,
    this.knightArt,
    this.victoryArt,
    this.bossArt,
    this.effects,
    this.accentColor,
    this.energyColor,
  }) : presentation =
           presentation ?? BossFinisherPresentation.forEncounter(boss);

  /// The defeated opponent. Regular chapter enemies use the same authored
  /// sequence as bosses, while their labels remain encounter-specific.
  final CombatEncounter boss;
  final Widget background;
  final VoidCallback onFinished;
  final BossFinisherPresentation presentation;
  final Widget? knightArt;
  final Widget? victoryArt;
  final Widget? bossArt;
  final Widget? effects;
  final Color? accentColor;
  final Color? energyColor;

  @override
  State<BossFinisherCutscene> createState() => _BossFinisherCutsceneState();
}

class _BossFinisherCutsceneState extends State<BossFinisherCutscene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener(_handleAnimationStatus);
  Timer? _deadline;
  bool _started = false;
  bool _reducedMotion = false;
  bool _completionDelivered = false;
  int _restartToken = 0;

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
  void didUpdateWidget(BossFinisherCutscene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_completionDelivered &&
        (oldWidget.presentation != widget.presentation ||
            oldWidget.boss.id != widget.boss.id)) {
      _beginTimeline();
    }
  }

  void _beginTimeline() {
    _started = true;
    _restartToken++;
    _deadline?.cancel();
    _controller.stop();
    _controller.value = 0;
    final duration =
        _reducedMotion
            ? widget.presentation.timing.reducedMotion
            : widget.presentation.timing.total;
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
            '${widget.boss.isBoss ? 'Boss finisher' : 'Encounter victory'}. '
            '${widget.presentation.specialMoveName}. '
            '${widget.boss.name} is defeated. The crown-bearer is victorious.',
        child: ExcludeSemantics(
          child: AbsorbPointer(
            child: Material(
              key: const ValueKey('boss-finisher-cutscene'),
              color: Colors.black,
              child: AnimatedBuilder(
                animation: _controller,
                builder:
                    (context, _) => _BossFinisherFrame(
                      progress: _controller.value,
                      reducedMotion: _reducedMotion,
                      presentation: widget.presentation,
                      boss: widget.boss,
                      background: widget.background,
                      knightArt: widget.knightArt,
                      victoryArt: widget.victoryArt,
                      bossArt: widget.bossArt,
                      effects: widget.effects,
                      accent: accent,
                      energy: energy,
                      restartToken: _restartToken,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BossFinisherFrame extends StatelessWidget {
  const _BossFinisherFrame({
    required this.progress,
    required this.reducedMotion,
    required this.presentation,
    required this.boss,
    required this.background,
    required this.knightArt,
    required this.victoryArt,
    required this.bossArt,
    required this.effects,
    required this.accent,
    required this.energy,
    required this.restartToken,
  });

  final double progress;
  final bool reducedMotion;
  final BossFinisherPresentation presentation;
  final CombatEncounter boss;
  final Widget background;
  final Widget? knightArt;
  final Widget? victoryArt;
  final Widget? bossArt;
  final Widget? effects;
  final Color accent;
  final Color energy;
  final int restartToken;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final timing = presentation.timing;
      final elapsed =
          reducedMotion
              ? timing.total
              : Duration(
                microseconds: (timing.total.inMicroseconds * progress).round(),
              );
      final phase =
          reducedMotion ? BossFinisherPhase.victory : timing.phaseAt(elapsed);
      final camera = reducedMotion ? 0.0 : _cameraPosition(phase, elapsed);
      final defeatProgress = _durationSegment(
        elapsed,
        timing.bossDefeatStart,
        timing.panToKnightStart,
      );
      final victoryProgress =
          reducedMotion
              ? 1.0
              : _durationSegment(
                elapsed,
                timing.victoryStart,
                timing.exitStart,
              );
      final isVictory = phase == BossFinisherPhase.victory;
      final bossDefeating =
          phase == BossFinisherPhase.bossDefeat ||
          phase == BossFinisherPhase.panToKnight ||
          isVictory;
      final effectsActive =
          !reducedMotion && phase == BossFinisherPhase.finalMove;
      final exitProgress =
          reducedMotion
              ? 0.0
              : _durationSegment(elapsed, timing.exitStart, timing.total);
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final defaultKnight = PixelKnightSprite(
        key: const ValueKey('boss-finisher-knight-sprite'),
        animation: isVictory ? KnightAnimation.special : presentation.finisher,
        restartToken: restartToken,
        // Legacy victory frames are wider than they are tall. This viewport
        // preserves their complete authored canvas before the outer shot fits
        // it to the available screen space.
        width: 420,
        height: 320,
      );
      final activeKnightArt =
          isVictory
              ? (victoryArt ?? defaultKnight)
              : (knightArt ?? defaultKnight);
      final activeBossArt =
          bossArt == null
              ? PixelEnemySprite(
                key: const ValueKey('boss-finisher-boss-sprite'),
                encounter: boss,
                stimulus:
                    bossDefeating
                        ? presentation.finisher
                        : KnightAnimation.bounce,
                frame:
                    bossDefeating
                        ? (defeatProgress * 4).floor().clamp(0, 3)
                        : 0,
                restartToken: restartToken,
                width: 310,
                height: 300,
              )
              : KeyedSubtree(
                // Animated custom art starts fresh when the camera arrives.
                key: ValueKey(
                  'boss-finisher-custom-boss-'
                  '${bossDefeating ? 'defeat' : 'waiting'}',
                ),
                child: bossArt!,
              );
      final activeEffects =
          effects ??
          CombatSpecialEffects(
            key: const ValueKey('boss-finisher-special-effects'),
            active: effectsActive,
            duration: presentation.finisher.presentationDuration,
            level: presentation.effectLevel,
            restartToken: restartToken,
            color: energy,
          );

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          ClipRect(
            child: ImageFiltered(
              key: const ValueKey('boss-finisher-blurred-background'),
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 3,
                sigmaY: 3,
                tileMode: ui.TileMode.clamp,
              ),
              child: Transform.translate(
                key: const ValueKey('boss-finisher-background-pan'),
                offset: Offset((.5 - camera) * width * .08, 0),
                child: Transform.scale(scale: 1.14, child: background),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x5c000000),
                  accent.withValues(alpha: .08),
                  const Color(0xb8080d20),
                ],
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('boss-finisher-knight-shot'),
            left: -camera * width,
            top: 0,
            width: width,
            height: height,
            child: _BossFinisherFocus(
              focusId: 'knight',
              art: activeKnightArt,
              eyebrow:
                  isVictory
                      ? 'VICTORY'
                      : boss.isBoss
                      ? 'REGALIA SPECIAL'
                      : 'ENCOUNTER SPECIAL',
              title:
                  isVictory
                      ? 'CROWN-BEARER'
                      : presentation.specialMoveName.toUpperCase(),
              footer: isVictory ? 'THE REGALIA ENDURES' : 'FINAL MOVE',
              accent: accent,
              energy: energy,
              emphasis: isVictory ? victoryProgress : 1,
              showVictoryAura: isVictory,
              labelOpacity: _focusLabelOpacity(1 - camera),
            ),
          ),
          Positioned(
            key: const ValueKey('boss-finisher-boss-shot'),
            left: (1 - camera) * width,
            top: 0,
            width: width,
            height: height,
            child: _BossFinisherFocus(
              focusId: 'opponent',
              art: activeBossArt,
              eyebrow:
                  boss.isBoss ? 'BOSS · FINAL STAND' : 'ENEMY · FINAL STAND',
              title: boss.name,
              footer:
                  defeatProgress >= .75 ? 'DEFEATED' : 'THE FINAL BLOW LANDS',
              accent: accent,
              energy: energy,
              emphasis: 1 - defeatProgress * .08,
              defeatedProgress: defeatProgress,
              labelOpacity: _focusLabelOpacity(camera),
            ),
          ),
          if (effectsActive)
            Positioned.fill(
              child: RepaintBoundary(
                key: const ValueKey('boss-finisher-effects-layer'),
                child: activeEffects,
              ),
            ),
          if (phase == BossFinisherPhase.bossDefeat &&
              defeatProgress > presentation.finisher.impactFraction)
            ColoredBox(
              key: const ValueKey('boss-finisher-impact-flash'),
              color: energy.withValues(
                alpha:
                    math.sin(
                      _durationSegment(
                            elapsed,
                            timing.bossDefeatStart +
                                presentation.finisher.presentationDuration *
                                    presentation.finisher.impactFraction,
                            timing.panToKnightStart,
                          ) *
                          math.pi,
                    ) *
                    .2,
              ),
            ),
          SizedBox.shrink(
            key: ValueKey('boss-finisher-phase-${_phaseSlug(phase)}'),
          ),
          if (exitProgress > 0)
            ColoredBox(
              key: const ValueKey('boss-finisher-exit-curtain'),
              color: Colors.black.withValues(
                alpha: Curves.easeInCubic.transform(exitProgress),
              ),
            ),
        ],
      );
    },
  );

  double _cameraPosition(BossFinisherPhase phase, Duration elapsed) =>
      switch (phase) {
        BossFinisherPhase.finalMove => 0,
        BossFinisherPhase.panToBoss => Curves.easeInOutCubic.transform(
          _durationSegment(
            elapsed,
            presentation.timing.finalMove,
            presentation.timing.bossDefeatStart,
          ),
        ),
        BossFinisherPhase.bossDefeat => 1,
        BossFinisherPhase.panToKnight =>
          1 -
              Curves.easeInOutCubic.transform(
                _durationSegment(
                  elapsed,
                  presentation.timing.panToKnightStart,
                  presentation.timing.victoryStart,
                ),
              ),
        BossFinisherPhase.victory => 0,
      };

  double _focusLabelOpacity(double cameraFocus) =>
      ((cameraFocus - .68) / .32).clamp(0.0, 1.0);
}

class _BossFinisherFocus extends StatelessWidget {
  const _BossFinisherFocus({
    required this.focusId,
    required this.art,
    required this.eyebrow,
    required this.title,
    required this.footer,
    required this.accent,
    required this.energy,
    required this.emphasis,
    required this.labelOpacity,
    this.showVictoryAura = false,
    this.defeatedProgress = 0,
  });

  final String focusId;
  final Widget art;
  final String eyebrow;
  final String title;
  final String footer;
  final Color accent;
  final Color energy;
  final double emphasis;
  final double labelOpacity;
  final bool showVictoryAura;
  final double defeatedProgress;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: .95,
        shadows: const [Shadow(color: Colors.black, offset: Offset(4, 4))],
      );
      final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: accent,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2))],
      );
      return SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            Opacity(
              opacity: labelOpacity,
              child: Text(
                eyebrow,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, artConstraints) {
                  // Leave room for the authored emphasis transform. Without
                  // this reserve, a scaled frame can reach the full-screen
                  // camera clip on short landscape viewports even though its
                  // untransformed layout box fits.
                  const maxArtScale = 1.08;
                  final availableExtent = math.min(
                    artConstraints.maxWidth * .94,
                    artConstraints.maxHeight * .98,
                  );
                  final artExtent = math.min(
                    availableExtent / maxArtScale,
                    560.0,
                  );
                  return Stack(
                    key: ValueKey('boss-finisher-$focusId-art-viewport'),
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      if (showVictoryAura)
                        Center(
                          child: Opacity(
                            opacity: emphasis.clamp(0.0, 1.0),
                            child: Container(
                              width: artExtent * 1.25,
                              height: artExtent * 1.25,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    energy.withValues(alpha: .28),
                                    accent.withValues(alpha: .1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: Transform.scale(
                          scale: emphasis.clamp(.82, 1.08),
                          child: SizedBox.square(
                            dimension: artExtent,
                            child: FittedBox(fit: BoxFit.contain, child: art),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Opacity(
              opacity: labelOpacity,
              child: DecoratedBox(
                key: ValueKey('boss-finisher-$focusId-caption'),
                decoration: BoxDecoration(
                  color: const Color(0xc7080d20),
                  border: Border.all(color: accent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xaa000000), offset: Offset(5, 5)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle?.copyWith(
                          color:
                              defeatedProgress > 0 ? energy : labelStyle.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

double _durationSegment(Duration value, Duration start, Duration end) {
  final span = end.inMicroseconds - start.inMicroseconds;
  if (span <= 0) return value >= end ? 1 : 0;
  return ((value.inMicroseconds - start.inMicroseconds) / span).clamp(0.0, 1.0);
}

String _phaseSlug(BossFinisherPhase phase) => switch (phase) {
  BossFinisherPhase.finalMove => 'final-move',
  BossFinisherPhase.panToBoss => 'pan-to-boss',
  BossFinisherPhase.bossDefeat => 'boss-defeat',
  BossFinisherPhase.panToKnight => 'pan-to-knight',
  BossFinisherPhase.victory => 'victory',
};

String _specialMoveName(KnightAnimation animation) => switch (animation) {
  KnightAnimation.crownSlash => 'Crown Slash',
  KnightAnimation.twinSigil => 'Twin Sigil',
  KnightAnimation.skybreak => 'Skybreak',
  KnightAnimation.tidalAegis => 'Tidal Aegis',
  KnightAnimation.cinderfall => 'Cinderfall',
  KnightAnimation.brassJudgment => 'Brass Judgment',
  KnightAnimation.moonlitSever => 'Moonlit Sever',
  KnightAnimation.regaliaNova => 'Regalia Nova',
  _ => 'Regalia Special',
};
