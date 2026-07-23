import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/widgets/pixel_art.dart';

const _combatA = PixelKnightSprite.defaultCombatAssetPath;
const _combatB =
    'assets/art/arcs/crimson-ledger/characters/elian-voss_combat.png';
const _combatC =
    'assets/art/arcs/inn-at-the-end-of-yesterday/characters/tamsin-reed_combat.png';
const _combatD =
    'assets/art/arcs/ninth-library/characters/oriel-marr_combat.png';
const _combatE =
    'assets/art/arcs/oathstorm-fleet/characters/yrsa-vale_combat.png';

const _finisherA = PixelKnightSprite.defaultFinisherAssetPath;
const _finisherB =
    'assets/art/arcs/crimson-ledger/characters/elian-voss_finishers.png';
const _finisherC =
    'assets/art/arcs/inn-at-the-end-of-yesterday/characters/tamsin-reed_finishers.png';

void main() {
  setUp(PixelKnightSprite.debugClearAtlasCaches);

  testWidgets('preload LRUs are bounded and isolated by atlas kind', (
    tester,
  ) async {
    await _preloadCombat(tester, _combatA);
    await _preloadCombat(tester, _combatB);
    expect(PixelKnightSprite.debugCachedCombatAssetPaths, [_combatA, _combatB]);

    await _preloadCombat(tester, _combatC);
    expect(PixelKnightSprite.debugCachedCombatAssetPaths, [_combatB, _combatC]);
    expect(PixelKnightSprite.debugCachedFinisherAssetPaths, isEmpty);

    await _preloadFinisher(tester, _finisherA);
    await _preloadFinisher(tester, _finisherB);
    await _preloadFinisher(tester, _finisherC);
    expect(PixelKnightSprite.debugCachedFinisherAssetPaths, [
      _finisherB,
      _finisherC,
    ]);
    expect(PixelKnightSprite.debugCachedCombatAssetPaths, [_combatB, _combatC]);

    PixelKnightSprite.debugClearAtlasCaches();
  });

  testWidgets('mounted sprites keep a shared atlas leased until all unmount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            PixelKnightSprite(
              key: ValueKey('first-knight'),
              frame: 0,
              combatAssetPath: _combatA,
            ),
            PixelKnightSprite(
              key: ValueKey('second-knight'),
              frame: 0,
              combatAssetPath: _combatA,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _preloadCombat(tester, _combatB);
    await _preloadCombat(tester, _combatC);
    expect(PixelKnightSprite.debugCachedCombatAssetPaths, contains(_combatA));
    expect(
      PixelKnightSprite.debugCachedCombatAssetPaths,
      isNot(contains(_combatB)),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: PixelKnightSprite(
          key: ValueKey('second-knight'),
          frame: 0,
          combatAssetPath: _combatA,
        ),
      ),
    );
    await tester.pump();
    await _preloadCombat(tester, _combatD);
    expect(PixelKnightSprite.debugCachedCombatAssetPaths, contains(_combatA));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _preloadCombat(tester, _combatE);
    expect(
      PixelKnightSprite.debugCachedCombatAssetPaths,
      isNot(contains(_combatA)),
    );

    PixelKnightSprite.debugClearAtlasCaches();
  });
}

Future<void> _preloadCombat(WidgetTester tester, String assetPath) async {
  await tester.runAsync(
    () => PixelKnightSprite.preloadCommon(combatAssetPath: assetPath),
  );
}

Future<void> _preloadFinisher(WidgetTester tester, String assetPath) async {
  await tester.runAsync(
    () => PixelKnightSprite.preloadFinishers(finisherAssetPath: assetPath),
  );
}
