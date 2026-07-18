@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
  });

  testWidgets('boss finishes escalate through eight distinct spectacle tiers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('boss-spectacle-atlas'),
            child: ColoredBox(
              color: const Color(0xff091329),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                crossAxisCount: 2,
                childAspectRatio: 3.72,
                children: [
                  for (final chapter in journeyChapters)
                    CombatPresentationBar(
                      animation: KnightAnimation.special,
                      restartToken: chapter.boss.spectacleLevel,
                      knightLine: 'The final sigil ignites!',
                      encounter: chapter.boss,
                      onKnightCompleted: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    await expectLater(
      find.byKey(const ValueKey('boss-spectacle-atlas')),
      matchesGoldenFile('goldens/combat_boss_spectacle_atlas.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('all boss sprite families remain readable at rest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 248);
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
              key: const ValueKey('boss-sprite-atlas'),
              child: ColoredBox(
                color: const Color(0xff091329),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 4,
                  childAspectRatio: 1.65,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: [
                    for (final chapter in journeyChapters)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xff293756),
                          border: Border.all(
                            color: const Color(0xffd5b343),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                              child: Text(
                                chapter.boss.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: PixelEnemySprite(
                                  encounter: chapter.boss,
                                  stimulus: KnightAnimation.bounce,
                                  width: 78,
                                  height: 78,
                                ),
                              ),
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
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('boss-sprite-atlas')),
      matchesGoldenFile('goldens/combat_boss_sprite_atlas.png'),
    );
  });
}
