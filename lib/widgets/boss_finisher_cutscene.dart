import 'dart:async';

import 'package:flutter/material.dart';

import '../app/journey.dart';
import 'combat_presentation.dart';
import 'encounter_cutscene.dart';
import 'pixel_art.dart';

/// The authored move, effects tier, and complete deadline for one boss finish.
///
/// The factory deliberately derives all three from the chapter spectacle tier,
/// so later bosses gain a longer reveal, a longer move, and a stronger effect
/// without hard-coding chapter IDs into the presentation widget.
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
    return BossFinisherPresentation(
      spectacleLevel: level,
      finisher: finisher,
      specialMoveName: _specialMoveName(finisher),
      effectLevel: level,
      timing: EncounterCutsceneTiming(
        entrance: Duration(milliseconds: 160 + level * 15),
        hold:
            finisher.presentationDuration +
            finisher.postRoll +
            Duration(milliseconds: 180 + level * 28),
        exit: Duration(milliseconds: 240 + level * 20),
        reducedMotion: Duration(milliseconds: 240 + level * 15),
      ),
    );
  }

  final int spectacleLevel;
  final KnightAnimation finisher;
  final String specialMoveName;
  final EncounterCutsceneTiming timing;
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

/// A reusable, full-screen boss finisher built on the encounter composition.
///
/// Production callers can rely on the boss reaction atlas and knight finisher
/// atlas, while tests and future arcs can replace either sprite or the effects
/// layer without changing the cutscene timeline.
class BossFinisherCutscene extends StatefulWidget {
  BossFinisherCutscene({
    super.key,
    required this.boss,
    required this.background,
    required this.onFinished,
    BossFinisherPresentation? presentation,
    this.knightArt,
    this.bossArt,
    this.effects,
    this.accentColor,
    this.energyColor,
  }) : presentation =
           presentation ??
           BossFinisherPresentation.forSpectacle(boss.spectacleLevel);

  final ChapterBoss boss;
  final Widget background;
  final VoidCallback onFinished;
  final BossFinisherPresentation presentation;
  final Widget? knightArt;
  final Widget? bossArt;
  final Widget? effects;
  final Color? accentColor;
  final Color? energyColor;

  @override
  State<BossFinisherCutscene> createState() => _BossFinisherCutsceneState();
}

class _BossFinisherCutsceneState extends State<BossFinisherCutscene> {
  Timer? _attackTimer;
  bool _attackStarted = false;
  bool? _reducedMotion;
  int _restartToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reducedMotion != reducedMotion) {
      _reducedMotion = reducedMotion;
      _scheduleAttack();
    }
  }

  @override
  void didUpdateWidget(BossFinisherCutscene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation != widget.presentation ||
        oldWidget.boss.id != widget.boss.id) {
      _scheduleAttack();
    }
  }

  void _scheduleAttack() {
    _attackTimer?.cancel();
    _restartToken++;
    if (_reducedMotion == true ||
        widget.presentation.timing.entrance == Duration.zero) {
      _attackStarted = true;
      return;
    }
    _attackStarted = false;
    _attackTimer = Timer(widget.presentation.timing.entrance, () {
      if (!mounted) return;
      setState(() {
        _attackStarted = true;
        _restartToken++;
      });
    });
  }

  @override
  void dispose() {
    _attackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.presentation;
    final colors = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? colors.secondary;
    final energy = widget.energyColor ?? colors.primary;
    final stimulus =
        _attackStarted ? presentation.finisher : KnightAnimation.bounce;
    final knightArt =
        widget.knightArt ??
        PixelKnightSprite(
          key: const ValueKey('boss-finisher-knight-sprite'),
          animation: stimulus,
          frame: _attackStarted ? null : 0,
          restartToken: _restartToken,
          width: 220,
          height: 190,
        );
    final bossArt =
        widget.bossArt ??
        PixelEnemySprite(
          key: const ValueKey('boss-finisher-boss-sprite'),
          encounter: widget.boss,
          stimulus: stimulus,
          restartToken: _restartToken,
          width: 230,
          height: 210,
        );
    final effects =
        widget.effects ??
        CombatSpecialEffects(
          key: const ValueKey('boss-finisher-special-effects'),
          active: _attackStarted,
          duration: presentation.finisher.presentationDuration,
          level: presentation.effectLevel,
          restartToken: _restartToken,
          color: energy,
        );

    return KeyedSubtree(
      key: const ValueKey('boss-finisher-cutscene'),
      child: EncounterCutscene(
        background: widget.background,
        foreground: effects,
        knightArt: knightArt,
        enemyArt: bossArt,
        knightName: presentation.specialMoveName.toUpperCase(),
        enemyName: widget.boss.name,
        encounterLabel: 'BOSS FINISHER ${presentation.spectacleLevel} OF 8',
        knightEyebrow: 'REGALIA SPECIAL',
        enemyEyebrow: 'FINAL STAND',
        centerBadgeLabel: 'K.O.',
        semanticLabel:
            'Boss finisher. ${presentation.specialMoveName}. '
            '${widget.boss.name} is defeated.',
        timing: presentation.timing,
        accentColor: accent,
        energyColor: energy,
        onFinished: widget.onFinished,
      ),
    );
  }
}

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
