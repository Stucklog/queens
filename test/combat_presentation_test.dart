import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/boss_finisher_cutscene.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('knight moves have one readable enemy response', () {
    expect(
      KnightAnimation.values.map((animation) => animation.name),
      isNot(contains('dance')),
    );
    expect(enemyReactionFor(KnightAnimation.bounce), EnemyReaction.idle);
    expect(enemyReactionFor(KnightAnimation.walk), EnemyReaction.idle);
    expect(enemyReactionFor(KnightAnimation.attack), EnemyReaction.staggered);
    expect(enemyReactionFor(KnightAnimation.defend), EnemyReaction.striking);
    expect(enemyReactionFor(KnightAnimation.damage), EnemyReaction.pressing);
    expect(enemyReactionFor(KnightAnimation.surprised), EnemyReaction.exposed);
    expect(enemyReactionFor(KnightAnimation.special), EnemyReaction.defeated);
    for (final level in Iterable<int>.generate(8, (index) => index + 1)) {
      expect(
        enemyReactionFor(finisherForSpectacle(level)),
        EnemyReaction.defeated,
      );
    }
  });

  test(
    'chapter finishers escalate and reserve Regalia Nova for the finale',
    () {
      final finishers = [
        for (var level = 1; level <= 8; level++) finisherForSpectacle(level),
      ];
      expect(finishers.toSet(), hasLength(8));
      expect(finishers.last, KnightAnimation.regaliaNova);
      for (var index = 1; index < finishers.length; index++) {
        expect(
          finishers[index].presentationDuration,
          greaterThan(finishers[index - 1].presentationDuration),
        );
      }
    },
  );

  testWidgets(
    'puzzle stage pins the scaled knight and places the enemy beside her',
    (tester) async {
      tester.view.physicalSize = const Size(390, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpBar(CombatEncounter? encounter) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 390,
                    height: CombatPresentationBar.preferredHeight,
                    child: CombatPresentationBar(
                      animation: KnightAnimation.attack,
                      restartToken: 1,
                      knightLine: 'A crown claims its ground.',
                      encounter: encounter,
                      onKnightCompleted: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpBar(null);
      final soloStageRect = tester.getRect(
        find.byKey(const ValueKey('puzzle-combatant-stage')),
      );
      final soloKnightRect = tester.getRect(
        find.byKey(const ValueKey('puzzle-knight-sprite')),
      );
      final soloKnightOffset = soloKnightRect.topLeft - soloStageRect.topLeft;
      expect(soloKnightRect.size, const Size(90, 79));
      expect(soloStageRect.size, const Size(90, 114));

      await pumpBar(_layoutTestEncounter);
      final combatStageRect = tester.getRect(
        find.byKey(const ValueKey('puzzle-combatant-stage')),
      );
      final combatKnightRect = tester.getRect(
        find.byKey(const ValueKey('puzzle-knight-sprite')),
      );
      final enemyRect = tester.getRect(
        find.byKey(const ValueKey('puzzle-enemy-sprite')),
      );
      expect(combatStageRect.topLeft, soloStageRect.topLeft);
      expect(combatKnightRect.topLeft, soloKnightRect.topLeft);
      expect(
        combatKnightRect.topLeft - combatStageRect.topLeft,
        soloKnightOffset,
      );
      expect(combatKnightRect.size, const Size(90, 79));
      expect(enemyRect.size, const Size(111, 114));
      expect(combatStageRect.size, const Size(177, 114));
      expect(enemyRect.left, combatKnightRect.right - 24);
      expect(enemyRect.bottom, combatKnightRect.bottom);
      expect(enemyRect.bottom, combatStageRect.bottom);
    },
  );

  testWidgets('in-chapter encounters react and cannot be dismissed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.unlockEntireMap(ContentIds.originArc);
    final arc = controller.originArc!;
    final encounter = arc.chapters.first.encounters.first;
    final puzzle = arc.catalog.byId(encounter.puzzleId);
    expect(controller.openPuzzle(puzzle), isTrue);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('puzzle-enemy-sprite')), findsOneWidget);
    expect(find.text('ENCOUNTER'), findsOneWidget);
    expect(find.textContaining('OPTIONAL'), findsNothing);
    expect(find.textContaining('FLAIR'), findsNothing);
    expect(find.text(encounter.name), findsAtLeastNWidgets(1));
    expect(find.text('WATCHING'), findsOneWidget);
    expect(find.byKey(const ValueKey('skip-optional-encounter')), findsNothing);

    final cell = find.byKey(const ValueKey('cell-0-0'));
    await tester.tap(cell);
    await tester.pump();
    expect(find.text('STRIKES'), findsOneWidget);
    await tester.tap(cell);
    await tester.pump();
    expect(find.text('STAGGERED'), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-enemy-sprite')), findsOneWidget);
  });

  testWidgets(
    'in-chapter encounters end with the reusable Crown Slash finisher',
    (tester) async {
      SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
      final controller = _TimerlessController();
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);
      await controller.unlockEntireMap(ContentIds.originArc);
      final arc = controller.originArc!;
      final encounter = arc.chapters.first.encounters.first;
      final puzzle = arc.catalog.byId(encounter.puzzleId);
      final solution =
          const ExactSolver().solve(puzzle, limit: 1).solutions.single;
      for (final cell in solution.take(solution.length - 1)) {
        controller.setCell(puzzle, cell, ManualCellState.crown);
      }
      expect(controller.openPuzzle(puzzle), isTrue);

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
      );
      await tester.pump();
      final finalCell = find.byKey(
        ValueKey('cell-${solution.last.row}-${solution.last.column}'),
      );
      await tester.ensureVisible(finalCell);
      await tester.tap(finalCell);
      await tester.pump();
      await tester.tap(finalCell);
      await tester.pump();

      expect(
        tester
            .widget<PixelKnightSprite>(
              find.byKey(const ValueKey('puzzle-knight-sprite')),
            )
            .animation,
        KnightAnimation.crownSlash,
      );
      expect(
        tester
            .widget<PixelEnemySprite>(
              find.byKey(const ValueKey('puzzle-enemy-sprite')),
            )
            .stimulus,
        KnightAnimation.crownSlash,
      );
      expect(find.text('DEFEATED'), findsOneWidget);
    },
  );

  testWidgets('final boss falls before completion and owns strongest finish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.unlockEntireMap(ContentIds.originArc);
    final arc = controller.originArc!;
    final boss = arc.chapters.last.boss;
    final puzzle = arc.catalog.byId(boss.puzzleId);
    expect(boss.spectacleLevel, 8);
    expect(
      boss.spectacleLevel,
      greaterThan(
        arc.chapters
            .take(arc.chapters.length - 1)
            .map((chapter) => chapter.boss.spectacleLevel)
            .reduce((left, right) => left > right ? left : right),
      ),
    );
    expect(controller.openPuzzle(puzzle), isTrue);
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();
    final finalCell = find.byKey(
      ValueKey('cell-${solution.last.row}-${solution.last.column}'),
    );
    await tester.ensureVisible(finalCell);
    await tester.tap(finalCell);
    await tester.pump();
    await tester.tap(finalCell);
    await tester.pump();

    final presentation = BossFinisherPresentation.forSpectacle(
      boss.spectacleLevel,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.regaliaNova,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .stimulus,
      KnightAnimation.bounce,
    );
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-final-move')),
      findsOneWidget,
    );
    expect(find.text('K.O.'), findsNothing);
    expect(
      find.byKey(const ValueKey('boss-finisher-special-effects')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);

    await tester.pump(
      presentation.timing.finalMove + presentation.timing.panToBoss,
    );
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-boss-defeat')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .stimulus,
      KnightAnimation.regaliaNova,
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);

    await tester.pump(presentation.timing.bossDefeat);
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-pan-to-knight')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .frame,
      3,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.regaliaNova,
    );

    await tester.pump(presentation.timing.panToKnight);
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-victory')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.special,
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);

    await tester.pump(
      presentation.timing.victory +
          presentation.timing.exit -
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('completion-knight')), findsOneWidget);
  });
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}

const _layoutTestEncounter = CombatEncounter(
  id: 'regalia:enemy/layout-test',
  name: 'Layout Test',
  puzzleId: 'regalia:puzzle/layout-test',
  spriteFamily: EnemySpriteFamily.clockwork,
  spriteAsset: 'assets/art/combat/opponents/gear-goblin.png',
  spectacleLevel: 1,
  isBoss: false,
);
