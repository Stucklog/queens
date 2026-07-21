import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/challenge_generator.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/challenge_screen.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/challenge_fixture.dart';

void main() {
  testWidgets('challenge mode generates, plays, and continues in isolation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'regalia.tutorialComplete': true,
      'regalia.journeySchemaVersion': 1,
    });
    late AppController controller;
    controller = AppController(
      challengePuzzleFactory:
          (spec, _) async => challengeFixtureForSpec(controller, spec),
    );
    await tester.runAsync(controller.initialize);
    var controllerDisposed = false;
    addTearDown(() {
      if (!controllerDisposed) controller.dispose();
    });
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(
      controller.originArc!.chapters.first.storyBeatId,
    );
    await tester.pumpWidget(
      MaterialApp(home: JourneyScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final challengeEntry = find.byKey(const ValueKey('open-challenge-mode'));
    await tester.ensureVisible(challengeEntry);
    await tester.tap(challengeEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('challenge-mode-easy')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('challenge-mode-easy')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Just Puzzle! 1'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);

    final first = controller.challengeSession!.currentPuzzle;
    final solution =
        const ExactSolver().solve(first, limit: 1).solutions.single;
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(first, cell, ManualCellState.crown);
    }
    final last = solution.last;
    final lastCell = find.byKey(ValueKey('cell-${last.row}-${last.column}'));
    await tester.ensureVisible(lastCell);
    await tester.tap(lastCell);
    await tester.pump();
    await tester.tap(lastCell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Next puzzle'), findsOneWidget);
    expect(controller.challengeSession?.completedCount, 1);
    expect(controller.frontierPuzzle?.order, 1);

    await tester.tap(find.text('Next puzzle'));
    for (
      var frame = 0;
      frame < 40 &&
          (find.text('Just Puzzle! 2').evaluate().isEmpty ||
              find.byType(GameScreen).evaluate().length != 1);
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Just Puzzle! 2'), findsOneWidget);
    expect(controller.challengeSession?.currentNumber, 2);
    expect(controller.frontierPuzzle?.order, 1);
    expect(controller.records, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(controller.flushPersistence);
    controller.dispose();
    controllerDisposed = true;
  });

  testWidgets(
    'extreme mode plays, resets, hints, and completes a 12x12 board',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      late AppController controller;
      controller = AppController(
        challengePuzzleFactory:
            (spec, _) async => challengeFixtureForSpec(controller, spec),
      );
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ChallengeScreen(controller: controller)),
      );
      await tester.pump();

      final extreme = find.byKey(const ValueKey('challenge-mode-extreme'));
      await tester.scrollUntilVisible(
        extreme,
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(extreme);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));

      expect(find.byType(GameScreen), findsOneWidget);
      expect(controller.challengeSession?.mode, ChallengeMode.extreme);
      final puzzle = controller.challengeSession!.currentPuzzle;
      final board = controller.boardFor(puzzle);
      expect(puzzle.tier, DifficultyTier.expert);
      expect(puzzle.size, 12);
      expect(board.cells, hasLength(144));
      expect(find.text('Extreme · 12 × 12'), findsOneWidget);
      expect(find.text('Expert · 12 × 12'), findsNothing);

      final edgeCell = find.byKey(const ValueKey('cell-11-11'));
      expect(edgeCell, findsOneWidget);
      await tester.tap(edgeCell);
      await tester.pump();
      expect(board.at(const Cell(11, 11)), ManualCellState.cross);

      final reset = find.byTooltip('Reset');
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pump();
      expect(find.text('Reset this attempt?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(board.cells, everyElement(ManualCellState.empty));
      expect(board.elapsedSeconds, 0);

      final hint = find.text('Hint');
      await tester.ensureVisible(hint);
      await tester.tap(hint);
      await tester.pump();
      expect(board.hintCount, 1);
      expect(board.assisted, isTrue);
      expect(
        find.byKey(const ValueKey('puzzle-feedback-message')),
        findsOneWidget,
      );

      final solution =
          const ExactSolver().solve(puzzle, limit: 1).solutions.single;
      for (final cell in solution.take(solution.length - 1)) {
        controller.setCell(puzzle, cell, ManualCellState.crown);
      }
      final last = solution.last;
      final lastCell = find.byKey(ValueKey('cell-${last.row}-${last.column}'));
      await tester.ensureVisible(lastCell);
      await tester.tap(lastCell);
      await tester.pump();
      await tester.tap(lastCell);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(controller.challengeSession?.currentCompleted, isTrue);
      expect(controller.challengeSession?.completedCount, 1);
      expect(controller.challengeSession?.assistedCount, 1);
      expect(find.text('Next puzzle'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(controller.flushPersistence);
    },
  );

  testWidgets('a slot-two generation never disables the ready next board', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'regalia.tutorialComplete': true,
      'regalia.journeySchemaVersion': 1,
    });
    final thirdGeneration = Completer<ChallengePuzzleResult>();
    late ChallengeGenerationSpec thirdSpec;
    late AppController controller;
    controller = AppController(
      challengePuzzleFactory: (spec, _) {
        if (spec.number < 3) {
          return Future.value(challengeFixtureForSpec(controller, spec));
        }
        thirdSpec = spec;
        return thirdGeneration.future;
      },
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    expect(
      await controller.startChallenge(ChallengeMode.easy, seed: 202),
      isTrue,
    );
    for (var frame = 0; frame < 50; frame++) {
      if (controller.challengeSession?.preparedPuzzles.length == 1 &&
          controller.isPreparingChallenge) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(controller.challengeSession?.preparedPuzzles.length, 1);
    expect(controller.isPreparingChallenge, isTrue);

    final current = controller.challengeSession!.currentPuzzle;
    await tester.runAsync(() async {
      for (final cell
          in const ExactSolver().solve(current, limit: 1).solutions.single) {
        controller.setCell(current, cell, ManualCellState.crown);
      }
      await controller.flushPersistence();
    });
    expect(controller.challengeSession?.currentCompleted, isTrue);

    await tester.pumpWidget(
      MaterialApp(home: ChallengeScreen(controller: controller)),
    );
    await tester.pump();

    final play = tester.widget<FilledButton>(
      find.byKey(const ValueKey('play-challenge')),
    );
    expect(play.onPressed, isNotNull);
    expect(
      find.text('The next board is ready while another is prepared.'),
      findsOneWidget,
    );

    thirdGeneration.complete(challengeFixtureForSpec(controller, thirdSpec));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
