import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/journey.dart';

enum PixelSceneKind { panorama, opening, chapter, finale }

enum PixelArtPlacement { story, route, banner }

enum PixelStatusGlyph { lock, crown, star, arrow, dots }

class PixelLandscape extends StatelessWidget {
  const PixelLandscape({
    super.key,
    required this.chapter,
    required this.brightness,
    this.sceneKind = PixelSceneKind.panorama,
    this.placement = PixelArtPlacement.story,
    this.frame = 0,
  });

  static const _chapterAssets = <String, String>{
    'clovermead': 'assets/art/backgrounds/chapter_clovermead.webp',
    'whisperwood': 'assets/art/backgrounds/chapter_whisperwood.webp',
    'windmill-heights': 'assets/art/backgrounds/chapter_windmill_heights.webp',
    'sunken-cloister': 'assets/art/backgrounds/chapter_sunken_cloister.webp',
    'emberbell-caverns':
        'assets/art/backgrounds/chapter_emberbell_caverns.webp',
    'goblin-underkeep': 'assets/art/backgrounds/chapter_goblin_underkeep.webp',
    'moonlit-catacombs':
        'assets/art/backgrounds/chapter_moonlit_catacombs.webp',
    'crownspire': 'assets/art/backgrounds/chapter_crownspire.webp',
  };

  final JourneyChapter chapter;
  final Brightness brightness;
  final PixelSceneKind sceneKind;
  final PixelArtPlacement placement;
  final int frame;

  String get _assetPath => switch (sceneKind) {
    PixelSceneKind.opening => 'assets/art/backgrounds/story_opening.webp',
    PixelSceneKind.finale => 'assets/art/backgrounds/story_finale.webp',
    _ =>
      _chapterAssets[chapter.id] ??
          'assets/art/backgrounds/chapter_${chapter.id.replaceAll('-', '_')}.webp',
  };

