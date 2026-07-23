@Tags(['golden'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  late JourneyChapter chapter;

  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    final metadata =
        jsonDecode(
              await rootBundle.loadString(
                'assets/content/arcs/sun-sail-covenant/arc.json',
              ),
            )
            as Map<String, Object?>;
    chapter = JourneyChapter.fromJson(
      (metadata['chapters']! as List<Object?>).first! as Map<String, Object?>,
    );
  });

  testWidgets('Dimming Sun chapter art remains readable in its story frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.forChapter(chapter),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('dimming-sun-chapter-golden'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PixelStoryScene(
                  chapter: chapter,
                  kind: PixelSceneKind.chapter,
                  semanticLabel:
                      "Nera's saffron sail banks around the Eclipse Hart "
                      'above a moon slipping into darkness.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _precache(tester, chapter.artAsset);

    await expectLater(
      find.byKey(const ValueKey('dimming-sun-chapter-golden')),
      matchesGoldenFile('goldens/sun_sail_dimming_sun_chapter.png'),
    );
  });

  testWidgets('Nera story idle keeps four coherent authored poses', (
    tester,
  ) async {
    const assetPath =
        'assets/art/arcs/sun-sail-covenant/characters/'
        'nera-venn_story_idle.png';
    tester.view.physicalSize = const Size(760, 280);
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
              key: ValueKey('nera-story-idle-golden'),
              child: ColoredBox(
                color: Color(0xff091329),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      for (var frame = 0; frame < 4; frame++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xff293756),
                                border: Border.fromBorderSide(
                                  BorderSide(
                                    color: Color(0xffd5b343),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StoryStripFrame(
                                    assetPath: assetPath,
                                    frame: frame,
                                    width: 144,
                                    height: 216,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'IDLE ${frame + 1}',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
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
      ),
    );
    await _precache(tester, assetPath);

    await expectLater(
      find.byKey(const ValueKey('nera-story-idle-golden')),
      matchesGoldenFile('goldens/sun_sail_nera_story_idle.png'),
    );
  });

  testWidgets('Eclipse Hart keeps all 24 reaction frames readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.forChapter(chapter),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('eclipse-hart-reactions-golden'),
              child: ColoredBox(
                color: const Color(0xff091329),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: EnemyReaction.values.length * 4,
                  itemBuilder: (context, index) {
                    final reaction = EnemyReaction.values[index ~/ 4];
                    final frame = index % 4;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xff293756),
                        border: Border.all(
                          color: const Color(0xffd5b343),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: PixelEnemySprite.preview(
                              encounter: chapter.boss,
                              reaction: reaction,
                              frame: frame,
                              width: 112,
                              height: 112,
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            bottom: 3,
                            child: Text(
                              '${reaction.label} ${frame + 1}',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _precache(tester, chapter.boss.spriteAsset);

    await expectLater(
      find.byKey(const ValueKey('eclipse-hart-reactions-golden')),
      matchesGoldenFile('goldens/sun_sail_eclipse_hart_reactions.png'),
    );
  });
}

Future<void> _precache(WidgetTester tester, String assetPath) async {
  final context = tester.element(find.byType(Scaffold));
  await tester.runAsync(() => precacheImage(AssetImage(assetPath), context));
  await tester.pumpAndSettle();
}

class _StoryStripFrame extends StatelessWidget {
  const _StoryStripFrame({
    required this.assetPath,
    required this.frame,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final int frame;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: ClipRect(
          child: Align(
            alignment: Alignment(-1 + (2 * frame / 3), 0),
            widthFactor: .25,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
