import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/journey.dart';
import 'pixel_art.dart';

enum EnemyReaction { idle, staggered, striking, pressing, exposed, defeated }

EnemyReaction enemyReactionFor(KnightAnimation animation) =>
    switch (animation) {
      KnightAnimation.walk || KnightAnimation.bounce => EnemyReaction.idle,
      KnightAnimation.attack => EnemyReaction.staggered,
      KnightAnimation.defend => EnemyReaction.striking,
      KnightAnimation.damage => EnemyReaction.pressing,
      KnightAnimation.surprised => EnemyReaction.exposed,
      KnightAnimation.special => EnemyReaction.defeated,
    };

extension on EnemyReaction {
  String get label => switch (this) {
    EnemyReaction.idle => 'WATCHING',
    EnemyReaction.staggered => 'STAGGERED',
    EnemyReaction.striking => 'STRIKES',
    EnemyReaction.pressing => 'PRESSES',
    EnemyReaction.exposed => 'EXPOSED',
    EnemyReaction.defeated => 'DEFEATED',
  };
}

/// Shared puzzle-header stage for the knight alone or an active encounter.
///
/// Enemy motion is derived entirely from the knight's current animation so the
/// two sprites cannot drift into independent combat timelines.
class CombatPresentationBar extends StatelessWidget {
  const CombatPresentationBar({
    super.key,
    required this.animation,
    required this.restartToken,
    required this.knightLine,
    required this.onKnightCompleted,
    this.encounter,
    this.onSkipEncounter,
  });

