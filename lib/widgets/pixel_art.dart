import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/journey.dart';

enum PixelSceneKind { panorama, opening, chapter, finale }

enum PixelStatusGlyph { lock, crown, star, arrow, dots }

class PixelStoryScene extends StatefulWidget {
  const PixelStoryScene({
    super.key,
    required this.chapter,
    required this.kind,
    required this.semanticLabel,
  });

  final JourneyChapter chapter;
  final PixelSceneKind kind;
  final String semanticLabel;

  @override
  State<PixelStoryScene> createState() => _PixelStorySceneState();
}

class _PixelStorySceneState extends State<PixelStoryScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final frame = still ? 0 : (_animation.value * 6).floor() % 6;
            return DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .22),
                    offset: const Offset(6, 6),
                  ),
                ],
              ),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: PixelLandscapePainter(
                        chapter: widget.chapter,
                        brightness: Theme.of(context).brightness,
                        sceneKind: widget.kind,
                        frame: frame,
                      ),
                    ),
                    if (widget.kind == PixelSceneKind.opening) ...[
                      Align(
                        alignment: const Alignment(-.48, .62),
                        child: PixelKnightSprite(
                          frame: frame,
                          width: 92,
                          height: 138,
                        ),
                      ),
                    ] else if (widget.kind == PixelSceneKind.finale) ...[
                      Align(
                        alignment: const Alignment(-.42, .65),
                        child: PixelKnightSprite(
                          frame: frame,
                          width: 82,
                          height: 123,
                        ),
                      ),
                      Align(
                        alignment: const Alignment(.34, .55),
                        child: PixelQueenSprite(
                          frame: frame,
                          width: 92,
                          height: 145,
                        ),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment(
                          -.58 + (frame.isEven ? 0 : .025),
                          .7,
                        ),
                        child: PixelKnightSprite(
                          frame: frame,
                          width: 72,
                          height: 108,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PixelLandscapePainter extends CustomPainter {
  const PixelLandscapePainter({
    required this.chapter,
    required this.brightness,
    this.sceneKind = PixelSceneKind.panorama,
    this.frame = 0,
  });

  final JourneyChapter chapter;
  final Brightness brightness;
  final PixelSceneKind sceneKind;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final index = journeyChapters.indexOf(chapter).clamp(0, 7);
    final dark = brightness == Brightness.dark;
    final background = chapter.palette.background(brightness);
    final surface = chapter.palette.surface(brightness);
    final skyTop =
        Color.lerp(background, dark ? Colors.black : Colors.white, .28)!;
    final skyLow =
        Color.lerp(background, chapter.palette.secondary, dark ? .12 : .08)!;
    final far =
        Color.lerp(chapter.palette.primary, background, dark ? .42 : .58)!;
    final mid =
        Color.lerp(
          chapter.palette.primary,
          chapter.palette.secondary,
          dark ? .32 : .46,
        )!;
    final near =
        Color.lerp(chapter.palette.secondary, background, dark ? .25 : .44)!;
    final ink = dark ? const Color(0xffefe8d5) : const Color(0xff25231f);
    final grid = math.max(1.0, (size.shortestSide / 180).floorToDouble());
    final p = _PixelCanvas(canvas, size, grid);

    p.rect(0, 0, size.width, size.height, skyTop);
    for (var band = 0; band < 10; band++) {
      final y = size.height * band * .045;
      p.rect(
        0,
        y,
        size.width,
        size.height * .05,
        Color.lerp(skyTop, skyLow, band / 9)!,
      );
    }
    _skyDetails(p, dark: dark, far: far, ink: ink, seed: index);
    p.cell(0, 42, 100, 58, background);
    p.cell(0, 42, 100, 7, far);
    p.cell(0, 49, 100, 7, Color.lerp(far, mid, .55)!);
    p.cell(0, 56, 100, 9, mid);
    p.cell(0, 65, 100, 12, near);
    p.cell(0, 77, 100, 23, Color.lerp(near, background, .42)!);
    _dither(
      p,
      surface.withValues(alpha: dark ? .25 : .42),
      Color.lerp(mid, ink, dark ? .15 : .08)!.withValues(alpha: .28),
      index,
    );

    switch (index) {
      case 0:
        _clovermead(p, far, mid, near, ink);
      case 1:
        _whisperwood(p, far, mid, near, ink);
      case 2:
        _windmills(p, far, mid, near, ink);
      case 3:
        _cloister(p, far, mid, near, ink);
      case 4:
        _cavern(p, far, mid, near, ink);
      case 5:
        _underkeep(p, far, mid, near, ink);
      case 6:
        _catacombs(p, far, mid, near, ink);
      case 7:
        _crownspire(p, far, mid, near, ink);
    }

    if (sceneKind == PixelSceneKind.opening) {
      _crownWind(p, ink);
    } else if (sceneKind == PixelSceneKind.finale) {
      _celebration(p, ink);
    }
  }

  void _skyDetails(
    _PixelCanvas p, {
    required bool dark,
    required Color far,
    required Color ink,
    required int seed,
  }) {
    if (dark || seed >= 4) {
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 12; x++) {
          if ((x * 7 + y * 11 + seed) % 9 == 0) {
            final twinkle = frame == (x + y) % 6;
            p.cell(
              3 + x * 8.2,
              3 + y * 7.0,
              twinkle ? 1.2 : .65,
              twinkle ? 1.2 : .65,
              ink.withValues(alpha: twinkle ? .88 : .52),
            );
          }
        }
      }
    } else {
      for (final cloud in const [
        Offset(12, 13),
        Offset(60, 7),
        Offset(83, 25),
      ]) {
        final cloudColor = Color.lerp(far, Colors.white, .72)!;
        p.cell(cloud.dx, cloud.dy, 15, 2.4, cloudColor);
        p.cell(cloud.dx + 3, cloud.dy - 2, 8, 2.4, cloudColor);
        p.cell(cloud.dx + 6, cloud.dy - 3.5, 5, 2, cloudColor);
        p.cell(
          cloud.dx + 2,
          cloud.dy + 2.3,
          12,
          .8,
          far.withValues(alpha: .35),
        );
      }
    }
  }

  void _dither(_PixelCanvas p, Color light, Color shade, int seed) {
    for (var y = 0; y < 14; y++) {
      for (var x = 0; x < 18; x++) {
        final value = x * 3 + y * 5 + seed;
        if (value % 8 == 0) {
          p.cell(x * 5.8 + 1, y * 6.7 + 4, .7, .7, light);
        } else if (value % 13 == 0) {
          p.cell(x * 5.8 + 3, y * 6.7 + 2, .55, .55, shade);
        }
      }
    }
  }

  void _clovermead(
    _PixelCanvas p,
    Color far,
    Color mid,
    Color near,
    Color ink,
  ) {
    final cream =
        brightness == Brightness.dark
            ? const Color(0xffd9cfb8)
            : const Color(0xfffff3d2);
    p.cell(0, 38, 31, 5, far);
    p.cell(18, 35, 34, 8, far);
    p.cell(72, 36, 28, 7, far);
    p.cell(73, 19, 3.2, 33, Color.lerp(ink, mid, .25)!);
    p.cell(66, 20, 17, 2.2, ink);
    p.cell(72, 12, 2.2, 19, mid);
    p.cell(63, 21, 20, 2.2, mid);
    p.cell(70, 43, 9, 3, Color.lerp(near, ink, .3)!);
    p.cell(8, 51, 19, 10, cream);
    p.cell(6, 48, 23, 4, chapter.palette.secondary);
    p.cell(12, 56, 4, 5, mid);
    p.cell(20, 56, 3, 3, Color.lerp(ink, cream, .2)!);
    p.cell(12, 62, 17, 1, Color.lerp(ink, near, .4)!);
    for (final x in [7.0, 20.0, 36.0, 48.0, 58.0, 87.0, 95.0]) {
      final y = 69 + (x % 5);
      p.cell(x, y, .7, 3, Color.lerp(near, ink, .35)!);
      p.cell(x - 1, y, 1.2, 1.2, chapter.palette.secondary);
      p.cell(x + .7, y + .4, 1.1, 1.1, cream);
    }
    p.cell(43, 63, 8, 4, cream);
    p.cell(42, 65, 2, 3, ink);
    p.cell(50, 65, 2, 3, ink);
    p.cell(49, 62, 2, 1, ink);
    p.cell(3, 82, 94, 1, Color.lerp(near, ink, .22)!);
    for (var x = 5; x < 98; x += 10) {
      p.cell(x.toDouble(), 79, 1.2, 7, Color.lerp(mid, ink, .28)!);
    }
  }

  void _whisperwood(
    _PixelCanvas p,
    Color far,
    Color mid,
    Color near,
    Color ink,
  ) {
    final bark = Color.lerp(ink, chapter.palette.secondary, .28)!;
    for (final x in [3.0, 20.0, 70.0, 90.0]) {
      p.cell(x, 17, 6, 61, bark);
      p.cell(x + 1, 19, 1.2, 54, Color.lerp(bark, Colors.white, .2)!);
      p.cell(x + 4.5, 22, 1.2, 51, Color.lerp(bark, Colors.black, .28)!);
      p.cell(x - 9, 8, 25, 13, far);
      p.cell(x - 6, 2, 19, 12, mid);
      p.cell(x - 2, 0, 11, 10, near);
      p.cell(x + 5, 28, 9, 2, bark);
    }
    for (final x in [33.0, 57.0, 80.0]) {
      p.cell(x, 73, 2.2, 10, const Color(0xffefe0c8));
      p.cell(x + 1.4, 74, .6, 8, const Color(0xffaa8d74));
      p.cell(x - 4, 69, 11, 4, chapter.palette.secondary);
      p.cell(
        x - 2.5,
        68,
        8,
        1.2,
        Color.lerp(chapter.palette.secondary, Colors.white, .35)!,
      );
      p.cell(x - 2, 72, 1, 1, const Color(0xffffe2c2));
    }
    for (final glow in const [Offset(17, 42), Offset(49, 26), Offset(84, 39)]) {
      final shift = frame.isEven ? 0.0 : 1.2;
      p.cell(glow.dx + shift, glow.dy, 1, 1, const Color(0xffffe777));
      p.cell(
        glow.dx + shift - .8,
        glow.dy - .8,
        2.6,
        2.6,
        const Color(0x22ffe777),
      );
    }
    for (var x = 8; x < 100; x += 13) {
      p.cell(x.toDouble(), 87 - (x % 4), 1, 5, near);
      p.cell(x + 1.2, 84 - (x % 4), 2, 1, mid);
    }
  }

  void _windmills(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    p.cell(0, 39, 28, 8, far);
    p.cell(18, 34, 42, 13, mid);
    p.cell(55, 38, 45, 9, far);
    p.cell(8, 55, 84, 3, Color.lerp(near, ink, .22)!);
    p.cell(12, 58, 4, 18, Color.lerp(near, ink, .35)!);
    p.cell(84, 58, 4, 18, Color.lerp(near, ink, .35)!);
    p.cell(47, 23, 9, 35, const Color(0xffeee4cf));
    p.cell(49, 27, 2, 30, const Color(0xffc5a98f));
    p.cell(45, 20, 13, 6, chapter.palette.secondary);
    p.cell(43, 19, 17, 2, Color.lerp(chapter.palette.secondary, ink, .38)!);
    final shift = frame.isOdd ? 1.0 : 0.0;
    p.cell(50 + shift, 10, 2, 31, ink);
    p.cell(37, 24 + shift, 29, 2, ink);
    p.cell(40, 13, 2, 24, mid);
    p.cell(61, 13, 2, 24, mid);
    p.cell(51, 38, 3, 7, Color.lerp(ink, mid, .35)!);
    for (final bird in const [Offset(16, 18), Offset(24, 15), Offset(78, 22)]) {
      p.cell(bird.dx, bird.dy, 2, .7, ink.withValues(alpha: .7));
      p.cell(bird.dx + 2, bird.dy - .7, 2, .7, ink.withValues(alpha: .7));
    }
    for (var x = 3; x < 100; x += 9) {
      p.cell(x.toDouble(), 79 + (x % 3), 5, 1, Color.lerp(near, mid, .4)!);
    }
  }

  void _cloister(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final stone = Color.lerp(far, ink, .28)!;
    p.cell(0, 69, 100, 31, chapter.palette.secondary.withValues(alpha: .72));
    p.cell(
      0,
      73,
      100,
      3,
      Color.lerp(chapter.palette.secondary, Colors.white, .22)!,
    );
    for (final x in [5.0, 35.0, 69.0]) {
      p.cell(x, 25, 5, 50, stone);
      p.cell(x + 1, 27, 1, 46, Color.lerp(stone, Colors.white, .18)!);
      p.cell(x + 20, 25, 5, 50, stone);
      p.cell(x + 23, 27, 1, 46, Color.lerp(stone, Colors.black, .2)!);
      p.cell(x + 4, 19, 17, 6, stone);
      p.cell(x + 7, 16, 11, 4, stone);
      p.cell(x + 9, 24, 7, 2, far);
      p.cell(x + 3, 35, 3, 2, mid);
    }
    for (var x = 0; x < 14; x++) {
      p.cell(x * 7.8, 79 + (x.isEven ? 0 : 3), 5, 1.2, near);
      p.cell(x * 7.8 + 2, 87 + (x.isEven ? 2 : 0), 7, .8, far);
    }
    for (final x in [15.0, 48.0, 88.0]) {
      p.cell(x, 64, 1, 12, Color.lerp(mid, ink, .2)!);
      p.cell(x - 2, 62, 3, 4, near);
      p.cell(x + 1, 60, 3, 5, near);
    }
  }

  void _cavern(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final rock = Color.lerp(chapter.palette.primary, Colors.black, .36)!;
    p.cell(0, 0, 100, 14, rock);
    for (final x in [2.0, 16.0, 31.0, 52.0, 72.0, 89.0]) {
      final length = 9 + (x % 5) * 2;
      p.cell(x, 12, 7, length, rock);
      p.cell(x + 1, 13, 2, length - 4, Color.lerp(rock, mid, .25)!);
      p.cell(x + 3, 12 + length, 2, 4, rock);
    }
    p.cell(0, 84, 100, 16, Color.lerp(rock, near, .25)!);
    for (final x in [10.0, 30.0, 61.0, 84.0]) {
      p.cell(x, 69, 7, 17, chapter.palette.secondary);
      p.cell(x + 1, 65, 4, 20, const Color(0xffffb347));
      p.cell(x + 2, 62, 2, 22, const Color(0xffffdf77));
      p.cell(x - 4, 78, 15, 6, near);
      p.cell(x + 1, 64, 1, 16, const Color(0xfffff0a6));
    }
    for (final bell in const [Offset(42, 43), Offset(74, 34)]) {
      p.cell(bell.dx, bell.dy, 9, 8, const Color(0xffc98b35));
      p.cell(bell.dx + 2, bell.dy - 3, 5, 4, const Color(0xffeab353));
      p.cell(bell.dx + 4, bell.dy + 7, 2, 3, ink);
      p.cell(
        bell.dx + 1,
        bell.dy + 6,
        7,
        2,
        Color.lerp(ink, const Color(0xffc98b35), .4)!,
      );
    }
    for (var x = 4; x < 100; x += 12) {
      p.cell(x.toDouble(), 54 + (x % 7), 4, 1, far.withValues(alpha: .7));
    }
  }

  void _underkeep(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final mortar = Color.lerp(far, Colors.black, .25)!;
    for (var y = 10; y < 90; y += 10) {
      p.cell(0, y.toDouble(), 100, 1.2, mortar);
      final offset = (y ~/ 10).isEven ? 0.0 : 7.0;
      for (var x = -7.0 + offset; x < 100; x += 14) {
        p.cell(x, y.toDouble(), 1.2, 10, mortar);
      }
    }
    p.cell(4, 18, 4, 64, Color.lerp(ink, mid, .35)!);
    p.cell(7, 20, 2, 60, chapter.palette.secondary);
    p.cell(91, 12, 4, 70, Color.lerp(ink, mid, .35)!);
    for (final center in [const Offset(28, 39), const Offset(76, 58)]) {
      final brass = const Color(0xffc7953f);
      p.cell(center.dx - 11, center.dy - 11, 22, 22, ink);
      p.cell(center.dx - 9, center.dy - 9, 18, 18, brass);
      p.cell(center.dx - 6, center.dy - 6, 12, 12, near);
      p.cell(center.dx - 3, center.dy - 3, 6, 6, ink);
      p.cell(center.dx - 1, center.dy - 1, 2, 2, brass);
      for (final tooth in const [
        Offset(0, -13),
        Offset(0, 11),
        Offset(-13, 0),
        Offset(11, 0),
      ]) {
        p.cell(center.dx + tooth.dx, center.dy + tooth.dy, 3, 3, brass);
      }
    }
    p.cell(40, 66, 19, 22, Color.lerp(ink, near, .18)!);
    p.cell(43, 69, 13, 19, Color.lerp(near, Colors.black, .32)!);
    p.cell(52, 77, 1.5, 2.5, chapter.palette.secondary);
    for (final x in [14.0, 63.0, 84.0]) {
      p.cell(x, 25, 6, 2, const Color(0xffd1a94c));
      p.cell(x + 2, 27, 2, 7, const Color(0xffffd565));
    }
  }

  void _catacombs(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    p.cell(73, 5, 14, 14, const Color(0xfff4efca));
    p.cell(79, 3, 10, 15, far);
    p.cell(74, 18, 13, 1, const Color(0xffc9c4ae));
    final stone = Color.lerp(far, ink, .2)!;
    for (final x in [2.0, 35.0, 69.0]) {
      p.cell(x, 30, 4, 48, stone);
      p.cell(x + 1, 32, 1, 43, Color.lerp(stone, Colors.white, .16)!);
      p.cell(x + 24, 30, 4, 48, stone);
      p.cell(x + 4, 23, 20, 7, stone);
      p.cell(x + 8, 19, 12, 5, stone);
      p.cell(x + 7, 31, 2, 2, mid);
    }
    for (final tomb in const [Offset(13, 58), Offset(45, 67), Offset(82, 53)]) {
      p.cell(tomb.dx, tomb.dy, 10, 13, const Color(0xffd9d8df));
      p.cell(tomb.dx + 2, tomb.dy - 3, 6, 4, const Color(0xffd9d8df));
      p.cell(tomb.dx + 4, tomb.dy + 3, 2, 6, Color.lerp(near, ink, .3)!);
      p.cell(tomb.dx + 2, tomb.dy + 5, 6, 2, Color.lerp(near, ink, .3)!);
    }
    for (final lantern in const [Offset(31, 41), Offset(65, 36)]) {
      p.cell(lantern.dx, lantern.dy, 5, 7, Color.lerp(ink, mid, .2)!);
      p.cell(lantern.dx + 1, lantern.dy + 1, 3, 4, const Color(0xffffdc7c));
      p.cell(lantern.dx + 2, lantern.dy - 4, 1, 4, ink);
      p.cell(lantern.dx - 1, lantern.dy - 4, 5, 1, ink);
    }
    for (final bat in const [Offset(18, 13), Offset(48, 10)]) {
      p.cell(bat.dx, bat.dy, 3, 1, ink);
      p.cell(bat.dx + 3, bat.dy + 1, 2, 1, ink);
      p.cell(bat.dx + 5, bat.dy, 3, 1, ink);
    }
  }

  void _crownspire(
    _PixelCanvas p,
    Color far,
    Color mid,
    Color near,
    Color ink,
  ) {
    const ivory = Color(0xfff3ead4);
    const shade = Color(0xffc9bea9);
    p.cell(54, 24, 38, 55, shade);
    p.cell(57, 20, 32, 59, ivory);
    p.cell(65, 7, 18, 72, shade);
    p.cell(68, 3, 12, 76, ivory);
    p.cell(63, 14, 22, 5, chapter.palette.secondary);
    p.cell(53, 25, 40, 4, chapter.palette.secondary);
    p.cell(58, 30, 30, 2, const Color(0xffffd66a));
    for (final x in [62.0, 76.0]) {
      p.cell(x, 38, 7, 15, far);
      p.cell(x + 1, 39, 2, 12, mid);
      p.cell(x + 5, 39, 1, 12, Color.lerp(far, Colors.black, .25)!);
      p.cell(x - 1, 36, 9, 2, chapter.palette.secondary);
    }
    p.cell(69, 58, 10, 21, Color.lerp(far, Colors.black, .28)!);
    p.cell(72, 61, 4, 18, mid);
    for (final y in [55.0, 62.0, 69.0, 76.0, 83.0]) {
      p.cell(31 + (y % 2), y, 39, 2, Color.lerp(ivory, shade, .45)!);
    }
    p.cell(9, 22, 3, 47, ink);
    p.cell(12, 26, 22, 15, const Color(0xffb2383b));
    p.cell(12, 26, 22, 2, const Color(0xffd85a55));
    p.cell(17, 31, 12, 3, const Color(0xffffd45a));
    p.cell(21, 29, 4, 8, chapter.palette.primary);
    for (final x in [4.0, 24.0, 42.0]) {
      p.cell(x, 43 + (x % 3), 12, 3, Color.lerp(far, Colors.white, .2)!);
      p.cell(x + 3, 41 + (x % 3), 7, 2, Color.lerp(far, Colors.white, .2)!);
    }
  }

  void _crownWind(_PixelCanvas p, Color ink) {
    final shift = frame.isEven ? 0.0 : 1.2;
    const gold = Color(0xffffd45a);
    const shadow = Color(0xffb68032);
    p.cell(44 + shift, 25, 2.2, 6, shadow);
    p.cell(50 + shift, 21, 2.2, 10, shadow);
    p.cell(56 + shift, 25, 2.2, 6, shadow);
    p.cell(45 + shift, 24, 1.2, 6, gold);
    p.cell(51 + shift, 20, 1.2, 10, gold);
    p.cell(57 + shift, 24, 1.2, 6, gold);
    p.cell(44 + shift, 29, 15, 4, gold);
    p.cell(46 + shift, 33, 11, 1.5, shadow);
    p.cell(62, 20, 4, 1, ink.withValues(alpha: .5));
    p.cell(68, 16, 8, 1, ink.withValues(alpha: .5));
    p.cell(64, 23, 7, .7, ink.withValues(alpha: .35));
  }

  void _celebration(_PixelCanvas p, Color ink) {
    for (var x = 5; x < 98; x += 8) {
      final y = 5 + ((x + frame * 3) % 28);
      p.cell(
        x.toDouble(),
        y.toDouble(),
        x.isEven ? 1.2 : .8,
        x.isEven ? 2.4 : 1.5,
        x.isEven ? ink : chapter.palette.secondary,
      );
    }
  }

  @override
  bool shouldRepaint(PixelLandscapePainter oldDelegate) =>
      oldDelegate.chapter != chapter ||
      oldDelegate.brightness != brightness ||
      oldDelegate.sceneKind != sceneKind ||
      oldDelegate.frame != frame;
}

