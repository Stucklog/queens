@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
  });

  testWidgets('all knight motions retain one coherent character design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 250);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('knight-motion-atlas'),
              child: ColoredBox(
                color: const Color(0xff091329),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 1.58,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      for (final animation in KnightAnimation.values)
                        _MotionTile(animation: animation),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await _expectStrictGolden(
      find.byKey(const ValueKey('knight-motion-atlas')),
      'goldens/knight_motion_atlas.png',
    );
  });

  testWidgets('all 28 active knight frames remain anchored and isolated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 675);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('knight-frame-atlas'),
            child: ColoredBox(
              color: const Color(0xff091329),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  children: [
                    for (final animation in KnightAnimation.values)
                      for (var frame = 0; frame < 4; frame++)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff293756),
                            border: Border.all(color: const Color(0xff8595be)),
                          ),
                          child: PixelKnightSprite(
                            animation: animation,
                            frame: frame,
                            width: 118,
                            height: 96,
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
    await tester.pumpAndSettle();

    await _expectStrictGolden(
      find.byKey(const ValueKey('knight-frame-atlas')),
      'goldens/knight_frame_atlas.png',
    );
  });
}

class _MotionTile extends StatelessWidget {
  const _MotionTile({required this.animation});

  final KnightAnimation animation;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: Theme.of(context).colorScheme.secondary,
        width: 2,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: PixelKnightSprite(
            animation: animation,
            frame: _representativeFrame(animation),
            width: 110,
            height: 66,
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(
            animation.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    ),
  );

  static int _representativeFrame(KnightAnimation animation) =>
      switch (animation) {
        KnightAnimation.walk => 2,
        KnightAnimation.bounce => 1,
        KnightAnimation.attack => 1,
        KnightAnimation.defend => 2,
        KnightAnimation.damage => 2,
        KnightAnimation.special => 2,
        KnightAnimation.surprised => 1,
      };
}

Future<void> _expectStrictGolden(Finder finder, String goldenPath) async {
  final previousComparator = goldenFileComparator;
  goldenFileComparator = _SpriteGoldenFileComparator(
    Uri.parse('test/knight_animation_golden_test.dart'),
    precisionTolerance: .0025,
  );
  try {
    await expectLater(finder, matchesGoldenFile(goldenPath));
  } finally {
    goldenFileComparator = previousComparator;
  }
}

/// Sprite sheets are deterministic enough to use one tenth of the app-wide
/// rasterization tolerance, so a single missing or misaligned pose fails.
class _SpriteGoldenFileComparator extends LocalFileComparator {
  _SpriteGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
