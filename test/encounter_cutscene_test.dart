import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/widgets/encounter_cutscene.dart';

void main() {
  testWidgets('standard encounter timeline releases at four seconds total', (
    tester,
  ) async {
    const timing = EncounterCutsceneTiming.standard;
    var completions = 0;

    expect(timing.entrance, const Duration(milliseconds: 900));
    expect(timing.hold, const Duration(milliseconds: 2100));
    expect(timing.exit, const Duration(milliseconds: 1000));
    expect(timing.total, const Duration(seconds: 4));
    expect(
      timing.entrance + timing.hold + timing.exit,
      const Duration(seconds: 4),
    );

    await tester.pumpWidget(
      _cutsceneHost(timing: timing, onFinished: () => completions++),
    );

    await tester.pump(timing.total - const Duration(milliseconds: 1));
    expect(completions, 0);
    expect(find.byKey(const ValueKey('encounter-cutscene')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1, reason: 'completion must be delivered only once');
  });

  testWidgets(
    'custom timing completes exactly and constructs destination lazily',
    (tester) async {
      const timing = EncounterCutsceneTiming(
        entrance: Duration(milliseconds: 25),
        hold: Duration(milliseconds: 40),
        exit: Duration(milliseconds: 55),
      );
      var cutsceneBuilds = 0;
      var destinationBuilds = 0;
      var completions = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: EncounterCutsceneTransition(
            cutsceneBuilder: (context, onFinished) {
              cutsceneBuilds++;
              return EncounterCutscene(
                background: _testBackground,
                knightArt: _testKnightArt,
                enemyArt: _testEnemyArt,
                enemyName: 'Clockwork Warden',
                timing: timing,
                onFinished: () {
                  completions++;
                  onFinished();
                },
              );
            },
            destinationBuilder: (context) {
              destinationBuilds++;
              return const ColoredBox(
                key: ValueKey('test-puzzle-destination'),
                color: Colors.teal,
              );
            },
          ),
        ),
      );

      expect(cutsceneBuilds, 1);
      expect(destinationBuilds, 0);
      expect(completions, 0);

      await tester.pump(timing.total - const Duration(milliseconds: 1));
      expect(completions, 0);
      expect(destinationBuilds, 0);
      expect(
        find.byKey(const ValueKey('test-puzzle-destination')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(completions, 1);
      expect(destinationBuilds, 1);
      expect(
        find.byKey(const ValueKey('encounter-cutscene-destination')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('test-puzzle-destination')),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
      expect(destinationBuilds, 1);
    },
  );

  testWidgets('combatants occupy opposite screen halves with both art slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const timing = EncounterCutsceneTiming(
      entrance: Duration(milliseconds: 100),
      hold: Duration(seconds: 1),
      exit: Duration(milliseconds: 100),
    );

    await tester.pumpWidget(_cutsceneHost(timing: timing));
    await tester.pump(const Duration(milliseconds: 150));

    final cutscene = tester.getRect(
      find.byKey(const ValueKey('encounter-cutscene')),
    );
    final enemyPanel = tester.getRect(
      find.byKey(const ValueKey('encounter-cutscene-enemy-panel')),
    );
    final knightPanel = tester.getRect(
      find.byKey(const ValueKey('encounter-cutscene-knight-panel')),
    );
    final enemySlot = find.byKey(
      const ValueKey('encounter-cutscene-enemy-art'),
    );
    final knightSlot = find.byKey(
      const ValueKey('encounter-cutscene-knight-art'),
    );

    expect(enemyPanel.top, cutscene.top);
    expect(enemyPanel.bottom, closeTo(cutscene.center.dy, .001));
    expect(knightPanel.top, closeTo(cutscene.center.dy, .001));
    expect(knightPanel.bottom, cutscene.bottom);
    expect(enemyPanel.overlaps(knightPanel), isFalse);

    expect(
      find.descendant(
        of: enemySlot,
        matching: find.byKey(const ValueKey('test-enemy-art')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: knightSlot,
        matching: find.byKey(const ValueKey('test-knight-art')),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(enemySlot).isEmpty, isFalse);
    expect(tester.getSize(knightSlot).isEmpty, isFalse);
    expect(find.text('Clockwork Warden'), findsOneWidget);
    expect(find.text('CROWN-BEARER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background is blurred and moves throughout the presentation', (
    tester,
  ) async {
    const timing = EncounterCutsceneTiming(
      entrance: Duration(milliseconds: 100),
      hold: Duration(seconds: 1),
      exit: Duration(milliseconds: 100),
    );
    await tester.pumpWidget(_cutsceneHost(timing: timing));

    final blur = find.byKey(
      const ValueKey('encounter-cutscene-blurred-background'),
    );
    final motion = find.byKey(
      const ValueKey('encounter-cutscene-background-motion'),
    );
    List<double> transform() =>
        List<double>.of(tester.widget<Transform>(motion).transform.storage);

    expect(tester.widget(blur), isA<ImageFiltered>());
    expect(
      find.descendant(
        of: blur,
        matching: find.byKey(const ValueKey('test-encounter-background')),
      ),
      findsOneWidget,
    );

    final initialTransform = transform();
    await tester.pump(const Duration(milliseconds: 200));
    final firstMovingTransform = transform();
    await tester.pump(const Duration(milliseconds: 200));
    final secondMovingTransform = transform();

    expect(firstMovingTransform, isNot(equals(initialTransform)));
    expect(secondMovingTransform, isNot(equals(firstMovingTransform)));
  });

  testWidgets('reduced motion uses its short static deadline', (tester) async {
    const timing = EncounterCutsceneTiming.standard;
    var completions = 0;

    await tester.pumpWidget(
      _cutsceneHost(
        timing: timing,
        reducedMotion: true,
        onFinished: () => completions++,
      ),
    );
    final motion = find.byKey(
      const ValueKey('encounter-cutscene-background-motion'),
    );
    List<double> transform() =>
        List<double>.of(tester.widget<Transform>(motion).transform.storage);
    final initialTransform = transform();

    expect(timing.reducedMotion, const Duration(milliseconds: 240));
    expect(timing.reducedMotion, lessThan(timing.total));

    await tester.pump(timing.reducedMotion - const Duration(milliseconds: 1));
    expect(completions, 0);
    expect(transform(), equals(initialTransform));

    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
    expect(transform(), equals(initialTransform));
  });

  testWidgets('disposing a cutscene cancels its pending completion', (
    tester,
  ) async {
    const timing = EncounterCutsceneTiming(
      entrance: Duration(milliseconds: 50),
      hold: Duration(milliseconds: 100),
      exit: Duration(milliseconds: 50),
    );
    var completions = 0;

    await tester.pumpWidget(
      _cutsceneHost(timing: timing, onFinished: () => completions++),
    );
    await tester.pump(const Duration(milliseconds: 75));
    expect(completions, 0);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));

    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });
}

Widget _cutsceneHost({
  EncounterCutsceneTiming timing = EncounterCutsceneTiming.standard,
  VoidCallback? onFinished,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: EncounterCutscene(
      background: _testBackground,
      knightArt: _testKnightArt,
      enemyArt: _testEnemyArt,
      enemyName: 'Clockwork Warden',
      timing: timing,
      onFinished: onFinished ?? () {},
    ),
  ),
);

const _testBackground = ColoredBox(
  key: ValueKey('test-encounter-background'),
  color: Color(0xff20385f),
);

const _testKnightArt = ColoredBox(
  key: ValueKey('test-knight-art'),
  color: Color(0xffd5b343),
);

const _testEnemyArt = ColoredBox(
  key: ValueKey('test-enemy-art'),
  color: Color(0xff9d3f57),
);