class PixelKnightSprite extends StatelessWidget {
  const PixelKnightSprite({
    super.key,
    this.frame = 0,
    this.width = 48,
    this.height = 72,
  });

  final int frame;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _PixelKnightPainter(frame: frame)),
  );
}

class _PixelKnightPainter extends CustomPainter {
  const _PixelKnightPainter({required this.frame});
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _SpriteCanvas(canvas, size, 32, 48);
    const ink = Color(0xff292329);
    const skin = Color(0xffa96d4e);
    const skinLight = Color(0xffce8c66);
    const skinShadow = Color(0xff754534);
    const hair = Color(0xff4a2638);
    const hairLight = Color(0xff75405c);
    const steel = Color(0xffc3c9c6);
    const steelLight = Color(0xffedf0e8);
    const shadow = Color(0xff6f7778);
    const deepShadow = Color(0xff465052);
    const teal = Color(0xff276b6b);
    const tealLight = Color(0xff3f9290);
    const plum = Color(0xff713f67);
    const plumLight = Color(0xff9a5b89);
    const gold = Color(0xffffca45);
    const goldShadow = Color(0xffb68032);
    const goldLight = Color(0xffffe47b);
    final bob = frame == 1 || frame == 4 ? 1.0 : 0.0;
    final stride = switch (frame % 4) {
      1 => 2.0,
      3 => -2.0,
      _ => 0.0,
    };