  final KnightAnimation animation;
  final int restartToken;
  final String knightLine;
  final VoidCallback onKnightCompleted;
  final CombatEncounter? encounter;
  final VoidCallback? onSkipEncounter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeEncounter = encounter;
    final reaction = enemyReactionFor(animation);
    final encounterDescription =
        activeEncounter == null
            ? ''
            : ' ${activeEncounter.isBoss ? 'Boss' : 'Optional enemy'} '
                '${activeEncounter.name}. Enemy ${reaction.label.toLowerCase()}. '
                '${activeEncounter.rewardLabel}.';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Knight companion. $knightLine$encounterDescription',
      child: Container(
        height: activeEncounter == null ? 66 : 86,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.secondary, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x77080d20), offset: Offset(4, 4)),
          ],
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (activeEncounter != null)
                CombatSpecialEffects(
                  key: const ValueKey('combat-special-effects'),
                  active: animation == KnightAnimation.special,
                  level: activeEncounter.spectacleLevel,
                  restartToken: restartToken,
                  color: colors.secondary,
                ),
              Row(
                children: [
                  SizedBox(
                    width: activeEncounter == null ? 106 : 84,
                    child: Center(
                      child: PixelKnightSprite(
                        key: const ValueKey('puzzle-knight-sprite'),
                        animation: animation,
                        loop: animation == KnightAnimation.bounce,
                        restartToken: restartToken,
                        onCompleted: onKnightCompleted,
                        width: activeEncounter == null ? 92 : 80,
                        height: activeEncounter == null ? 57 : 70,
                      ),
                    ),
                  ),
                  if (activeEncounter == null)
                    Expanded(child: _KnightStatus(line: knightLine))
                  else ...[
                    Expanded(
                      child: _EncounterStatus(
                        encounter: activeEncounter,
                        reaction: reaction,
                        onSkip: onSkipEncounter,
                      ),
                    ),
                    SizedBox(
                      width: 78,
                      child: Center(
                        child: PixelEnemySprite(
                          key: const ValueKey('puzzle-enemy-sprite'),
                          encounter: activeEncounter,
                          stimulus: animation,
                          restartToken: restartToken,
                          width: 74,
                          height: 76,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnightStatus extends StatelessWidget {
  const _KnightStatus({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CROWN-BEARER',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Flexible(
              child: Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.05),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncounterStatus extends StatelessWidget {
  const _EncounterStatus({
    required this.encounter,
    required this.reaction,
    this.onSkip,
  });

  final CombatEncounter encounter;
  final EnemyReaction reaction;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Text(
            encounter.isBoss
                ? 'BOSS · FINISH ${encounter.spectacleLevel}/8'
                : 'OPTIONAL · FLAIR ONLY',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.secondary,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ),
        ExcludeSemantics(
          child: Text(
            encounter.name,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  reaction.label,
                  key: const ValueKey('enemy-reaction-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        reaction == EnemyReaction.defeated
                            ? colors.primary
                            : colors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            if (encounter.skippable && onSkip != null) ...[
              const SizedBox(width: 4),
              SizedBox(
                height: 25,
                child: TextButton(
                  key: const ValueKey('skip-optional-encounter'),
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    minimumSize: const Size(38, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('LEAVE', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class PixelEnemySprite extends StatefulWidget {
  const PixelEnemySprite({
    super.key,
    required this.encounter,
    required this.stimulus,
    this.restartToken = 0,
    this.width = 72,
    this.height = 76,
  });

  final CombatEncounter encounter;
  final KnightAnimation stimulus;
  final int restartToken;
  final double width;
  final double height;

  @override
  State<PixelEnemySprite> createState() => _PixelEnemySpriteState();
}

class _PixelEnemySpriteState extends State<PixelEnemySprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _reduceMotion = false;

  EnemyReaction get _reaction => enemyReactionFor(widget.stimulus);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _restart();
  }

  @override
  void didUpdateWidget(PixelEnemySprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stimulus != widget.stimulus ||
        oldWidget.restartToken != widget.restartToken ||
        oldWidget.encounter.id != widget.encounter.id) {
      _restart();
    }
  }

  void _restart() {
    _controller
      ..stop()
      ..duration = _durationFor(widget.stimulus)
      ..value = 0;
    if (_reduceMotion) {
      _controller.value = _reaction == EnemyReaction.defeated ? 1 : .64;
    } else if (_reaction == EnemyReaction.idle) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pose = _enemyPose(_reaction, _controller.value);
          return Opacity(
            opacity: pose.opacity,
            child: Transform.translate(
              offset: pose.offset,
              child: Transform.rotate(
                angle: pose.rotation,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: pose.scale,
                  alignment: Alignment.bottomCenter,
                  child: CustomPaint(
                    painter: _PixelEnemyPainter(
                      family: widget.encounter.spriteFamily,
                      boss: widget.encounter.isBoss,
                      variant: _stableVariant(widget.encounter.id),
                      flash: pose.flash,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Duration _durationFor(KnightAnimation animation) => switch (animation) {
  KnightAnimation.walk => const Duration(milliseconds: 580),
  KnightAnimation.bounce => const Duration(milliseconds: 760),
  KnightAnimation.attack => const Duration(milliseconds: 500),
  KnightAnimation.defend => const Duration(milliseconds: 680),
  KnightAnimation.damage => const Duration(milliseconds: 620),
  KnightAnimation.special => const Duration(milliseconds: 720),
  KnightAnimation.surprised => const Duration(milliseconds: 740),
};

int _stableVariant(String id) =>
    id.codeUnits.fold<int>(0, (value, unit) => (value + unit) % 5);

class _EnemyPose {
  const _EnemyPose({
    this.offset = Offset.zero,
    this.rotation = 0,
    this.scale = 1,
    this.opacity = 1,
    this.flash = 0,
  });

  final Offset offset;
  final double rotation;
  final double scale;
  final double opacity;
  final double flash;
}

_EnemyPose _enemyPose(EnemyReaction reaction, double t) {
  final pulse = math.sin(t * math.pi);
  return switch (reaction) {
    EnemyReaction.idle => _EnemyPose(offset: Offset(0, -2 * pulse)),
    EnemyReaction.staggered => _EnemyPose(
      offset: Offset(13 * pulse, -3 * pulse),
      rotation: .16 * pulse,
      flash: pulse,
    ),
    EnemyReaction.striking => _EnemyPose(
      offset: Offset(-11 * pulse, -2 * pulse),
      rotation: -.1 * pulse,
      scale: 1 + .06 * pulse,
    ),
    EnemyReaction.pressing => _EnemyPose(
      offset: Offset(-6 * t, -3 * pulse),
      scale: 1 + .08 * pulse,
    ),
    EnemyReaction.exposed => _EnemyPose(
      offset: Offset(0, -9 * pulse),
      rotation: -.08 * pulse,
      flash: pulse * .35,
    ),
    EnemyReaction.defeated => _EnemyPose(
      offset: Offset(16 * t, 54 * math.pow(t, 2).toDouble()),
      rotation: math.pi * .48 * t,
      scale: 1 + .12 * math.sin(t * math.pi),
      opacity: (1 - ((t - .72) / .28).clamp(0, 1)).toDouble(),
      flash: math.sin(math.min(1, t * 2) * math.pi),
    ),
  };
}

class _EnemyPalette {
  const _EnemyPalette(this.dark, this.mid, this.light, this.accent);

  final Color dark;
  final Color mid;
  final Color light;
  final Color accent;
}

_EnemyPalette _palette(EnemySpriteFamily family) => switch (family) {
  EnemySpriteFamily.antlered => const _EnemyPalette(
    Color(0xff211d2e),
    Color(0xff76523d),
    Color(0xffd8b46b),
    Color(0xff9ce8dd),
  ),
  EnemySpriteFamily.rootbound => const _EnemyPalette(
    Color(0xff18291f),
    Color(0xff59472e),
    Color(0xff94a94e),
    Color(0xffd9e27c),
  ),
  EnemySpriteFamily.winged => const _EnemyPalette(
    Color(0xff1d203a),
    Color(0xff576b91),
    Color(0xffb7d6db),
    Color(0xffffc75e),
  ),
  EnemySpriteFamily.abyssal => const _EnemyPalette(
    Color(0xff102c36),
    Color(0xff26747b),
    Color(0xff75c6bd),
    Color(0xffff8da1),
  ),
  EnemySpriteFamily.volcanic => const _EnemyPalette(
    Color(0xff2b1720),
    Color(0xff733528),
    Color(0xffb85a30),
    Color(0xffffc247),
  ),
  EnemySpriteFamily.clockwork => const _EnemyPalette(
    Color(0xff26212b),
    Color(0xff77652f),
    Color(0xffc5a54a),
    Color(0xffb8e157),
  ),
  EnemySpriteFamily.spectral => const _EnemyPalette(
    Color(0xff20203f),
    Color(0xff5c5793),
    Color(0xffb9c7e9),
    Color(0xffe2adff),
  ),
  EnemySpriteFamily.cosmic => const _EnemyPalette(
    Color(0xff130f2d),
    Color(0xff453285),
    Color(0xff876ddd),
    Color(0xffffd76a),
  ),
};

class _PixelEnemyPainter extends CustomPainter {
  const _PixelEnemyPainter({
    required this.family,
    required this.boss,
    required this.variant,
    required this.flash,
  });

  final EnemySpriteFamily family;
  final bool boss;
  final int variant;
  final double flash;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 64, size.height / 72);
    final dx = (size.width - 64 * scale) / 2;
    final dy = size.height - 72 * scale;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);
    final palette = _palette(family);
    final dark = Paint()..color = palette.dark;
    final mid =
        Paint()..color = Color.lerp(palette.mid, Colors.white, flash * .55)!;
    final light =
        Paint()..color = Color.lerp(palette.light, Colors.white, flash * .8)!;
    final accent = Paint()..color = palette.accent;
    final shadow = Paint()..color = const Color(0x55000000);
    canvas.drawOval(const Rect.fromLTWH(8, 65, 50, 5), shadow);

    switch (family) {
      case EnemySpriteFamily.antlered:
        _paintAntlered(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.rootbound:
        _paintRootbound(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.winged:
        _paintWinged(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.abyssal:
        _paintAbyssal(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.volcanic:
        _paintVolcanic(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.clockwork:
        _paintClockwork(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.spectral:
        _paintSpectral(canvas, dark, mid, light, accent);
      case EnemySpriteFamily.cosmic:
        _paintCosmic(canvas, dark, mid, light, accent);
    }
    if (boss) _paintBossCrown(canvas, dark, accent);
    if (variant.isOdd) {
      canvas.drawRect(const Rect.fromLTWH(48, 43, 5, 5), accent);
    }
    canvas.restore();
  }

  void _paintAntlered(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    c.drawRect(const Rect.fromLTWH(16, 36, 35, 22), d);
    c.drawRect(const Rect.fromLTWH(20, 32, 28, 24), m);
    c.drawRect(const Rect.fromLTWH(12, 54, 8, 12), d);
    c.drawRect(const Rect.fromLTWH(43, 53, 8, 13), d);
    c.drawRect(const Rect.fromLTWH(5, 20, 25, 25), d);
    c.drawRect(const Rect.fromLTWH(9, 23, 19, 18), m);
    c.drawRect(const Rect.fromLTWH(8, 8, 4, 17), l);
    c.drawRect(const Rect.fromLTWH(2, 7, 10, 4), l);
    c.drawRect(const Rect.fromLTWH(25, 8, 4, 17), l);
    c.drawRect(const Rect.fromLTWH(25, 7, 10, 4), l);
    c.drawRect(const Rect.fromLTWH(12, 28, 4, 4), a);
  }

  void _paintRootbound(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    c.drawRect(const Rect.fromLTWH(18, 19, 30, 43), d);
    c.drawRect(const Rect.fromLTWH(22, 23, 22, 35), m);
    c.drawRect(const Rect.fromLTWH(7, 27, 15, 7), d);
    c.drawRect(const Rect.fromLTWH(44, 30, 15, 7), d);
    c.drawRect(const Rect.fromLTWH(15, 6, 6, 20), d);
    c.drawRect(const Rect.fromLTWH(44, 7, 6, 19), d);
    c.drawRect(const Rect.fromLTWH(10, 5, 13, 6), l);
    c.drawRect(const Rect.fromLTWH(43, 4, 13, 6), l);
    c.drawRect(const Rect.fromLTWH(25, 30, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(36, 30, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(13, 60, 15, 6), d);
    c.drawRect(const Rect.fromLTWH(39, 59, 15, 7), d);
  }

  void _paintWinged(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    final left =
        Path()..addPolygon(const [
          Offset(31, 26),
          Offset(3, 13),
          Offset(12, 47),
        ], true);
    final right =
        Path()..addPolygon(const [
          Offset(34, 26),
          Offset(61, 13),
          Offset(53, 47),
        ], true);
    c.drawPath(left, d);
    c.drawPath(right, d);
    c.drawPath(
      Path()..addPolygon(const [
        Offset(29, 28),
        Offset(8, 20),
        Offset(15, 40),
      ], true),
      l,
    );
    c.drawPath(
      Path()..addPolygon(const [
        Offset(35, 28),
        Offset(56, 20),
        Offset(50, 40),
      ], true),
      l,
    );
    c.drawRect(const Rect.fromLTWH(24, 22, 18, 36), d);
    c.drawRect(const Rect.fromLTWH(28, 25, 11, 29), m);
    c.drawRect(const Rect.fromLTWH(29, 27, 4, 4), a);
    c.drawRect(const Rect.fromLTWH(35, 27, 4, 4), a);
    c.drawRect(const Rect.fromLTWH(29, 55, 4, 11), d);
    c.drawRect(const Rect.fromLTWH(37, 55, 4, 11), d);
  }

  void _paintAbyssal(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    final bell =
        Path()..addPolygon(const [
          Offset(18, 17),
          Offset(45, 17),
          Offset(55, 52),
          Offset(8, 52),
        ], true);
    c.drawPath(bell, d);
    c.drawPath(
      Path()..addPolygon(const [
        Offset(22, 21),
        Offset(41, 21),
        Offset(48, 47),
        Offset(15, 47),
      ], true),
      m,
    );
    c.drawRect(const Rect.fromLTWH(13, 12, 38, 8), l);
    for (final x in const [12.0, 23.0, 34.0, 45.0]) {
      c.drawRect(Rect.fromLTWH(x, 48, 7, 17), d);
    }
    c.drawRect(const Rect.fromLTWH(24, 29, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(36, 29, 5, 5), a);
  }

  void _paintVolcanic(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    c.drawPath(
      Path()..addPolygon(const [
        Offset(7, 59),
        Offset(13, 24),
        Offset(25, 15),
        Offset(34, 23),
        Offset(47, 16),
        Offset(58, 59),
      ], true),
      d,
    );
    c.drawPath(
      Path()..addPolygon(const [
        Offset(14, 55),
        Offset(19, 29),
        Offset(29, 23),
        Offset(37, 30),
        Offset(45, 24),
        Offset(52, 55),
      ], true),
      m,
    );
    c.drawRect(const Rect.fromLTWH(4, 36, 13, 20), d);
    c.drawRect(const Rect.fromLTWH(49, 35, 13, 21), d);
    c.drawRect(const Rect.fromLTWH(23, 34, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(39, 34, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(29, 42, 5, 15), l);
    c.drawRect(const Rect.fromLTWH(34, 50, 12, 4), a);
  }

  void _paintClockwork(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    c.drawRect(const Rect.fromLTWH(13, 18, 42, 42), d);
    c.drawRect(const Rect.fromLTWH(18, 23, 32, 31), m);
    c.drawRect(const Rect.fromLTWH(5, 29, 11, 22), d);
    c.drawRect(const Rect.fromLTWH(52, 29, 10, 22), d);
    c.drawCircle(const Offset(34, 39), 10, l);
    c.drawCircle(const Offset(34, 39), 5, d);
    c.drawRect(const Rect.fromLTWH(22, 27, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(41, 27, 5, 5), a);
    c.drawRect(const Rect.fromLTWH(17, 57, 10, 9), d);
    c.drawRect(const Rect.fromLTWH(42, 57, 10, 9), d);
  }

  void _paintSpectral(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    final ghost =
        Path()..addPolygon(const [
          Offset(15, 61),
          Offset(19, 19),
          Offset(31, 9),
          Offset(45, 19),
          Offset(51, 61),
          Offset(43, 55),
          Offset(36, 64),
          Offset(29, 55),
          Offset(22, 64),
        ], true);
    c.drawPath(ghost, d);
    c.drawPath(
      Path()..addPolygon(const [
        Offset(21, 56),
        Offset(24, 23),
        Offset(32, 16),
        Offset(40, 23),
        Offset(45, 55),
        Offset(37, 49),
        Offset(31, 57),
      ], true),
      m,
    );
    c.drawRect(const Rect.fromLTWH(25, 29, 5, 6), a);
    c.drawRect(const Rect.fromLTWH(37, 29, 5, 6), a);
    c.drawRect(const Rect.fromLTWH(28, 40, 12, 4), l);
  }

  void _paintCosmic(Canvas c, Paint d, Paint m, Paint l, Paint a) {
    c.drawCircle(const Offset(33, 37), 26, d);
    c.drawCircle(const Offset(33, 37), 20, m);
    final star =
        Path()..addPolygon(const [
          Offset(33, 9),
          Offset(39, 28),
          Offset(57, 37),
          Offset(39, 44),
          Offset(33, 65),
          Offset(27, 44),
          Offset(8, 37),
          Offset(27, 28),
        ], true);
    c.drawPath(star, l);
    c.drawCircle(const Offset(33, 37), 9, d);
    c.drawRect(const Rect.fromLTWH(29, 33, 8, 8), a);
  }

  void _paintBossCrown(Canvas c, Paint d, Paint a) {
    c.drawRect(const Rect.fromLTWH(22, 2, 24, 6), d);
    c.drawPath(
      Path()..addPolygon(const [
        Offset(23, 4),
        Offset(27, -3),
        Offset(33, 4),
        Offset(39, -3),
        Offset(45, 4),
        Offset(44, 8),
        Offset(23, 8),
      ], true),
      a,
    );
  }

  @override
  bool shouldRepaint(_PixelEnemyPainter oldDelegate) =>
      oldDelegate.family != family ||
      oldDelegate.boss != boss ||
      oldDelegate.variant != variant ||
      oldDelegate.flash != flash;
}

class CombatSpecialEffects extends StatefulWidget {
  const CombatSpecialEffects({
    super.key,
    required this.active,
    required this.level,
    required this.restartToken,
    required this.color,
  });

  final bool active;
  final int level;
  final int restartToken;
  final Color color;

  @override
  State<CombatSpecialEffects> createState() => _CombatSpecialEffectsState();
}

class _CombatSpecialEffectsState extends State<CombatSpecialEffects>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(CombatSpecialEffects oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.restartToken != widget.restartToken ||
        oldWidget.level != widget.level) {
      _restart();
    }
  }

  void _restart() {
    _controller.stop();
    _controller.value = 0;
    if (!widget.active) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = .78;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => CustomPaint(
            painter: _SpecialEffectsPainter(
              progress: widget.active ? _controller.value : 0,
              level: widget.level,
              color: widget.color,
            ),
          ),
    ),
  );
}

class _SpecialEffectsPainter extends CustomPainter {
  const _SpecialEffectsPainter({
    required this.progress,
    required this.level,
    required this.color,
  });

  final double progress;
  final int level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final t = Curves.easeOutCubic.transform(progress);
    final center = Offset(size.width * .68, size.height * .5);
    final fade = (1 - progress).clamp(.12, 1).toDouble();
    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = level >= 6 ? 4 : 3
          ..color = color.withValues(alpha: fade);
    canvas.drawLine(
      Offset(size.width * (.25 + .25 * t), size.height * .82),
      Offset(size.width * (.55 + .35 * t), size.height * .12),
      stroke,
    );
    if (level >= 2) {
      canvas.drawLine(
        Offset(size.width * (.35 + .2 * t), size.height * .12),
        Offset(size.width * (.58 + .31 * t), size.height * .8),
        stroke..color = Colors.white.withValues(alpha: fade * .8),
      );
    }
    if (level >= 3) {
      final particle = Paint()..color = color.withValues(alpha: fade);
      for (var i = 0; i < level * 3; i++) {
        final angle = (i / (level * 3)) * math.pi * 2 + level * .37;
        final radius = (8 + (i % 4) * 5) * t;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final side = i.isEven ? 3.0 : 2.0;
        canvas.drawRect(
          Rect.fromCenter(center: point, width: side, height: side),
          particle,
        );
      }
    }
    if (level >= 4) {
      canvas.drawCircle(
        center,
        7 + t * (12 + level * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: fade * .6),
      );
    }
    if (level >= 5) {
      final ray =
          Paint()
            ..strokeWidth = 2
            ..color = color.withValues(alpha: fade * .55);
      for (var i = 0; i < level - 2; i++) {
        final x = size.width * ((i + 1) / level);
        canvas.drawLine(Offset(x, 0), Offset(center.dx, center.dy), ray);
      }
    }
    if (level >= 7) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Colors.white.withValues(alpha: fade * .08 * (level - 6)),
      );
    }
    if (level == 8) {
      canvas.drawCircle(
        center,
        5 + 18 * t,
        Paint()..color = const Color(0xff130f2d).withValues(alpha: fade * .75),
      );
      canvas.drawCircle(
        center,
        10 + 25 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = const Color(0xffffd76a).withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_SpecialEffectsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.level != level ||
      oldDelegate.color != color;
}
