import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
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

    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('puzzle-knight-sprite')),
          )
          .animation,
      KnightAnimation.regaliaNova,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('puzzle-enemy-sprite')),
          )
          .stimulus,
      KnightAnimation.regaliaNova,
    );
    expect(find.text('DEFEATED'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('combat-special-effects')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);

    await tester.pump(
      KnightAnimation.regaliaNova.presentationDuration -
          const Duration(milliseconds: 1),
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(
      KnightAnimation.regaliaNova.postRoll + const Duration(milliseconds: 20),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('completion-knight')), findsOneWidget);
  });
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