    p.rect(10, 2 + bob, 13, 3, hair);
    p.rect(8, 5 + bob, 17, 6, hair);
    p.rect(9, 4 + bob, 7, 2, hairLight);
    p.rect(10, 7 + bob, 13, 11, ink);
    p.rect(11, 7 + bob, 11, 10, skin);
    p.rect(12, 8 + bob, 3, 8, skinLight);
    p.rect(20, 9 + bob, 2, 7, skinShadow);
    p.rect(18, 10 + bob, 2, 1, ink);
    p.rect(21, 6 + bob, 4, 5, hair);
    p.rect(13, 17 + bob, 7, 2, skinShadow);

    p.rect(7, 17 + bob, 19, 6, ink);
    p.rect(8, 17 + bob, 17, 5, steel);
    p.rect(10, 18 + bob, 8, 1, steelLight);
    p.rect(5, 21 + bob, 22, 17, ink);
    p.rect(7, 21 + bob, 18, 16, teal);
    p.rect(8, 22 + bob, 4, 14, tealLight);
    p.rect(21, 23 + bob, 3, 12, deepShadow);
    p.rect(3, 19 + bob, 6, 21, plum);
    p.rect(4, 20 + bob, 2, 18, plumLight);
    p.rect(24, 19 + bob, 5, 21, plum);
    p.rect(27, 22 + bob, 2, 16, Color.lerp(plum, ink, .35)!);
    p.rect(5, 34 + bob, 22, 4, steel);
    p.rect(7, 35 + bob, 18, 2, shadow);

