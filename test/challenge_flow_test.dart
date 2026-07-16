import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      challengePuzzleFactory: (spec) async => _fixtureForSpec(controller, spec),
    );
    await tester.runAsync(controller.initialize);
    var controllerDisposed = false;
    addTearDown(() {
      if (!controllerDisposed) controller.dispose();
    });
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(journeyChapters.first.storyBeatId);
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
    expect(find.text('Challenge 1'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Next challenge'), findsOneWidget);
    expect(controller.challengeSession?.completedCount, 1);
    expect(controller.frontierPuzzle?.order, 1);

    await tester.tap(find.text('Next challenge'));
    for (
      var frame = 0;
      frame < 20 && find.text('Challenge 2').evaluate().isEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Challenge 2'), findsOneWidget);
    expect(controller.challengeSession?.currentNumber, 2);
    expect(controller.frontierPuzzle?.order, 1);
    expect(controller.records, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(controller.flushPersistence);
    controller.dispose();
    controllerDisposed = true;
  });
}

PuzzleDefinition _fixtureForSpec(
  AppController controller,
  ChallengeGenerationSpec spec,
) {
  final source = controller.catalog!.puzzles.firstWhere(
    (puzzle) => puzzle.tier == spec.tier && puzzle.size == spec.size,
  );
  return PuzzleDefinition(
    id: spec.puzzleId,
    order: spec.number,
    size: source.size,
    tier: source.tier,
    regions: source.regions,
    schemaVersion: source.schemaVersion,
    contentHash: source.contentHash,
    difficultyScore: source.difficultyScore,
    scoringModel: source.scoringModel,
  );
}
