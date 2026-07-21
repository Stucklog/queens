@Tags(['golden'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/boss_finisher_cutscene.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_art.dart';

late List<JourneyChapter> _originChapters;

void main() {
  late List<CombatEncounter> allOpponents;

  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
    final metadata =
        jsonDecode(
              await rootBundle.loadString(
                'assets/content/arcs/origin/arc.json',
              ),
            )
            as Map<String, Object?>;
    final opponents = <CombatEncounter>[];
    final chapters = <JourneyChapter>[];
    for (final chapterValue in metadata['chapters']! as List<Object?>) {
      final chapter = chapterValue! as Map<String, Object?>;
      chapters.add(JourneyChapter.fromJson(chapter));
      opponents.add(
        ChapterBoss.fromJson(chapter['boss']! as Map<String, Object?>),
      );
      for (final encounterValue in chapter['encounters']! as List<Object?>) {
        opponents.add(
          ChapterEnemy.fromJson(encounterValue! as Map<String, Object?>),
        );
      }
    }
    allOpponents = opponents;
    _originChapters = chapters;
  });

  testWidgets(
    'boss finishes escalate through eight distinct spectacle tiers',
    (tester) async {
      tester.view.physicalSize = const Size(760, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _precacheOpponents(
        tester,
        allOpponents.where((enemy) => enemy.isBoss),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: RegaliaTheme.midnight(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('boss-spectacle-atlas'),
                child: ColoredBox(
                  color: const Color(0xff091329),
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    crossAxisCount: 2,
                    childAspectRatio: 2.75,
                    children: [
                      for (final chapter in _originChapters)
                        CombatPresentationBar(
                          animation: finisherForSpectacle(
                            chapter.boss.spectacleLevel,
                          ),
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
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('boss-spectacle-atlas')),
        matchesGoldenFile('goldens/combat_boss_spectacle_atlas.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'all production opponent sprites remain readable at rest',
    (tester) async {
      tester.view.physicalSize = const Size(760, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _precacheOpponents(tester, allOpponents);
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
                      for (final encounter in allOpponents)
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
                                  encounter.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: PixelEnemySprite(
                                    encounter: encounter,
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
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('boss-sprite-atlas')),
        matchesGoldenFile('goldens/combat_boss_sprite_atlas.png'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'final boss atlas has six readable four-frame reactions',
    (tester) async {
      tester.view.physicalSize = const Size(520, 730);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final finalBoss = allOpponents.where((enemy) => enemy.isBoss).last;
      const reactionMoves = [
        KnightAnimation.bounce,
        KnightAnimation.attack,
        KnightAnimation.defend,
        KnightAnimation.damage,
        KnightAnimation.surprised,
        KnightAnimation.regaliaNova,
      ];

      await _precacheOpponents(tester, [finalBoss]);
      await tester.pumpWidget(
        MaterialApp(
          theme: RegaliaTheme.midnight(),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('final-boss-reaction-atlas'),
              child: ColoredBox(
                color: const Color(0xff091329),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 4,
                  childAspectRatio: 1.08,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  children: [
                    for (final move in reactionMoves)
                      for (var frame = 0; frame < 4; frame++)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff293756),
                            border: Border.all(color: const Color(0xff8595be)),
                          ),
                          child: PixelEnemySprite(
                            encounter: finalBoss,
                            stimulus: move,
                            frame: frame,
                            width: 110,
                            height: 94,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('final-boss-reaction-atlas')),
        matchesGoldenFile('goldens/combat_final_boss_reactions.png'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('final boss finisher attack fills the narrow layout', (
    tester,
  ) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(390, 844),
      beat: _BossFinisherGoldenBeat.attack,
      file: 'goldens/boss_finisher_narrow_attack_midnight.png',
    );
  });

  testWidgets('final boss defeat fills the narrow layout', (tester) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(390, 844),
      beat: _BossFinisherGoldenBeat.defeat,
      file: 'goldens/boss_finisher_narrow_defeat_midnight.png',
    );
  });

  testWidgets('final boss victory fills the narrow layout', (tester) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(390, 844),
      beat: _BossFinisherGoldenBeat.victory,
      file: 'goldens/boss_finisher_narrow_victory_midnight.png',
    );
  });

  testWidgets('final boss finisher attack fills the wide layout', (
    tester,
  ) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(1180, 800),
      beat: _BossFinisherGoldenBeat.attack,
      file: 'goldens/boss_finisher_wide_attack_midnight.png',
    );
  });

  testWidgets('final boss defeat fills the wide layout', (tester) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(1180, 800),
      beat: _BossFinisherGoldenBeat.defeat,
      file: 'goldens/boss_finisher_wide_defeat_midnight.png',
    );
  });

  testWidgets('final boss victory fills the wide layout', (tester) async {
    await _goldenFinalBossFinisher(
      tester,
      finalBoss: allOpponents.where((enemy) => enemy.isBoss).last,
      size: const Size(1180, 800),
      beat: _BossFinisherGoldenBeat.victory,
      file: 'goldens/boss_finisher_wide_victory_midnight.png',
    );
  });

  testWidgets('Drowned Acolyte keeps every reaction facing the knight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(760, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final acolyte = allOpponents.singleWhere(
      (enemy) => enemy.id == 'regalia:enemy/origin/drowned-acolyte',
    );
    await _precacheOpponents(tester, [acolyte]);
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('drowned-acolyte-reactions'),
            child: ColoredBox(
              color: const Color(0xff091329),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'KNIGHT IS ON THE LEFT',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: _OpponentReactionCard(encounter: acolyte)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('drowned-acolyte-reactions')),
      matchesGoldenFile('goldens/combat_drowned_acolyte_reactions.png'),
    );
  });

  testWidgets(
    'all opponent reaction frames face the knight and stay in bounds',
    (tester) async {
      // Keep every reaction large enough for art review. The previous 4 x 6
      // overview reduced each 192 px source frame to roughly 50 px, which hid
      // clipped anatomy and small fragments at cell boundaries.
      tester.view.physicalSize = const Size(1800, 6600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _precacheOpponents(tester, allOpponents);
      await tester.pumpWidget(
        MaterialApp(
          theme: RegaliaTheme.midnight(),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('all-opponent-reactions'),
              child: ColoredBox(
                color: const Color(0xff091329),
                child: Column(
                  children: [
                    for (var row = 0; row < 8; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var column = 0; column < 3; column++)
                              Expanded(
                                child: _OpponentReactionCard(
                                  encounter: allOpponents[row * 3 + column],
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
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('all-opponent-reactions')),
        matchesGoldenFile('goldens/combat_all_opponent_reactions.png'),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _goldenFinalBossFinisher(
  WidgetTester tester, {
  required CombatEncounter finalBoss,
  required Size size,
  required _BossFinisherGoldenBeat beat,
  required String file,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final chapter = _originChapters.last;
  final presentation = BossFinisherPresentation.forSpectacle(
    chapter.boss.spectacleLevel,
  );
  await _precacheOpponents(tester, [finalBoss]);
  final precacheContext = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(
    () => precacheImage(AssetImage(chapter.artAsset), precacheContext),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.forChapter(chapter),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: RepaintBoundary(
          key: const ValueKey('boss-finisher-golden'),
          child: BossFinisherCutscene(
            boss: chapter.boss,
            background: PixelLandscape(
              chapter: chapter,
              brightness: Brightness.dark,
              placement: PixelArtPlacement.story,
            ),
            accentColor: chapter.palette.secondary,
            energyColor: chapter.palette.primary,
            onFinished: () {},
          ),
        ),
      ),
    ),
  );
  switch (beat) {
    case _BossFinisherGoldenBeat.attack:
      await tester.pump(presentation.finisher.presentationDuration * .58);
    case _BossFinisherGoldenBeat.defeat:
      await tester.pump(
        presentation.timing.bossDefeatStart +
            presentation.timing.bossDefeat * .82,
      );
    case _BossFinisherGoldenBeat.victory:
      await tester.pump(presentation.timing.victoryStart);
      await tester.pump(KnightAnimation.special.presentationDuration * .52);
  }
  await expectLater(
    find.byKey(const ValueKey('boss-finisher-golden')),
    matchesGoldenFile(file),
  );
  await tester.pumpWidget(const SizedBox.shrink());
}

enum _BossFinisherGoldenBeat { attack, defeat, victory }

class _OpponentReactionCard extends StatelessWidget {
  const _OpponentReactionCard({required this.encounter});

  final CombatEncounter encounter;

  static const _moves = [
    KnightAnimation.bounce,
    KnightAnimation.attack,
    KnightAnimation.defend,
    KnightAnimation.damage,
    KnightAnimation.surprised,
    KnightAnimation.regaliaNova,
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff293756),
        border: Border.all(color: const Color(0xffd5b343), width: 2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
            child: Text(
              encounter.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(4),
              crossAxisCount: 4,
              childAspectRatio: 1.08,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              children: [
                for (final move in _moves)
                  for (var frame = 0; frame < 4; frame++)
                    ColoredBox(
                      color: const Color(0xff1e2948),
                      child: LayoutBuilder(
                        builder:
                            (context, constraints) => PixelEnemySprite(
                              encounter: encounter,
                              stimulus: move,
                              frame: frame,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                            ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _precacheOpponents(
  WidgetTester tester,
  Iterable<CombatEncounter> opponents,
) async {
  await tester.pumpWidget(const MaterialApp(home: Scaffold()));
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(
    () => Future.wait([
      for (final opponent in opponents)
        precacheImage(AssetImage(opponent.spriteAsset), context),
    ]),
  );
}