    p.rect(12, 27 + bob, 10, 6, goldShadow);
    p.rect(12, 25 + bob, 2, 7, gold);
    p.rect(16, 23 + bob, 2, 9, gold);
    p.rect(20, 25 + bob, 2, 7, gold);
    p.rect(13, 28 + bob, 8, 3, gold);
    p.rect(14, 28 + bob, 5, 1, goldLight);
    p.rect(14, 33 + bob, 7, 1, goldShadow);
    p.rect(9, 29 + bob, 3, 3, skinLight);
    p.rect(22, 29 + bob, 3, 3, skin);

    p.rect(8 - stride, 38 + bob, 8, 7, ink);
    p.rect(9 - stride, 38 + bob, 6, 7, shadow);
    p.rect(10 - stride, 39 + bob, 2, 5, steelLight);
    p.rect(18 + stride, 38 + bob, 8, 7, ink);
    p.rect(19 + stride, 38 + bob, 6, 7, shadow);
    p.rect(20 + stride, 39 + bob, 2, 5, steelLight);
    p.rect(6 - stride, 44 + bob, 10, 3, ink);
    p.rect(18 + stride, 44 + bob, 10, 3, ink);
    p.rect(7 - stride, 44 + bob, 7, 1, deepShadow);
    p.rect(20 + stride, 44 + bob, 6, 1, deepShadow);
  }

  @override
  bool shouldRepaint(_PixelKnightPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

class PixelQueenSprite extends StatelessWidget {
  const PixelQueenSprite({
    super.key,
    this.frame = 0,
    this.width = 48,
    this.height = 76,
  });
  final int frame;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(painter: _PixelQueenPainter(frame)),
  );
}