  Alignment get _alignment {
    if (sceneKind == PixelSceneKind.finale &&
        placement == PixelArtPlacement.banner) {
      return const Alignment(0, -.48);
    }
    return switch (placement) {
      PixelArtPlacement.story => Alignment.center,
      PixelArtPlacement.route => Alignment.center,
      PixelArtPlacement.banner => const Alignment(0, -.1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: PixelLandscapePainter(
        chapter: chapter,
        brightness: brightness,
        frame: frame,
      ),
    );
    return ClipRect(
      child: RepaintBoundary(
        child: Image.asset(
          _assetPath,
          fit: BoxFit.cover,
          alignment: _alignment,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (context, child, imageFrame, wasLoaded) {
            if (wasLoaded || imageFrame != null) return child;
            return fallback;
          },
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

class PixelStoryScene extends StatefulWidget {
  const PixelStoryScene({
    super.key,
    required this.chapter,
    required this.kind,
    required this.semanticLabel,
    this.placement = PixelArtPlacement.story,
  });

  final JourneyChapter chapter;
  final PixelSceneKind kind;
  final String semanticLabel;
  final PixelArtPlacement placement;

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
                    PixelLandscape(
                      chapter: widget.chapter,
                      brightness: Theme.of(context).brightness,
                      sceneKind: widget.kind,
                      placement: widget.placement,
                      frame: frame,
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
    final ink = dark ? const Color(0xffefe8d5) : const Color(0xff25231f);
    final grid = math.max(1.0, (size.shortestSide / 180).floorToDouble());
    final p = _PixelCanvas(canvas, size, grid);
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

    p.rect(0, 0, size.width, size.height, skyTop);
    for (var band = 0; band < 28; band++) {
      final y = size.height * band * .016;
      p.rect(
        0,
        y,
        size.width,
        size.height * .018,
        Color.lerp(skyTop, skyLow, band / 27)!,
      );
    }
    _skyDetails(p, dark: dark, far: far, ink: ink, seed: index);
    _terrainLayers(p, index, background, far, mid, near);
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

    _foregroundDetail(p, index, background, far, mid, near, ink);

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
      final moon = Color.lerp(ink, Colors.white, .45)!;
      if (seed == 6) {
        p.cell(73, 5, 10, 10, moon);
        p.cell(78, 3, 8, 12, far);
        p.cell(73, 15, 11, .5, moon.withValues(alpha: .45));
      }
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 18; x++) {
          if ((x * 7 + y * 11 + seed) % 11 == 0) {
            final twinkle = frame == (x + y) % 6;
            p.cell(
              2 + x * 5.7,
              2 + y * 5.3,
              twinkle ? .75 : .35,
              twinkle ? .75 : .35,
              ink.withValues(alpha: twinkle ? .88 : .52),
            );
            if (twinkle) {
              p.cell(
                1.6 + x * 5.7,
                2.25 + y * 5.3,
                1.55,
                .18,
                ink.withValues(alpha: .4),
              );
            }
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
        final cloudShade = Color.lerp(cloudColor, far, .35)!;
        p.cell(cloud.dx, cloud.dy, 15, 1.2, cloudShade);
        p.cell(cloud.dx + 1.2, cloud.dy - 1.2, 13, 2.2, cloudColor);
        p.cell(cloud.dx + 3.1, cloud.dy - 2.6, 8.5, 2.6, cloudColor);
        p.cell(cloud.dx + 6, cloud.dy - 4.1, 4.8, 2.1, cloudColor);
        p.cell(cloud.dx + 8, cloud.dy - 4.8, 2.2, 1.2, cloudColor);
        p.cell(
          cloud.dx + 3,
          cloud.dy - 1.7,
          4.5,
          .45,
          Colors.white.withValues(alpha: .42),
        );
        p.cell(
          cloud.dx + 2,
          cloud.dy + 1.4,
          12,
          .45,
          far.withValues(alpha: .35),
        );
      }
    }
  }

  void _terrainLayers(
    _PixelCanvas p,
    int index,
    Color background,
    Color far,
    Color mid,
    Color near,
  ) {
    p.cell(0, 43, 100, 57, background);
    if (index <= 2 || index == 7) {
      p.polygon(const [
        Offset(0, 47),
        Offset(0, 41),
        Offset(9, 37),
        Offset(18, 40),
        Offset(29, 33),
        Offset(39, 39),
        Offset(51, 31),
        Offset(64, 39),
        Offset(78, 34),
        Offset(89, 40),
        Offset(100, 35),
        Offset(100, 50),
      ], far);
      p.polygon(const [
        Offset(0, 57),
        Offset(0, 49),
        Offset(12, 44),
        Offset(26, 48),
        Offset(39, 41),
        Offset(55, 49),
        Offset(71, 42),
        Offset(87, 48),
        Offset(100, 43),
        Offset(100, 61),
      ], Color.lerp(far, mid, .62)!);
      p.polygon(const [
        Offset(0, 69),
        Offset(0, 59),
        Offset(17, 54),
        Offset(32, 61),
        Offset(49, 53),
        Offset(67, 60),
        Offset(83, 54),
        Offset(100, 60),
        Offset(100, 75),
      ], mid);
    } else {
      p.cell(0, 42, 100, 8, far);
      p.cell(0, 50, 100, 9, Color.lerp(far, mid, .55)!);
      p.cell(0, 59, 100, 11, mid);
    }
    p.polygon(const [
      Offset(0, 82),
      Offset(0, 69),
      Offset(9, 67),
      Offset(21, 71),
      Offset(34, 66),
      Offset(48, 72),
      Offset(63, 67),
      Offset(79, 73),
      Offset(91, 68),
      Offset(100, 71),
      Offset(100, 84),
    ], near);
    p.cell(0, 82, 100, 18, Color.lerp(near, background, .42)!);
  }

  void _dither(_PixelCanvas p, Color light, Color shade, int seed) {
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 28; x++) {
        final value = x * 3 + y * 5 + seed;
        if (value % 8 == 0) {
          p.cell(x * 3.7 + 1, y * 4.8 + 4, .38, .38, light);
        } else if (value % 13 == 0) {
          p.cell(x * 3.7 + 2.2, y * 4.8 + 2, .3, .3, shade);
        }
      }
    }
  }

  void _foregroundDetail(
    _PixelCanvas p,
    int index,
    Color background,
    Color far,
    Color mid,
    Color near,
    Color ink,
  ) {
    final light = Color.lerp(background, Colors.white, .28)!;
    final shade = Color.lerp(near, ink, .32)!;
    for (var row = 0; row < 6; row++) {
      for (var column = 0; column < 24; column++) {
        final hash = column * 17 + row * 29 + index * 13;
        if (hash % 7 == 0) {
          final x = 1.5 + column * 4.2;
          final y = 72.0 + row * 4.7 + (hash % 5) * .35;
          p.cell(x, y, .28, 1.2, shade.withValues(alpha: .72));
          p.cell(x + .35, y - .3, .5, .3, light.withValues(alpha: .7));
        } else if (hash % 11 == 0) {
          p.cell(
            1.5 + column * 4.2,
            73.0 + row * 4.7,
            .7,
            .25,
            Color.lerp(far, mid, .5)!.withValues(alpha: .7),
          );
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
    final roof = chapter.palette.secondary;
    final roofShade = Color.lerp(roof, ink, .35)!;
    final timber = Color.lerp(ink, mid, .22)!;
    final stone = Color.lerp(cream, far, .45)!;

    // A small half-timbered cottage nestled into the foreground hill.
    p.polygon(const [
      Offset(4, 55),
      Offset(11, 47),
      Offset(24, 47),
      Offset(31, 55),
    ], roofShade);
    p.polygon(const [
      Offset(6, 54),
      Offset(12, 48),
      Offset(23, 48),
      Offset(29, 54),
    ], roof);
    p.cell(7, 54, 21, 12, cream);
    p.cell(7, 64, 21, 2, stone);
    p.cell(9, 55, 1.1, 10, timber);
    p.cell(24.5, 55, 1.1, 10, timber);
    p.cell(9, 59.5, 16.5, .7, timber);
    p.cell(15.5, 54, .8, 12, timber);
    p.cell(18, 60, 5, 6, timber);
    p.cell(19, 61, 2.8, 5, Color.lerp(timber, ink, .35)!);
    p.cell(11, 56.5, 3, 2.6, const Color(0xff8fc7cc));
    p.cell(11.5, 57, .5, 1.8, cream);
    p.cell(12.5, 56.8, .4, 2, timber);
    p.cell(23, 43.5, 1.6, 6, timber);
    p.cell(22.5, 43, 2.7, 1.2, stone);
    for (var x = 7.0; x < 28; x += 2.3) {
      p.cell(x, 52.2 + ((x * 2).round().isEven ? 0 : .5), 2, .45, roofShade);
    }

    // A tapered windmill with shaded stone courses and fine timber sails.
    p.polygon(const [
      Offset(68, 55),
      Offset(71, 24),
      Offset(78, 24),
      Offset(82, 55),
    ], Color.lerp(stone, ink, .18)!);
    p.polygon(const [
      Offset(69.5, 54),
      Offset(72.2, 25),
      Offset(76.8, 25),
      Offset(80.5, 54),
    ], stone);
    for (var y = 30.0; y < 54; y += 4) {
      p.cell(
        70.5 + ((y ~/ 4).isOdd ? .8 : 0),
        y,
        8.8,
        .45,
        Color.lerp(stone, far, .45)!,
      );
    }
    p.polygon(const [
      Offset(69, 25),
      Offset(73, 20),
      Offset(78, 20),
      Offset(82, 25),
    ], roofShade);
    p.cell(72.5, 35, 4.8, 6, timber);
    p.cell(73.2, 36, 1.3, 4, const Color(0xff8fc7cc));
    p.cell(75.5, 36, 1, 4, const Color(0xff568f9a));
    p.cell(73, 48, 4.5, 6, timber);
    p.cell(74.2, 49, 2.2, 5, Color.lerp(timber, near, .25)!);
    final sailShift = frame.isOdd ? .45 : 0.0;
    p.cell(74.7 + sailShift, 8, 1.1, 30, timber);
    p.cell(60.5, 22.2 + sailShift, 29.5, 1.1, timber);
    p.polygon(const [
      Offset(75.7, 9),
      Offset(78, 11),
      Offset(77, 20),
      Offset(75.7, 22),
    ], cream);
    p.polygon(const [
      Offset(61.5, 22),
      Offset(64, 19.8),
      Offset(72.5, 21),
      Offset(74, 22),
    ], cream);
    p.polygon(const [
      Offset(76, 23.6),
      Offset(87.8, 24),
      Offset(90, 26),
      Offset(78, 25),
    ], cream);
    p.polygon(const [
      Offset(74.5, 24),
      Offset(74, 36.5),
      Offset(72, 38.5),
      Offset(73.2, 26),
    ], cream);
    p.cell(73.4 + sailShift, 21.2 + sailShift, 4.5, 4.5, roofShade);
    p.cell(
      74.4 + sailShift,
      22.2 + sailShift,
      2.5,
      2.5,
      const Color(0xffd9b85c),
    );

    // Sheep, clover, and the near fence keep the meadow from reading as bands.
    p.cell(42, 65, 8, 3.5, cream);
    p.cell(43, 63.8, 5.2, 2.2, Color.lerp(cream, Colors.white, .3)!);
    p.cell(49.2, 65, 2.1, 2.3, ink);
    p.cell(42.5, 68, 1, 2.4, ink);
    p.cell(48.5, 68, 1, 2.4, ink);
    p.cell(49.8, 64.1, .55, .55, cream);
    for (final x in [5.0, 19.0, 34.0, 55.0, 63.0, 87.0, 95.0]) {
      final y = 70 + (x % 4);
      p.cell(x, y, .35, 2.2, Color.lerp(near, ink, .35)!);
      p.cell(x - .65, y, .8, .65, roof);
      p.cell(x + .25, y + .25, .65, .65, cream);
      p.cell(x - .15, y - .5, .55, .55, const Color(0xffffdf67));
    }
    p.cell(3, 84, 94, .5, Color.lerp(near, ink, .28)!);
    p.cell(3, 91, 94, .45, Color.lerp(near, ink, .22)!);
    for (var x = 5; x < 98; x += 8) {
      p.cell(x.toDouble(), 80.5, .65, 14, timber);
      p.cell(x + .65, 81, .35, 13, Color.lerp(timber, cream, .28)!);
      p.cell(x - .7, 79.8, 2.1, .8, roofShade);
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
    final barkLight = Color.lerp(bark, Colors.white, .22)!;
    final barkDark = Color.lerp(bark, Colors.black, .32)!;
    final leafLight = Color.lerp(mid, Colors.white, .14)!;
    final leafDark = Color.lerp(near, Colors.black, .25)!;

    for (final x in [-3.0, 17.0, 69.0, 91.0]) {
      p.polygon([
        Offset(x, 80),
        Offset(x + 2, 18),
        Offset(x + 8, 16),
        Offset(x + 10, 80),
      ], barkDark);
      p.polygon([
        Offset(x + 2, 78),
        Offset(x + 3.5, 19),
        Offset(x + 6.5, 18),
        Offset(x + 7, 78),
      ], bark);
      p.cell(x + 3.2, 21, .75, 54, barkLight);
      p.cell(x + 6.1, 25, .6, 50, barkDark);
      for (var y = 29.0; y < 72; y += 8) {
        p.cell(x + 4, y, 2, .45, y.toInt().isEven ? barkLight : barkDark);
      }
      p.polygon([
        Offset(x + 5, 31),
        Offset(x + 15, 23),
        Offset(x + 17, 25),
        Offset(x + 7, 35),
      ], bark);
      p.polygon([
        Offset(x + 5, 46),
        Offset(x - 6, 39),
        Offset(x - 7, 41),
        Offset(x + 4, 50),
      ], barkDark);

      for (final crown in [
        Offset(x - 5, 5),
        Offset(x + 3, 0),
        Offset(x + 10, 7),
        Offset(x - 1, 13),
      ]) {
        p.polygon([
          Offset(crown.dx, crown.dy + 9),
          Offset(crown.dx + 3, crown.dy + 2),
          Offset(crown.dx + 9, crown.dy),
          Offset(crown.dx + 15, crown.dy + 5),
          Offset(crown.dx + 13, crown.dy + 12),
          Offset(crown.dx + 5, crown.dy + 14),
        ], (crown.dx.round().isEven ? mid : near));
        p.cell(
          crown.dx + 3,
          crown.dy + 4,
          6,
          1.2,
          leafLight.withValues(alpha: .65),
        );
        p.cell(
          crown.dx + 9,
          crown.dy + 9,
          3,
          1,
          leafDark.withValues(alpha: .7),
        );
      }
    }

    // Layered mushrooms and ferns create a dense, lived-in forest floor.
    for (final x in [10.0, 31.0, 55.0, 80.0]) {
      final y = 72.0 + (x % 5);
      p.cell(x, y, 1.1, 8, const Color(0xffefe0c8));
      p.cell(x + .65, y + .5, .35, 7, const Color(0xffaa8d74));
      p.polygon([
        Offset(x - 3.8, y),
        Offset(x - 1.5, y - 3),
        Offset(x + 3.2, y - 3.7),
        Offset(x + 6, y),
        Offset(x + 4.5, y + 1.5),
        Offset(x - 2.4, y + 1.5),
      ], chapter.palette.secondary);
      p.cell(
        x - 1.7,
        y - 2.5,
        4.3,
        .6,
        Color.lerp(chapter.palette.secondary, Colors.white, .35)!,
      );
      p.cell(x - .8, y - .8, .55, .55, const Color(0xffffe2c2));
      p.cell(x + 2.4, y - 1.5, .45, .45, const Color(0xffffe2c2));
    }

    for (final glow in const [
      Offset(13, 42),
      Offset(40, 27),
      Offset(61, 36),
      Offset(85, 47),
    ]) {
      final shift = frame.isEven ? 0.0 : .7;
      p.cell(glow.dx + shift, glow.dy, .55, .55, const Color(0xffffe777));
      p.cell(
        glow.dx + shift - .65,
        glow.dy - .65,
        1.8,
        1.8,
        const Color(0x22ffe777),
      );
      p.cell(
        glow.dx + shift - 1.5,
        glow.dy + .1,
        .8,
        .18,
        const Color(0x66ffe777),
      );
    }

    for (var x = 4; x < 100; x += 6) {
      final y = 87.0 - (x % 5);
      p.cell(x.toDouble(), y, .45, 5, barkDark);
      p.polygon([
        Offset(x - 2, y + 1),
        Offset(x.toDouble(), y - 1.5),
        Offset(x + .2, y + 1.5),
      ], leafLight);
      p.polygon([
        Offset(x + .2, y + 2),
        Offset(x + 2.4, y),
        Offset(x + .5, y + 3),
      ], leafDark);
    }
  }

  void _windmills(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    const plaster = Color(0xffeee4cf);
    const plasterShade = Color(0xffc5a98f);
    final rust = chapter.palette.secondary;
    final rustDark = Color.lerp(rust, ink, .42)!;
    final timber = Color.lerp(ink, mid, .25)!;

    // Slate ridges and a stepped road establish much more depth.
    p.polygon(const [
      Offset(0, 48),
      Offset(12, 39),
      Offset(25, 44),
      Offset(41, 32),
      Offset(57, 45),
      Offset(73, 36),
      Offset(100, 47),
    ], far);
    p.polygon(const [
      Offset(0, 59),
      Offset(18, 51),
      Offset(37, 57),
      Offset(59, 47),
      Offset(81, 55),
      Offset(100, 50),
      Offset(100, 66),
      Offset(0, 66),
    ], mid);
    p.polygon(const [
      Offset(10, 100),
      Offset(35, 68),
      Offset(48, 65),
      Offset(72, 100),
    ], Color(0xffd8ccb4));
    p.polygon(const [
      Offset(17, 100),
      Offset(38, 71),
      Offset(47, 69),
      Offset(63, 100),
    ], Color(0xffb9aa94));

    // Main tapered windmill tower with masonry, windows, and a conical cap.
    p.polygon(const [
      Offset(42, 62),
      Offset(46, 25),
      Offset(56, 25),
      Offset(61, 62),
    ], plasterShade);
    p.polygon(const [
      Offset(44, 61),
      Offset(47.5, 25),
      Offset(54.5, 25),
      Offset(59, 61),
    ], plaster);
    for (var y = 31.0; y < 60; y += 5) {
      p.cell(45 + ((y ~/ 5).isOdd ? .8 : 0), y, 13, .45, plasterShade);
      p.cell(
        48 + ((y ~/ 5).isOdd ? 0 : 2),
        y + 2.3,
        3.5,
        .35,
        Color.lerp(plaster, Colors.white, .3)!,
      );
    }
    p.polygon(const [
      Offset(42.5, 26),
      Offset(47, 19),
      Offset(55, 19),
      Offset(61, 26),
    ], rustDark);
    p.polygon(const [
      Offset(44, 25),
      Offset(47.5, 20.5),
      Offset(54.5, 20.5),
      Offset(59.5, 25),
    ], rust);
    p.cell(49, 47, 5, 8, timber);
    p.cell(50, 48, 3, 7, Color.lerp(timber, plaster, .18)!);
    p.cell(49.5, 33, 4, 5.5, const Color(0xff7f9eb1));
    p.cell(50.2, 33.7, 1.1, 4.2, const Color(0xffb9d1d6));
    p.cell(51.8, 33.5, .45, 4.5, timber);
    p.cell(49.3, 35.5, 4.3, .4, timber);

    final shift = frame.isOdd ? .45 : 0.0;
    p.cell(50.5 + shift, 6.5, .9, 34, timber);
    p.cell(33.5, 24.2 + shift, 35, .9, timber);
    p.polygon(const [
      Offset(51.5, 8),
      Offset(54, 10),
      Offset(53, 20.5),
      Offset(51.5, 23),
    ], plaster);
    p.polygon(const [
      Offset(34.5, 24),
      Offset(37.5, 21),
      Offset(48.5, 23),
      Offset(50, 24),
    ], plaster);
    p.polygon(const [
      Offset(52, 25.6),
      Offset(65, 26.5),
      Offset(68, 29),
      Offset(53.5, 27.3),
    ], plaster);
    p.polygon(const [
      Offset(50, 25.8),
      Offset(49, 39),
      Offset(46.5, 42),
      Offset(48.5, 27),
    ], plaster);
    p.cell(49.2 + shift, 22.5 + shift, 4.5, 4.5, rustDark);
    p.cell(50.2 + shift, 23.5 + shift, 2.5, 2.5, const Color(0xffe0ad52));

    // A distant mill and bridge railings add narrative-scale detail.
    p.polygon(const [
      Offset(78, 54),
      Offset(80, 36),
      Offset(85, 36),
      Offset(87, 54),
    ], plasterShade);
    p.polygon(const [
      Offset(78, 37),
      Offset(81, 33),
      Offset(85, 33),
      Offset(88, 37),
    ], rust);
    p.cell(82.2, 27, .6, 19, timber);
    p.cell(75.5, 35.8, 14.5, .6, timber);
    p.cell(5, 65, 29, 1.2, timber);
    p.cell(67, 65, 27, 1.2, timber);
    for (final x in [7.0, 16.0, 25.0, 70.0, 79.0, 88.0]) {
      p.cell(x, 61.5, 1, 12, timber);
      p.cell(x + .8, 62, .35, 11, plasterShade);
    }
    for (final bird in const [Offset(16, 18), Offset(24, 15), Offset(78, 22)]) {
      p.cell(bird.dx, bird.dy, 1.7, .35, ink.withValues(alpha: .7));
      p.cell(bird.dx + 1.6, bird.dy - .5, 1.7, .35, ink.withValues(alpha: .7));
    }
    for (var x = 3; x < 100; x += 7) {
      p.cell(x.toDouble(), 78 + (x % 4), 3.8, .45, Color.lerp(near, mid, .4)!);
      p.cell(x + 1, 77.2 + (x % 4), .4, 1.3, Color.lerp(near, ink, .3)!);
    }
  }

  void _cloister(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final stone = Color.lerp(far, ink, .28)!;
    final stoneLight = Color.lerp(stone, Colors.white, .24)!;
    final stoneDark = Color.lerp(stone, Colors.black, .28)!;
    final water = chapter.palette.secondary;
    p.cell(0, 68, 100, 32, water.withValues(alpha: .78));
    p.cell(0, 71, 100, 1.1, Color.lerp(water, Colors.white, .34)!);
    p.cell(0, 78, 100, .55, Color.lerp(water, Colors.white, .22)!);
    p.cell(0, 89, 100, .45, Color.lerp(water, ink, .18)!);

    // Repeating pointed arches with individual masonry blocks.
    for (final x in [-3.0, 29.0, 61.0, 93.0]) {
      p.cell(x, 27, 5.5, 46, stoneDark);
      p.cell(x + 1, 27, 3.5, 45, stone);
      p.cell(x + 2, 29, .8, 41, stoneLight);
      p.cell(x + 25, 27, 5.5, 46, stoneDark);
      p.cell(x + 25.5, 27, 3.7, 45, stone);
      p.polygon([
        Offset(x, 28),
        Offset(x + 5, 20),
        Offset(x + 13.5, 15),
        Offset(x + 22, 20),
        Offset(x + 30.5, 28),
        Offset(x + 27, 31),
        Offset(x + 21, 24),
        Offset(x + 13.5, 20),
        Offset(x + 6, 24),
        Offset(x + 2, 31),
      ], stoneDark);
      p.polygon([
        Offset(x + 2, 27),
        Offset(x + 6, 21),
        Offset(x + 13.5, 17),
        Offset(x + 21, 21),
        Offset(x + 28.5, 27),
        Offset(x + 27, 29),
        Offset(x + 20, 23),
        Offset(x + 13.5, 19),
        Offset(x + 7, 23),
        Offset(x + 3.5, 29),
      ], stone);
      for (var y = 34.0; y < 70; y += 6) {
        p.cell(x + .5, y, 4.5, .5, y.toInt().isEven ? stoneLight : stoneDark);
        p.cell(
          x + 26,
          y + 2.5,
          4,
          .5,
          y.toInt().isEven ? stoneDark : stoneLight,
        );
      }
      p.cell(x + 9, 29, 9, 1.2, far.withValues(alpha: .65));
    }

    // Broken columns, lily pads, and reflected arches.
    for (var x = 0; x < 14; x++) {
      final y = 76.0 + (x.isEven ? 0 : 5);
      p.cell(x * 7.8, y, 4.5, .45, near);
      p.cell(
        x * 7.8 + 1.2,
        y - .45,
        2.6,
        .35,
        stoneLight.withValues(alpha: .65),
      );
      p.cell(x * 7.8 + 2, 87 + (x.isEven ? 2 : 0), 6, .35, far);
    }
    for (final x in [15.0, 48.0, 88.0]) {
      p.cell(x, 62, .45, 12, Color.lerp(mid, ink, .2)!);
      p.polygon([
        Offset(x - 3, 64),
        Offset(x - 1, 60),
        Offset(x + .2, 65),
      ], near);
      p.polygon([
        Offset(x, 63),
        Offset(x + 2.8, 58),
        Offset(x + .5, 67),
      ], Color.lerp(near, Colors.white, .15)!);
    }
    for (final x in [20.0, 54.0, 74.0]) {
      p.cell(x, 77, 5, .8, Color.lerp(near, ink, .2)!);
      p.cell(x + 1, 76.5, 2.5, .45, Color.lerp(near, Colors.white, .18)!);
      p.cell(x + 2.2, 74.8, .35, 2.2, stoneLight);
      p.cell(x + 1.7, 74.5, 1.3, .35, const Color(0xffffe3a0));
    }
  }

  void _cavern(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final rock = Color.lerp(chapter.palette.primary, Colors.black, .36)!;
    final rockMid = Color.lerp(rock, mid, .28)!;
    final rockLight = Color.lerp(rock, chapter.palette.secondary, .34)!;
    final ember = chapter.palette.secondary;

    p.polygon(const [
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 12),
      Offset(94, 18),
      Offset(89, 13),
      Offset(82, 25),
      Offset(76, 14),
      Offset(66, 20),
      Offset(58, 11),
      Offset(50, 24),
      Offset(43, 13),
      Offset(33, 18),
      Offset(25, 10),
      Offset(16, 23),
      Offset(9, 14),
      Offset(0, 20),
    ], rock);
    p.polygon(const [
      Offset(0, 0),
      Offset(100, 0),
      Offset(100, 6),
      Offset(83, 10),
      Offset(70, 7),
      Offset(56, 12),
      Offset(40, 8),
      Offset(24, 12),
      Offset(10, 7),
      Offset(0, 11),
    ], rockMid);
    for (final shard in const [
      [Offset(14, 10), Offset(18, 28), Offset(21, 12)],
      [Offset(37, 8), Offset(42, 23), Offset(46, 9)],
      [Offset(68, 7), Offset(72, 21), Offset(76, 8)],
      [Offset(88, 8), Offset(92, 27), Offset(96, 9)],
    ]) {
      p.polygon(shard, rockLight);
      p.cell(
        shard[0].dx + 2,
        shard[0].dy + 2,
        .45,
        8,
        Color.lerp(rockLight, Colors.white, .18)!,
      );
    }

    p.polygon(const [
      Offset(0, 100),
      Offset(0, 88),
      Offset(11, 78),
      Offset(23, 87),
      Offset(38, 75),
      Offset(52, 89),
      Offset(65, 78),
      Offset(80, 86),
      Offset(92, 76),
      Offset(100, 84),
      Offset(100, 100),
    ], Color(0xff3a2530));
    p.polygon(const [
      Offset(0, 100),
      Offset(0, 94),
      Offset(16, 87),
      Offset(29, 93),
      Offset(45, 83),
      Offset(60, 94),
      Offset(77, 85),
      Offset(100, 91),
      Offset(100, 100),
    ], Color(0xff5b2c2f));

    // Ember crystal clusters use multiple facets rather than solid pillars.
    for (final x in [7.0, 26.0, 57.0, 82.0]) {
      final y = 67.0 + (x % 4);
      p.polygon([
        Offset(x, y + 17),
        Offset(x + 2, y + 2),
        Offset(x + 5, y - 4),
        Offset(x + 7, y + 17),
      ], ember);
      p.polygon([
        Offset(x + 2, y + 15),
        Offset(x + 3, y + 2),
        Offset(x + 5, y - 4),
        Offset(x + 5, y + 15),
      ], const Color(0xffffdf77));
      p.polygon([
        Offset(x + 5, y - 4),
        Offset(x + 9, y + 4),
        Offset(x + 8, y + 16),
        Offset(x + 5, y + 15),
      ], const Color(0xffff8f42));
      p.polygon([
        Offset(x - 4, y + 14),
        Offset(x, y + 6),
        Offset(x + 2, y + 17),
      ], const Color(0xffd34b35));
      p.cell(x + 2.8, y + 1, .5, 10, const Color(0xfffff0a6));
      p.cell(x - 5, y + 16, 16, 2.5, rockMid);
      p.cell(x - 2, y + 15.3, 9, .6, rockLight);
    }
    for (final bell in const [Offset(42, 43), Offset(74, 34)]) {
      p.cell(bell.dx + 4, bell.dy - 8, .6, 8, ink);
      p.polygon([
        Offset(bell.dx + 2, bell.dy),
        Offset(bell.dx + 7, bell.dy),
        Offset(bell.dx + 10, bell.dy + 8),
        Offset(bell.dx - 1, bell.dy + 8),
      ], const Color(0xff8f562e));
      p.polygon([
        Offset(bell.dx + 3, bell.dy),
        Offset(bell.dx + 6, bell.dy),
        Offset(bell.dx + 8, bell.dy + 6),
        Offset(bell.dx + 1, bell.dy + 6),
      ], const Color(0xffc98b35));
      p.cell(bell.dx + 2, bell.dy + 1, 2, 4, const Color(0xffeab353));
      p.cell(bell.dx, bell.dy + 6.5, 10, 1.5, const Color(0xffeab353));
      p.cell(bell.dx + 4, bell.dy + 7.5, 1.3, 3, ink);
    }
    for (var x = 4; x < 100; x += 8) {
      final y = 52.0 + (x % 9);
      p.cell(x.toDouble(), y, 2.5, .35, rockLight.withValues(alpha: .7));
      p.cell(x + 1, y + .5, .35, 1.4, ember.withValues(alpha: .45));
    }
  }

  void _underkeep(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final mortar = Color.lerp(far, Colors.black, .25)!;
    final brick = Color.lerp(far, near, .42)!;
    final brickLight = Color.lerp(brick, Colors.white, .12)!;
    final brass = const Color(0xffc7953f);
    final brassLight = const Color(0xffffd565);
    final brassDark = const Color(0xff795525);

    for (var y = 7; y < 95; y += 6) {
      p.cell(0, y.toDouble(), 100, .65, mortar);
      final offset = (y ~/ 6).isEven ? 0.0 : 6.0;
      for (var x = -6.0 + offset; x < 100; x += 12) {
        p.cell(x, y.toDouble(), .55, 6, mortar);
        p.cell(x + .8, y + .8, 9.8, .35, brickLight.withValues(alpha: .48));
      }
    }
    p.polygon(const [
      Offset(0, 100),
      Offset(0, 76),
      Offset(14, 74),
      Offset(25, 82),
      Offset(40, 73),
      Offset(57, 80),
      Offset(74, 72),
      Offset(89, 79),
      Offset(100, 75),
      Offset(100, 100),
    ], Color.lerp(near, Colors.black, .2)!);

    // Layered pipes with collars and rivets.
    p.cell(4, 16, 5, 68, Color.lerp(ink, mid, .35)!);
    p.cell(5, 17, 2.2, 66, chapter.palette.secondary);
    p.cell(5.4, 18, .55, 63, brassLight.withValues(alpha: .65));
    p.cell(90, 10, 5, 74, Color.lerp(ink, mid, .35)!);
    p.cell(91, 11, 2.2, 71, brass);
    for (final y in [22.0, 48.0, 72.0]) {
      p.cell(2.8, y, 7.4, 2.6, brassDark);
      p.cell(3.5, y + .4, 6, 1.4, brass);
      p.cell(89, y - 2, 7, 2.6, brassDark);
      p.cell(89.7, y - 1.6, 5.6, 1.4, brass);
      p.cell(4.2, y + .7, .6, .6, brassLight);
      p.cell(8.1, y + .7, .6, .6, brassLight);
    }

    // Detailed toothed gears with concentric shading.
    for (final center in [const Offset(28, 39), const Offset(76, 58)]) {
      p.polygon([
        Offset(center.dx, center.dy - 11),
        Offset(center.dx + 7, center.dy - 8),
        Offset(center.dx + 11, center.dy),
        Offset(center.dx + 8, center.dy + 7),
        Offset(center.dx, center.dy + 11),
        Offset(center.dx - 7, center.dy + 8),
        Offset(center.dx - 11, center.dy),
        Offset(center.dx - 8, center.dy - 7),
      ], brassDark);
      p.polygon([
        Offset(center.dx, center.dy - 8.5),
        Offset(center.dx + 6, center.dy - 6),
        Offset(center.dx + 8.5, center.dy),
        Offset(center.dx + 6, center.dy + 6),
        Offset(center.dx, center.dy + 8.5),
        Offset(center.dx - 6, center.dy + 6),
        Offset(center.dx - 8.5, center.dy),
        Offset(center.dx - 6, center.dy - 6),
      ], brass);
      p.polygon([
        Offset(center.dx - 5, center.dy - 2),
        Offset(center.dx - 2, center.dy - 6),
        Offset(center.dx + 4, center.dy - 5),
        Offset(center.dx + 6, center.dy),
        Offset(center.dx + 3, center.dy + 5),
        Offset(center.dx - 4, center.dy + 4),
        Offset(center.dx - 6, center.dy),
      ], near);
      p.cell(center.dx - 2.4, center.dy - 2.4, 4.8, 4.8, ink);
      p.cell(center.dx - .8, center.dy - .8, 1.6, 1.6, brassLight);
      p.cell(
        center.dx - 5,
        center.dy - 5.5,
        4,
        1,
        brassLight.withValues(alpha: .7),
      );
      for (final tooth in const [
        Offset(0, -13),
        Offset(0, 11),
        Offset(-13, 0),
        Offset(11, 0),
      ]) {
        p.cell(
          center.dx + tooth.dx - 1.5,
          center.dy + tooth.dy - 1.5,
          3,
          3,
          brass,
        );
      }
    }

    // A riveted service door and hanging chains.
    p.polygon(const [
      Offset(39, 88),
      Offset(39, 70),
      Offset(43, 65),
      Offset(56, 65),
      Offset(60, 70),
      Offset(60, 88),
    ], Color.lerp(ink, near, .18)!);
    p.polygon(const [
      Offset(42, 88),
      Offset(42, 71),
      Offset(45, 68),
      Offset(54, 68),
      Offset(57, 71),
      Offset(57, 88),
    ], Color.lerp(near, Colors.black, .32)!);
    p.cell(53, 77, 1.1, 2.1, brassLight);
    p.cell(52.7, 76.6, 1.7, .6, brassDark);
    for (final x in [18.0, 66.0]) {
      for (var y = 12.0; y < 33; y += 3) {
        p.cell(x + ((y ~/ 3).isEven ? 0 : .7), y, 1.1, 1.6, brassDark);
      }
    }
    for (final x in [14.0, 63.0, 84.0]) {
      p.cell(x, 25, 6, 1.2, brass);
      p.cell(x + 2.2, 26, 1.4, 7, brassLight);
      p.cell(x + 2.6, 27, .5, 5, const Color(0xffffef9a));
    }
  }

  void _catacombs(_PixelCanvas p, Color far, Color mid, Color near, Color ink) {
    final stone = Color.lerp(far, ink, .2)!;
    final stoneLight = Color.lerp(stone, Colors.white, .2)!;
    final stoneDark = Color.lerp(stone, Colors.black, .3)!;

    // Moonlit lancet vaults with smaller, individually shaded stones.
    for (final x in [-1.0, 32.0, 65.0, 98.0]) {
      p.cell(x, 31, 4.8, 49, stoneDark);
      p.cell(x + .8, 31, 3.1, 48, stone);
      p.cell(x + 1.3, 33, .55, 44, stoneLight);
      p.cell(x + 25, 31, 4.8, 49, stoneDark);
      p.cell(x + 25.5, 31, 3.1, 48, stone);
      p.polygon([
        Offset(x, 32),
        Offset(x + 6, 24),
        Offset(x + 14, 17),
        Offset(x + 23, 24),
        Offset(x + 30, 32),
        Offset(x + 27, 35),
        Offset(x + 21, 27),
        Offset(x + 14, 21),
        Offset(x + 7, 27),
        Offset(x + 3, 35),
      ], stoneDark);
      p.polygon([
        Offset(x + 2, 31),
        Offset(x + 7, 25),
        Offset(x + 14, 19),
        Offset(x + 22, 25),
        Offset(x + 28, 31),
        Offset(x + 27, 33),
        Offset(x + 21, 26.5),
        Offset(x + 14, 20.5),
        Offset(x + 8, 26.5),
        Offset(x + 4, 33),
      ], stone);
      for (var y = 38.0; y < 77; y += 6) {
        p.cell(x + .5, y, 3.8, .45, y.toInt().isEven ? stoneLight : stoneDark);
        p.cell(
          x + 26,
          y + 2.8,
          3.5,
          .45,
          y.toInt().isEven ? stoneDark : stoneLight,
        );
      }
    }

    p.polygon(const [
      Offset(0, 100),
      Offset(0, 82),
      Offset(15, 78),
      Offset(29, 84),
      Offset(44, 77),
      Offset(59, 83),
      Offset(75, 76),
      Offset(89, 82),
      Offset(100, 79),
      Offset(100, 100),
    ], Color.lerp(near, Colors.black, .2)!);

    for (final tomb in const [Offset(13, 58), Offset(45, 67), Offset(82, 53)]) {
      p.polygon([
        Offset(tomb.dx, tomb.dy + 14),
        Offset(tomb.dx, tomb.dy + 2),
        Offset(tomb.dx + 2, tomb.dy - 2),
        Offset(tomb.dx + 5, tomb.dy - 4),
        Offset(tomb.dx + 8, tomb.dy - 2),
        Offset(tomb.dx + 10, tomb.dy + 2),
        Offset(tomb.dx + 10, tomb.dy + 14),
      ], stoneDark);
      p.polygon([
        Offset(tomb.dx + 1, tomb.dy + 13),
        Offset(tomb.dx + 1, tomb.dy + 2),
        Offset(tomb.dx + 3, tomb.dy - 1),
        Offset(tomb.dx + 5, tomb.dy - 2.5),
        Offset(tomb.dx + 7, tomb.dy - 1),
        Offset(tomb.dx + 9, tomb.dy + 2),
        Offset(tomb.dx + 9, tomb.dy + 13),
      ], stoneLight);
      p.cell(tomb.dx + 4.4, tomb.dy + 2, 1.2, 7, Color.lerp(near, ink, .3)!);
      p.cell(tomb.dx + 2.5, tomb.dy + 4.5, 5, 1.1, Color.lerp(near, ink, .3)!);
      p.cell(tomb.dx + 1.8, tomb.dy + 10.5, 6, .45, stone);
    }
    for (final lantern in const [Offset(31, 41), Offset(65, 36)]) {
      p.cell(lantern.dx + 2, lantern.dy - 6, .45, 6, ink);
      p.cell(lantern.dx - 1, lantern.dy - 6, 6, .55, ink);
      p.polygon([
        Offset(lantern.dx, lantern.dy),
        Offset(lantern.dx + 4, lantern.dy),
        Offset(lantern.dx + 5, lantern.dy + 7),
        Offset(lantern.dx - 1, lantern.dy + 7),
      ], Color.lerp(ink, mid, .2)!);
      p.cell(
        lantern.dx + .5,
        lantern.dy + 1,
        3.2,
        4.8,
        const Color(0xffffdc7c),
      );
      p.cell(
        lantern.dx + 1.3,
        lantern.dy + 1.4,
        .8,
        3.8,
        const Color(0xfffff1ad),
      );
      p.cell(lantern.dx - 3, lantern.dy - 1, 11, 10, const Color(0x16ffdc7c));
    }
    for (final bat in const [Offset(18, 13), Offset(48, 10)]) {
      p.polygon([
        Offset(bat.dx, bat.dy),
        Offset(bat.dx + 2.5, bat.dy + 1.4),
        Offset(bat.dx + 4, bat.dy + .4),
        Offset(bat.dx + 5.5, bat.dy + 1.4),
        Offset(bat.dx + 8, bat.dy),
      ], ink);
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
    const deepShade = Color(0xff9c907f);
    const gold = Color(0xffffd66a);
    const goldShade = Color(0xffb98a2d);
    final blue = chapter.palette.primary;
    final crimson = chapter.palette.secondary;

    // The palace is built from stepped towers, buttresses, cornices, and lit
    // windows instead of one large rectangular mass.
    p.polygon(const [
      Offset(50, 82),
      Offset(50, 31),
      Offset(54, 27),
      Offset(59, 27),
      Offset(59, 22),
      Offset(64, 22),
      Offset(64, 82),
    ], deepShade);
    p.polygon(const [
      Offset(54, 81),
      Offset(54, 31),
      Offset(58, 28),
      Offset(63, 28),
      Offset(63, 22),
      Offset(68, 22),
      Offset(68, 81),
    ], shade);
    p.polygon(const [
      Offset(58, 80),
      Offset(58, 32),
      Offset(61, 29),
      Offset(66, 29),
      Offset(66, 23),
      Offset(72, 23),
      Offset(72, 80),
    ], ivory);
    p.polygon(const [
      Offset(70, 80),
      Offset(70, 14),
      Offset(74, 10),
      Offset(77, 3),
      Offset(80, 10),
      Offset(84, 14),
      Offset(84, 80),
    ], deepShade);
    p.polygon(const [
      Offset(73, 79),
      Offset(73, 15),
      Offset(76, 11),
      Offset(78, 5),
      Offset(80, 12),
      Offset(82, 15),
      Offset(82, 79),
    ], ivory);
    p.polygon(const [
      Offset(82, 81),
      Offset(82, 27),
      Offset(88, 27),
      Offset(88, 32),
      Offset(92, 32),
      Offset(92, 81),
    ], shade);
    p.polygon(const [
      Offset(84, 80),
      Offset(84, 29),
      Offset(89, 29),
      Offset(89, 34),
      Offset(94, 34),
      Offset(94, 80),
    ], ivory);

    p.cell(63, 18, 29, 3, goldShade);
    p.cell(64, 17, 27, 2.1, gold);
    p.cell(53, 27, 42, 3.4, goldShade);
    p.cell(55, 26, 38, 2.2, gold);
    p.cell(58, 31, 34, .7, const Color(0xffffef9a));
    for (var y = 36.0; y < 76; y += 7) {
      p.cell(59, y, 34, .45, Color.lerp(ivory, shade, .55)!);
      p.cell(
        61 + ((y ~/ 7).isOdd ? 4 : 0),
        y + 3,
        7,
        .35,
        Color.lerp(ivory, Colors.white, .4)!,
      );
    }
    for (final x in [62.0, 76.0]) {
      p.polygon([
        Offset(x, 53),
        Offset(x, 39),
        Offset(x + 3.5, 35),
        Offset(x + 7, 39),
        Offset(x + 7, 53),
      ], far);
      p.cell(x + .8, 40, 1.5, 11.5, Color.lerp(far, Colors.white, .2)!);
      p.cell(x + 5, 40, 1, 12, Color.lerp(far, Colors.black, .25)!);
      p.cell(x - .7, 36.5, 8.5, 1.3, crimson);
      p.cell(x, 36, 7, .7, gold);
    }

    p.polygon(const [
      Offset(68, 80),
      Offset(68, 65),
      Offset(71, 59),
      Offset(77, 56),
      Offset(83, 59),
      Offset(86, 65),
      Offset(86, 80),
    ], goldShade);
    p.polygon(const [
      Offset(71, 80),
      Offset(71, 65),
      Offset(74, 61),
      Offset(78, 59),
      Offset(82, 62),
      Offset(83, 66),
      Offset(83, 80),
    ], Color.lerp(blue, Colors.black, .25)!);
    p.cell(73, 66, 2.2, 13, Color.lerp(blue, Colors.white, .2)!);

    // A long ceremonial stair, railings, and banner fill the approach.
    for (var y = 55.0; y < 91; y += 6) {
      final start = 25.0 + (y - 55) * .35;
      p.cell(
        start,
        y,
        46 - (y - 55) * .45,
        1.5,
        Color.lerp(ivory, shade, .48)!,
      );
      p.cell(start + 2, y, 42 - (y - 55) * .4, .45, ivory);
    }
    p.cell(8, 19, 2.1, 52, ink);
    p.cell(8.5, 19, .55, 50, goldShade);
    p.polygon(const [
      Offset(10, 23),
      Offset(35, 23),
      Offset(35, 43),
      Offset(22, 40),
      Offset(10, 43),
    ], const Color(0xff8e252f));
    p.polygon(const [
      Offset(11, 24),
      Offset(34, 24),
      Offset(34, 40),
      Offset(22, 38),
      Offset(11, 40),
    ], crimson);
    p.cell(17, 29, 12, 1.4, gold);
    p.cell(17, 35, 12, 1.4, goldShade);
    p.polygon(const [
      Offset(20, 27),
      Offset(24, 27),
      Offset(27, 32),
      Offset(24, 37),
      Offset(20, 37),
      Offset(17, 32),
    ], blue);
    p.cell(21, 28, 1.2, 8, Color.lerp(blue, Colors.white, .25)!);
    for (final x in [4.0, 24.0, 42.0]) {
      final y = 45.0 + (x % 3);
      p.cell(x, y, 11, 1.2, Color.lerp(far, Colors.white, .2)!);
      p.cell(x + 2, y - 1.2, 7, 1.5, Color.lerp(far, Colors.white, .32)!);
      p.cell(x + 4, y - 2.2, 3, 1.2, Color.lerp(far, Colors.white, .4)!);
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
  Widget build(BuildContext context) {
    final bob = frame == 1 || frame == 4 ? height / 72 : 0.0;
    final sway = switch (frame % 4) {
      1 => -.008,
      3 => .008,
      _ => 0.0,
    };

    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.rotate(
        angle: sway,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            'assets/art/knight.png',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
            frameBuilder: (context, child, imageFrame, wasLoaded) {
              if (wasLoaded || imageFrame != null) return child;
              return CustomPaint(painter: _PixelKnightPainter(frame: frame));
            },
            errorBuilder:
                (context, error, stackTrace) =>
                    CustomPaint(painter: _PixelKnightPainter(frame: frame)),
          ),
        ),
      ),
    );
  }
}

class _PixelKnightPainter extends CustomPainter {
  const _PixelKnightPainter({required this.frame});
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 34 || size.height < 50) {
      _paintMini(canvas, size);
      return;
    }
    final p = _SpriteCanvas(canvas, size, 48, 72);
    const ink = Color(0xff292329);
    const skin = Color(0xffa9654c);
    const skinLight = Color(0xffdc9570);
    const skinMid = Color(0xffbd7657);
    const skinShadow = Color(0xff713b35);
    const hair = Color(0xff42243b);
    const hairLight = Color(0xff7d4569);
    const hairShadow = Color(0xff241a2c);
    const steel = Color(0xffaebbbb);
    const steelLight = Color(0xffeef3e9);
    const steelMid = Color(0xffced8d3);
    const shadow = Color(0xff687778);
    const deepShadow = Color(0xff394a50);
    const teal = Color(0xff1f6468);
    const tealLight = Color(0xff3b9995);
    const tealShadow = Color(0xff173e49);
    const plum = Color(0xff68385e);
    const plumLight = Color(0xffa05b87);
    const plumShadow = Color(0xff3d2748);
    const leather = Color(0xff7a4934);
    const leatherLight = Color(0xffaa6a42);
    const gold = Color(0xffffca45);
    const goldShadow = Color(0xffb68032);
    const goldLight = Color(0xffffe47b);
    final bob = frame == 1 || frame == 4 ? 1.0 : 0.0;
    final stride = switch (frame % 4) {
      1 => 1.5,
      3 => -1.5,
      _ => 0.0,
    };

    // Ground shadow and a layered travelling cloak establish the silhouette.
    p.rect(8, 69, 34, 2, const Color(0x55292329));
    p.rect(13, 70, 25, 1, const Color(0x33292329));
    p.polygon([
      Offset(7, 25 + bob),
      Offset(14, 20 + bob),
      Offset(37, 22 + bob),
      Offset(43, 31 + bob),
      Offset(39, 58 + bob),
      Offset(31, 62 + bob),
      Offset(9, 58 + bob),
    ], plumShadow);
    p.polygon([
      Offset(8, 26 + bob),
      Offset(14, 22 + bob),
      Offset(20, 27 + bob),
      Offset(16, 57 + bob),
      Offset(10, 55 + bob),
    ], plum);
    p.rect(10, 28 + bob, 2, 24, plumLight);
    p.rect(38, 30 + bob, 2, 24, plum);
    p.rect(39, 34 + bob, 1, 17, plumLight);

    // Hair uses a high-resolution asymmetric silhouette and several highlights.
    p.polygon([
      Offset(14, 8 + bob),
      Offset(17, 3 + bob),
      Offset(27, 1 + bob),
      Offset(36, 5 + bob),
      Offset(39, 12 + bob),
      Offset(36, 21 + bob),
      Offset(32, 24 + bob),
      Offset(16, 22 + bob),
      Offset(11, 17 + bob),
    ], hairShadow);
    p.polygon([
      Offset(15, 9 + bob),
      Offset(18, 5 + bob),
      Offset(27, 3 + bob),
      Offset(35, 6 + bob),
      Offset(37, 12 + bob),
      Offset(33, 18 + bob),
      Offset(16, 18 + bob),
      Offset(13, 15 + bob),
    ], hair);
    p.rect(18, 5 + bob, 9, 2, hairLight);
    p.rect(15, 8 + bob, 6, 2, hairLight);
    p.rect(32, 7 + bob, 3, 8, hairLight);
    p.rect(12, 14 + bob, 4, 10, hair);
    p.rect(14, 20 + bob, 3, 5, hairLight);

    // Three-quarter face with readable eye, brow, nose, ear, and jaw shading.
    p.polygon([
      Offset(17, 9 + bob),
      Offset(31, 8 + bob),
      Offset(35, 12 + bob),
      Offset(34, 20 + bob),
      Offset(29, 25 + bob),
      Offset(19, 23 + bob),
      Offset(15, 18 + bob),
    ], skinShadow);
    p.polygon([
      Offset(18, 10 + bob),
      Offset(30, 9 + bob),
      Offset(33, 12 + bob),
      Offset(32, 19 + bob),
      Offset(28, 23 + bob),
      Offset(20, 22 + bob),
      Offset(17, 18 + bob),
    ], skin);
    p.rect(19, 11 + bob, 4, 8, skinLight);
    p.rect(20, 10 + bob, 7, 2, skinMid);
    p.rect(27, 13 + bob, 4, 1, hairShadow);
    p.rect(29, 14 + bob, 2, 2, ink);
    p.rect(29, 14 + bob, 1, 1, steelLight);
    p.rect(31, 16 + bob, 2, 2, skinMid);
    p.rect(26, 21 + bob, 5, 1, skinShadow);
    p.rect(34, 14 + bob, 3, 6, skinShadow);
    p.rect(35, 15 + bob, 1, 2, skinLight);
    p.rect(22, 22 + bob, 7, 4, skinShadow);

    // Articulated pauldrons, breastplate, tabard, belt, and tiny rivets.
    p.polygon([
      Offset(10, 28 + bob),
      Offset(14, 24 + bob),
      Offset(21, 24 + bob),
      Offset(23, 30 + bob),
      Offset(19, 34 + bob),
      Offset(11, 33 + bob),
    ], ink);
    p.polygon([
      Offset(11, 28 + bob),
      Offset(15, 25 + bob),
      Offset(20, 25 + bob),
      Offset(21, 30 + bob),
      Offset(18, 32 + bob),
      Offset(12, 31 + bob),
    ], steel);
    p.rect(13, 27 + bob, 6, 2, steelLight);
    p.rect(12, 31 + bob, 2, 1, shadow);
    p.polygon([
      Offset(28, 27 + bob),
      Offset(34, 24 + bob),
      Offset(40, 27 + bob),
      Offset(41, 33 + bob),
      Offset(34, 34 + bob),
      Offset(29, 31 + bob),
    ], ink);
    p.polygon([
      Offset(29, 28 + bob),
      Offset(34, 25 + bob),
      Offset(39, 28 + bob),
      Offset(39, 31 + bob),
      Offset(34, 32 + bob),
      Offset(30, 30 + bob),
    ], steelMid);
    p.rect(33, 26 + bob, 5, 2, steelLight);
    p.polygon([
      Offset(16, 27 + bob),
      Offset(32, 27 + bob),
      Offset(36, 35 + bob),
      Offset(34, 51 + bob),
      Offset(14, 51 + bob),
      Offset(12, 35 + bob),
    ], deepShadow);
    p.polygon([
      Offset(17, 28 + bob),
      Offset(30, 28 + bob),
      Offset(33, 35 + bob),
      Offset(31, 49 + bob),
      Offset(16, 49 + bob),
      Offset(14, 35 + bob),
    ], steel);
    p.polygon([
      Offset(18, 29 + bob),
      Offset(23, 29 + bob),
      Offset(22, 48 + bob),
      Offset(17, 48 + bob),
      Offset(15, 35 + bob),
    ], steelLight);
    p.rect(24, 30 + bob, 2, 18, shadow);
    p.rect(29, 33 + bob, 2, 14, deepShadow);
    p.polygon([
      Offset(18, 33 + bob),
      Offset(30, 33 + bob),
      Offset(31, 49 + bob),
      Offset(17, 49 + bob),
    ], teal);
    p.rect(18, 34 + bob, 3, 13, tealLight);
    p.rect(28, 35 + bob, 2, 12, tealShadow);
    p.rect(14, 48 + bob, 21, 4, leather);
    p.rect(16, 48 + bob, 17, 1, leatherLight);
    p.rect(23, 48 + bob, 3, 4, goldShadow);
    p.rect(24, 49 + bob, 1, 1, goldLight);
    for (final x in [17.0, 30.0]) {
      p.rect(x, 31 + bob, 1, 1, steelLight);
    }

    // Hands cradle the recovered crown in front of the armor.
    p.polygon([
      Offset(10, 35 + bob),
      Offset(15, 32 + bob),
      Offset(19, 38 + bob),
      Offset(17, 43 + bob),
      Offset(13, 42 + bob),
    ], steelMid);
    p.rect(14, 40 + bob, 5, 4, skinShadow);
    p.rect(15, 39 + bob, 4, 4, skinLight);
    p.polygon([
      Offset(38, 35 + bob),
      Offset(34, 32 + bob),
      Offset(30, 38 + bob),
      Offset(32, 43 + bob),
      Offset(36, 42 + bob),
    ], shadow);
    p.rect(29, 40 + bob, 5, 4, skinShadow);
    p.rect(30, 39 + bob, 4, 4, skinMid);
    p.rect(19, 38 + bob, 11, 8, goldShadow);
    p.rect(20, 37 + bob, 2, 8, gold);
    p.rect(23, 34 + bob, 2, 11, gold);
    p.rect(28, 37 + bob, 2, 8, gold);
    p.rect(20, 42 + bob, 10, 4, gold);
    p.rect(21, 42 + bob, 7, 1, goldLight);
    p.rect(21, 46 + bob, 8, 2, goldShadow);
    p.rect(23, 39 + bob, 1, 1, const Color(0xffd95656));
    p.rect(26, 39 + bob, 1, 1, const Color(0xff3b63b7));

    // Separate greaves and boots animate with a restrained two-pixel stride.
    p.polygon([
      Offset(15 - stride, 51 + bob),
      Offset(23, 51 + bob),
      Offset(22 - stride, 65 + bob),
      Offset(13 - stride, 65 + bob),
    ], ink);
    p.polygon([
      Offset(16 - stride, 52 + bob),
      Offset(22, 52 + bob),
      Offset(20.5 - stride, 64 + bob),
      Offset(14.5 - stride, 64 + bob),
    ], steel);
    p.rect(16 - stride, 53 + bob, 2, 10, steelLight);
    p.rect(20 - stride, 54 + bob, 1.5, 9, shadow);
    p.polygon([
      Offset(26, 51 + bob),
      Offset(34 + stride, 51 + bob),
      Offset(36 + stride, 65 + bob),
      Offset(27 + stride, 65 + bob),
    ], ink);
    p.polygon([
      Offset(27, 52 + bob),
      Offset(33 + stride, 52 + bob),
      Offset(34.5 + stride, 64 + bob),
      Offset(28 + stride, 64 + bob),
    ], shadow);
    p.rect(28 + stride, 53 + bob, 2, 10, steelLight);
    p.rect(32 + stride, 54 + bob, 1.5, 9, deepShadow);
    p.rect(10 - stride, 64 + bob, 13, 4, ink);
    p.rect(12 - stride, 64 + bob, 10, 2, leather);
    p.rect(26 + stride, 64 + bob, 14, 4, ink);
    p.rect(27 + stride, 64 + bob, 11, 2, leather);
    p.rect(12 - stride, 64 + bob, 5, 1, leatherLight);
    p.rect(28 + stride, 64 + bob, 5, 1, leatherLight);
  }

  void _paintMini(Canvas canvas, Size size) {
    final p = _SpriteCanvas(canvas, size, 24, 36);
    const ink = Color(0xff292329);
    const hair = Color(0xff4a2638);
    const hairLight = Color(0xff75405c);
    const skin = Color(0xffa96d4e);
    const skinLight = Color(0xffce8c66);
    const steel = Color(0xffc3c9c6);
    const steelLight = Color(0xffedf0e8);
    const shadow = Color(0xff6f7778);
    const teal = Color(0xff276b6b);
    const plum = Color(0xff713f67);
    const gold = Color(0xffffca45);
    const goldShadow = Color(0xffb68032);
    final bob = frame.isOdd ? 1.0 : 0.0;
    final stride =
        frame % 4 == 1
            ? 1.0
            : frame % 4 == 3
            ? -1.0
            : 0.0;

    p.rect(7, 2 + bob, 10, 3, hair);
    p.rect(5, 5 + bob, 13, 5, hair);
    p.rect(7, 4 + bob, 5, 2, hairLight);
    p.rect(7, 7 + bob, 10, 7, skin);
    p.rect(8, 8 + bob, 2, 5, skinLight);
    p.rect(14, 9 + bob, 2, 1, ink);
    p.rect(5, 13 + bob, 14, 4, steel);
    p.rect(7, 13 + bob, 7, 1, steelLight);
    p.rect(3, 16 + bob, 18, 12, ink);
    p.rect(5, 16 + bob, 14, 11, teal);
    p.rect(2, 15 + bob, 4, 14, plum);
    p.rect(18, 15 + bob, 4, 14, plum);
    p.rect(8, 20 + bob, 8, 5, goldShadow);
    p.rect(8, 19 + bob, 2, 6, gold);
    p.rect(11, 17 + bob, 2, 8, gold);
    p.rect(14, 19 + bob, 2, 6, gold);
    p.rect(9, 22 + bob, 7, 3, gold);
    p.rect(5 - stride, 27 + bob, 6, 6, ink);
    p.rect(6 - stride, 27 + bob, 4, 5, steel);
    p.rect(13 + stride, 27 + bob, 6, 6, ink);
    p.rect(14 + stride, 27 + bob, 4, 5, shadow);
    p.rect(3 - stride, 32 + bob, 8, 3, ink);
    p.rect(13 + stride, 32 + bob, 8, 3, ink);
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
  Widget build(BuildContext context) {
    final bob = frame == 2 || frame == 5 ? height / 72 : 0.0;
    final sway = switch (frame % 4) {
      1 => -.008,
      3 => .008,
      _ => 0.0,
    };

    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.rotate(
        angle: sway,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(
            'assets/art/queen.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
            frameBuilder: (context, child, imageFrame, wasLoaded) {
              if (wasLoaded || imageFrame != null) return child;
              return CustomPaint(painter: _PixelQueenPainter(frame));
            },
            errorBuilder:
                (context, error, stackTrace) =>
                    CustomPaint(painter: _PixelQueenPainter(frame)),
          ),
        ),
      ),
    );
  }
}

class _PixelQueenPainter extends CustomPainter {
  const _PixelQueenPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _SpriteCanvas(canvas, size, 48, 72);
    const ink = Color(0xff211d29);
    const skin = Color(0xff70442f);
    const skinLight = Color(0xffa76847);
    const skinShadow = Color(0xff4a2a26);
    const hair = Color(0xff292733);
    const hairLight = Color(0xff50435c);
    const hairShadow = Color(0xff171724);
    const blue = Color(0xff203d78);
    const blueLight = Color(0xff315a9c);
    const blueShadow = Color(0xff152951);
    const ivory = Color(0xfff4ead4);
    const ivoryShadow = Color(0xffc9bea7);
    const crimson = Color(0xff9d2f3c);
    const crimsonLight = Color(0xffd14a52);
    const gold = Color(0xffffca45);
    const goldShadow = Color(0xffb68032);
    const goldLight = Color(0xffffe47b);
    final bob = frame == 2 || frame == 5 ? 1.0 : 0.0;

    p.rect(6, 69, 37, 2, const Color(0x55211d29));

    // Crown and elaborate hair frame a small, expressive three-quarter face.
    p.polygon([
      Offset(12, 10 + bob),
      Offset(16, 5 + bob),
      Offset(25, 3 + bob),
      Offset(35, 7 + bob),
      Offset(39, 14 + bob),
      Offset(36, 28 + bob),
      Offset(30, 30 + bob),
      Offset(13, 26 + bob),
      Offset(9, 18 + bob),
    ], hairShadow);
    p.polygon([
      Offset(13, 11 + bob),
      Offset(17, 7 + bob),
      Offset(25, 5 + bob),
      Offset(34, 8 + bob),
      Offset(37, 14 + bob),
      Offset(34, 24 + bob),
      Offset(14, 23 + bob),
      Offset(11, 17 + bob),
    ], hair);
    p.rect(16, 7 + bob, 8, 2, hairLight);
    p.rect(13, 11 + bob, 5, 3, hairLight);
    p.rect(32, 10 + bob, 3, 11, hairLight);
    p.rect(11, 20 + bob, 5, 12, hair);
    p.rect(34, 20 + bob, 4, 12, hair);

    p.polygon([
      Offset(16, 11 + bob),
      Offset(30, 10 + bob),
      Offset(34, 14 + bob),
      Offset(32, 23 + bob),
      Offset(27, 27 + bob),
      Offset(18, 24 + bob),
      Offset(14, 18 + bob),
    ], skinShadow);
    p.polygon([
      Offset(17, 12 + bob),
      Offset(29, 11 + bob),
      Offset(32, 14 + bob),
      Offset(30, 22 + bob),
      Offset(26, 25 + bob),
      Offset(19, 23 + bob),
      Offset(16, 18 + bob),
    ], skin);
    p.rect(18, 13 + bob, 4, 8, skinLight);
    p.rect(26, 15 + bob, 4, 1, hair);
    p.rect(28, 16 + bob, 2, 2, ink);
    p.rect(28, 16 + bob, 1, 1, ivory);
    p.rect(30, 18 + bob, 2, 2, skinLight);
    p.rect(25, 22 + bob, 5, 1, skinShadow);
    p.rect(33, 16 + bob, 3, 6, skinShadow);
    p.rect(21, 24 + bob, 7, 4, skinShadow);

    p.rect(14, 7 + bob, 22, 3, goldShadow);
    p.rect(15, 6 + bob, 20, 2, gold);
    p.polygon([
      Offset(15, 7 + bob),
      Offset(15, 1 + bob),
      Offset(20, 6 + bob),
      Offset(24, 0 + bob),
      Offset(28, 6 + bob),
      Offset(34, 2 + bob),
      Offset(34, 7 + bob),
    ], gold);
    p.rect(16, 6 + bob, 17, 1, goldLight);
    p.rect(18, 5 + bob, 2, 2, const Color(0xffd94b58));
    p.rect(23, 3 + bob, 2, 2, const Color(0xff4e6fc4));
    p.rect(29, 5 + bob, 2, 2, const Color(0xff63a67b));

    // Embroidered mantle, fitted bodice, layered skirt, and ivory sleeves.
    p.polygon([
      Offset(10, 29 + bob),
      Offset(16, 25 + bob),
      Offset(32, 25 + bob),
      Offset(40, 30 + bob),
      Offset(36, 38 + bob),
      Offset(13, 38 + bob),
    ], ivoryShadow);
    p.polygon([
      Offset(12, 29 + bob),
      Offset(17, 26 + bob),
      Offset(31, 26 + bob),
      Offset(38, 30 + bob),
      Offset(34, 35 + bob),
      Offset(14, 35 + bob),
    ], ivory);
    p.rect(18, 27 + bob, 12, 2, gold);
    p.rect(21, 29 + bob, 6, 2, crimson);
    p.polygon([
      Offset(14, 34 + bob),
      Offset(34, 34 + bob),
      Offset(36, 53 + bob),
      Offset(12, 53 + bob),
    ], blueShadow);
    p.polygon([
      Offset(16, 35 + bob),
      Offset(32, 35 + bob),
      Offset(33, 51 + bob),
      Offset(14, 51 + bob),
    ], blue);
    p.rect(16, 36 + bob, 4, 14, blueLight);
    p.rect(29, 37 + bob, 3, 13, blueShadow);
    p.polygon([
      Offset(21, 35 + bob),
      Offset(28, 35 + bob),
      Offset(28, 50 + bob),
      Offset(24, 47 + bob),
      Offset(20, 50 + bob),
    ], crimson);
    p.rect(22, 36 + bob, 2, 11, crimsonLight);
    p.rect(12, 42 + bob, 24, 3, goldShadow);
    p.rect(14, 42 + bob, 20, 1, goldLight);
    p.rect(22, 42 + bob, 4, 3, gold);

    p.polygon([
      Offset(11, 30 + bob),
      Offset(5, 34 + bob),
      Offset(4, 50 + bob),
      Offset(10, 52 + bob),
      Offset(15, 36 + bob),
    ], ivoryShadow);
    p.polygon([
      Offset(10, 31 + bob),
      Offset(7, 34 + bob),
      Offset(6, 48 + bob),
      Offset(10, 49 + bob),
      Offset(13, 36 + bob),
    ], ivory);
    p.rect(7, 47 + bob, 5, 4, skinShadow);
    p.rect(8, 46 + bob, 4, 4, skinLight);
    p.polygon([
      Offset(37, 30 + bob),
      Offset(43, 34 + bob),
      Offset(44, 50 + bob),
      Offset(38, 52 + bob),
      Offset(33, 36 + bob),
    ], ivoryShadow);
    p.polygon([
      Offset(38, 31 + bob),
      Offset(41, 34 + bob),
      Offset(42, 48 + bob),
      Offset(38, 49 + bob),
      Offset(35, 36 + bob),
    ], ivory);
    p.rect(37, 47 + bob, 5, 4, skinShadow);
    p.rect(37, 46 + bob, 4, 4, skin);

    p.polygon([
      Offset(12, 50 + bob),
      Offset(36, 50 + bob),
      Offset(43, 68 + bob),
      Offset(5, 68 + bob),
    ], blueShadow);
    p.polygon([
      Offset(14, 51 + bob),
      Offset(34, 51 + bob),
      Offset(39, 66 + bob),
      Offset(9, 66 + bob),
    ], blue);
    p.polygon([
      Offset(16, 52 + bob),
      Offset(22, 52 + bob),
      Offset(18, 65 + bob),
      Offset(11, 65 + bob),
    ], blueLight);
    p.polygon([
      Offset(25, 51 + bob),
      Offset(31, 51 + bob),
      Offset(36, 66 + bob),
      Offset(27, 66 + bob),
    ], crimson);
    p.rect(28, 53 + bob, 2, 11, crimsonLight);
    p.rect(6, 66 + bob, 36, 3, goldShadow);
    p.rect(9, 66 + bob, 30, 1, goldLight);
    for (final x in [14.0, 23.0, 32.0]) {
      p.rect(x, 55 + bob, 1, 1, gold);
      p.rect(x + 2, 58 + bob, 1, 1, goldLight);
    }
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

  void polygon(List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final path = Path();
    final first = points.first;
    path.moveTo(
      _snap(size.width * first.dx / 100),
      _snap(size.height * first.dy / 100),
    );
    for (final point in points.skip(1)) {
      path.lineTo(
        _snap(size.width * point.dx / 100),
        _snap(size.height * point.dy / 100),
      );
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = false,
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

  void polygon(List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final unit = math.min(
      size.width / logicalWidth,
      size.height / logicalHeight,
    );
    final originX = (size.width - logicalWidth * unit) / 2;
    final originY = (size.height - logicalHeight * unit) / 2;
    Offset convert(Offset point) => Offset(
      (originX + point.dx * unit).roundToDouble(),
      (originY + point.dy * unit).roundToDouble(),
    );

    final path =
        Path()..moveTo(convert(points.first).dx, convert(points.first).dy);
    for (final point in points.skip(1)) {
      final converted = convert(point);
      path.lineTo(converted.dx, converted.dy);
    }
    path.close();
    canvas.drawPath(
      path,
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