class _PixelQueenPainter extends CustomPainter {
  const _PixelQueenPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _SpriteCanvas(canvas, size, 32, 50);
    const skin = Color(0xff70442f);
    const skinLight = Color(0xffa76847);
    const skinShadow = Color(0xff4a2a26);
    const hair = Color(0xff292733);
    const hairLight = Color(0xff50435c);
    const blue = Color(0xff203d78);
    const blueLight = Color(0xff315a9c);
    const blueShadow = Color(0xff152951);
    const ivory = Color(0xfff4ead4);
    const ivoryShadow = Color(0xffc9bea7);
    const gold = Color(0xffffca45);
    const goldShadow = Color(0xffb68032);
    const goldLight = Color(0xffffe47b);
    final bob = frame == 2 || frame == 5 ? 1.0 : 0.0;

    p.rect(9, 5 + bob, 15, 5, hair);
    p.rect(7, 9 + bob, 19, 7, hair);
    p.rect(8, 8 + bob, 5, 4, hairLight);
    p.rect(10, 9 + bob, 13, 11, skinShadow);
    p.rect(11, 9 + bob, 11, 10, skin);
    p.rect(12, 10 + bob, 3, 8, skinLight);
    p.rect(19, 12 + bob, 2, 1, hair);
    p.rect(21, 10 + bob, 2, 8, skinShadow);
    p.rect(8, 17 + bob, 17, 6, ivoryShadow);
    p.rect(9, 17 + bob, 15, 5, ivory);
    p.rect(13, 18 + bob, 7, 2, gold);

    p.rect(7, 21 + bob, 19, 25, blueShadow);
    p.rect(9, 21 + bob, 15, 24, blue);
    p.rect(10, 23 + bob, 5, 20, blueLight);
    p.rect(20, 24 + bob, 3, 19, Color.lerp(blue, Colors.black, .18)!);
    p.rect(4, 23 + bob, 6, 22, ivoryShadow);
    p.rect(5, 23 + bob, 4, 20, ivory);
    p.rect(24, 23 + bob, 5, 22, ivoryShadow);
    p.rect(24, 23 + bob, 3, 20, ivory);
    p.rect(6, 35 + bob, 4, 3, skinLight);
    p.rect(24, 35 + bob, 4, 3, skin);
    p.rect(7, 31 + bob, 19, 3, goldShadow);
    p.rect(8, 31 + bob, 17, 2, gold);
    p.rect(5, 44 + bob, 24, 4, blueShadow);
    p.rect(7, 44 + bob, 20, 2, blueLight);

    p.rect(10, 4 + bob, 14, 3, goldShadow);
    p.rect(10, 2 + bob, 3, 5, gold);
    p.rect(15, 0 + bob, 3, 7, gold);
    p.rect(21, 2 + bob, 3, 5, gold);
    p.rect(11, 5 + bob, 12, 3, gold);
    p.rect(12, 5 + bob, 9, 1, goldLight);
  }

  @override
  bool shouldRepaint(_PixelQueenPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

class PixelStatusIcon extends StatelessWidget {
  const PixelStatusIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 20,
  });
  final PixelStatusGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PixelStatusPainter(glyph, color)),
  );
}

class _PixelStatusPainter extends CustomPainter {
  const _PixelStatusPainter(this.glyph, this.color);
  final PixelStatusGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _SpriteCanvas(canvas, size, 16, 16);
    final shade = Color.lerp(color, Colors.black, .28)!;
    final light = Color.lerp(color, Colors.white, .28)!;
    switch (glyph) {
      case PixelStatusGlyph.lock:
        p.rect(3, 7, 10, 8, shade);
        p.rect(4, 7, 8, 7, color);
        p.rect(5, 3, 2, 5, color);
        p.rect(10, 3, 2, 5, shade);
        p.rect(6, 2, 5, 2, color);
        p.rect(7, 9, 3, 3, light);
        p.rect(8, 11, 1, 2, shade);
      case PixelStatusGlyph.crown:
        p.rect(2, 5, 3, 7, shade);
        p.rect(7, 2, 3, 10, shade);
        p.rect(12, 5, 2, 7, shade);
        p.rect(3, 5, 2, 6, color);
        p.rect(8, 2, 2, 9, color);
        p.rect(12, 5, 2, 6, color);
        p.rect(3, 9, 11, 4, color);
        p.rect(5, 9, 6, 1, light);
        p.rect(4, 14, 9, 1, shade);
      case PixelStatusGlyph.star:
        p.rect(7, 1, 3, 14, shade);
        p.rect(1, 7, 14, 3, shade);
        p.rect(4, 4, 8, 8, color);
        p.rect(6, 2, 4, 12, color);
        p.rect(2, 6, 12, 4, color);
        p.rect(6, 5, 3, 3, light);
      case PixelStatusGlyph.arrow:
        p.rect(2, 5, 7, 6, shade);
        p.rect(7, 3, 3, 10, shade);
        p.rect(10, 5, 3, 6, shade);
        p.rect(3, 6, 7, 4, color);
        p.rect(8, 4, 3, 8, color);
        p.rect(11, 6, 3, 4, color);
        p.rect(4, 6, 5, 1, light);
      case PixelStatusGlyph.dots:
        p.rect(1, 6, 4, 4, shade);
        p.rect(6, 6, 4, 4, shade);
        p.rect(11, 6, 4, 4, shade);
        p.rect(2, 6, 3, 3, color);
        p.rect(7, 6, 3, 3, color);
        p.rect(12, 6, 3, 3, color);
        p.rect(2, 6, 2, 1, light);
        p.rect(7, 6, 2, 1, light);
        p.rect(12, 6, 2, 1, light);
    }
  }

  @override
  bool shouldRepaint(_PixelStatusPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class _PixelCanvas {
  const _PixelCanvas(this.canvas, this.size, this.grid);
  final Canvas canvas;
  final Size size;
  final double grid;

  void rect(double x, double y, double width, double height, Color color) {
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(
        _snap(x),
        _snap(y),
        math.max(grid, _snap(width)),
        math.max(grid, _snap(height)),
      ),
      paint,
    );
  }

  void cell(double x, double y, double width, double height, Color color) {
    rect(
      size.width * x / 100,
      size.height * y / 100,
      size.width * width / 100,
      size.height * height / 100,
      color,
    );
  }

  double _snap(double value) => (value / grid).roundToDouble() * grid;
}

class _SpriteCanvas {
  const _SpriteCanvas(
    this.canvas,
    this.size,
    this.logicalWidth,
    this.logicalHeight,
  );
  final Canvas canvas;
  final Size size;
  final double logicalWidth;
  final double logicalHeight;

  void rect(double x, double y, double width, double height, Color color) {
    final unit = math.min(
      size.width / logicalWidth,
      size.height / logicalHeight,
    );
    final left =
        ((size.width - logicalWidth * unit) / 2 + x * unit).roundToDouble();
    final top =
        ((size.height - logicalHeight * unit) / 2 + y * unit).roundToDouble();
    canvas.drawRect(
      Rect.fromLTWH(
        left,
        top,
        math.max(1, (width * unit).roundToDouble()),
        math.max(1, (height * unit).roundToDouble()),
      ),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  void outline(double x, double y, double width, double height, Color color) {
    rect(x, y, width, 1, color);
    rect(x, y + height - 1, width, 1, color);
    rect(x, y, 1, height, color);
    rect(x + width - 1, y, 1, height, color);
  }
}
