import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves and settings persist and restore locally', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final first = AppController();
    await first.initialize();
    final puzzle = first.catalog!.puzzles.first;
    first.openPuzzle(puzzle);
    first.cycle(puzzle, const Cell(0, 0));
    first.updateSettings(
      first.settings.copyWith(themeMode: ThemeMode.dark, showTimer: false),
    );
    await first.flushPersistence();
    first.dispose();

    final restored = AppController();
    await restored.initialize();
    expect(
      restored.boardFor(puzzle).at(const Cell(0, 0)),
      ManualCellState.cross,
    );
    expect(restored.settings.themeMode, ThemeMode.dark);
    expect(restored.settings.showTimer, isFalse);
    expect(restored.recordFor(puzzle.id).status, CompletionStatus.inProgress);
    restored.dispose();
  });

  test('hints never mutate marks and assistance survives undo', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final puzzle = controller.catalog!.puzzles.first;
    controller.openPuzzle(puzzle);
    final board = controller.boardFor(puzzle);
    final before = List<ManualCellState>.of(board.cells);

    final deduction = controller.hint(puzzle);
    expect(deduction, isNotNull);
    expect(board.cells, before);
    expect(board.assisted, isTrue);
    expect(board.hintCount, 1);

    controller.cycle(puzzle, const Cell(0, 0));
    controller.undo(puzzle);
    expect(board.cells, before);
    expect(board.assisted, isTrue);
    await controller.flushPersistence();
    controller.dispose();
  });

  test('a fresh replay upgrades assisted solved to clean solved', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final puzzle = controller.catalog!.puzzles.first;
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    controller.openPuzzle(puzzle);
    controller.checkProgress(puzzle);
    for (final cell in solution) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(
      controller.recordFor(puzzle.id).status,
      CompletionStatus.assistedSolved,
    );

    controller.openPuzzle(puzzle);
    expect(
      controller.boardFor(puzzle).cells,
      everyElement(ManualCellState.empty),
    );
    controller.setCell(puzzle, solution.first, ManualCellState.crown);
    expect(controller.statusFor(puzzle), CompletionStatus.inProgress);
    for (final cell in solution.skip(1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(
      controller.recordFor(puzzle.id).status,
      CompletionStatus.cleanSolved,
    );
    await controller.flushPersistence();
    controller.dispose();
  });

  test('active timer pauses when stopped', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final puzzle = controller.catalog!.puzzles.first;
    controller.openPuzzle(puzzle);
    controller.startTimer(puzzle.id);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    controller.stopTimer();
    final stoppedAt = controller.boardFor(puzzle).elapsedSeconds;
    expect(stoppedAt, 2);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(controller.boardFor(puzzle).elapsedSeconds, stoppedAt);
    await controller.flushPersistence();
    controller.dispose();
  });

  test('reset starts a clean attempt and clears attempt-only data', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final puzzle = controller.catalog!.puzzles.first;
    controller.openPuzzle(puzzle);
    controller.cycle(puzzle, const Cell(0, 0));
    controller.checkProgress(puzzle);
    final board = controller.boardFor(puzzle)..elapsedSeconds = 12;

    controller.reset(puzzle);

    expect(board.cells, everyElement(ManualCellState.empty));
    expect(board.elapsedSeconds, 0);
    expect(board.assisted, isFalse);
    expect(board.checkCount, 0);
    expect(controller.recordFor(puzzle.id).attemptCount, 2);
    await controller.flushPersistence();
    controller.dispose();
  });

  test('corrupt and stale saved state is ignored during startup', () async {
    SharedPreferences.setMockInitialValues({
      'regalia.tutorialComplete': true,
      'regalia.lastPuzzle': 'removed-puzzle',
      'regalia.boards': '{not json',
      'regalia.records': '{also not json',
    });
    final controller = AppController();
    await controller.initialize();

    expect(controller.lastPuzzleId, isNull);
    expect(controller.boards, isEmpty);
    expect(controller.records, isEmpty);
    expect(controller.recommendedPuzzle(), controller.catalog!.puzzles.first);
    controller.dispose();
  });

  test('a changed catalog clears puzzle-specific local progress', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final original = AppController();
    await original.initialize();
    final puzzle = original.catalog!.puzzles.first;
    original.openPuzzle(puzzle);
    original.cycle(puzzle, const Cell(0, 0));
    await original.flushPersistence();
    original.dispose();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('regalia.catalogFingerprint', 'old-catalog');

    final restored = AppController();
    await restored.initialize();
    expect(restored.boards, isEmpty);
    expect(restored.records, isEmpty);
    expect(restored.lastPuzzleId, isNull);
    expect(restored.tutorialComplete, isTrue);
    restored.dispose();
  });

  test(
    'only the first frontier can open and locked attempts are inert',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
      });
      final controller = AppController();
      await controller.initialize();
      final first = controller.catalog!.puzzles.first;
      final second = controller.catalog!.puzzles[1];

      expect(controller.frontierPuzzle, first);
      expect(controller.canOpenPuzzle(first), isTrue);
      expect(controller.canOpenPuzzle(second), isFalse);
      expect(controller.openPuzzle(second), isFalse);
      expect(controller.boards, isEmpty);
      expect(controller.records, isEmpty);
      expect(controller.lastPuzzleId, isNull);

      expect(controller.openPuzzle(first), isTrue);
      expect(controller.boards.keys, contains(first.id));
      controller.dispose();
    },
  );

  test('clean and assisted frontier solves both advance', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final solver = const ExactSolver();
    final first = controller.catalog!.puzzles.first;
    controller.openPuzzle(first);
    final firstSolution = solver.solve(first, limit: 1).solutions.single;
    PuzzleCompletionOutcome? cleanOutcome;
    for (final cell in firstSolution) {
      cleanOutcome = controller.setCell(first, cell, ManualCellState.crown);
    }
    expect(cleanOutcome?.advancedJourney, isTrue);
    expect(cleanOutcome?.nextPuzzle?.order, 2);
    expect(controller.frontierPuzzle?.order, 2);

    final second = controller.frontierPuzzle!;
    controller.openPuzzle(second);
    controller.checkProgress(second);
    final secondSolution = solver.solve(second, limit: 1).solutions.single;
    PuzzleCompletionOutcome? assistedOutcome;
    for (final cell in secondSolution) {
      assistedOutcome = controller.setCell(second, cell, ManualCellState.crown);
    }
    expect(assistedOutcome?.advancedJourney, isTrue);
    expect(
      controller.recordFor(second.id).status,
      CompletionStatus.assistedSolved,
    );
    expect(controller.frontierPuzzle?.order, 3);
    controller.dispose();
  });

  test('replaying an older puzzle cannot move the frontier', () async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = AppController();
    await controller.initialize();
    final puzzle = controller.catalog!.puzzles.first;
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    controller.openPuzzle(puzzle);
    for (final cell in solution) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(controller.frontierPuzzle?.order, 2);

    controller.openPuzzle(puzzle);
    PuzzleCompletionOutcome? replayOutcome;
    for (final cell in solution) {
      replayOutcome = controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(replayOutcome?.advancedJourney, isFalse);
    expect(replayOutcome?.nextPuzzle, isNull);
    expect(controller.frontierPuzzle?.order, 2);
    controller.dispose();
  });

  test(
    'chapter boundaries and the final completion are derived in order',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
      });
      final controller = AppController();
      await controller.initialize();
      final puzzles = controller.catalog!.puzzles;
      for (final puzzle in puzzles.take(19)) {
        controller.records[puzzle.id] = const CompletionRecord(
          status: CompletionStatus.cleanSolved,
        );
      }
      final twentieth = puzzles[19];
      controller.openPuzzle(twentieth);
      PuzzleCompletionOutcome? boundaryOutcome;
      for (final cell
          in const ExactSolver().solve(twentieth, limit: 1).solutions.single) {
        boundaryOutcome = controller.setCell(
          twentieth,
          cell,
          ManualCellState.crown,
        );
      }
      expect(boundaryOutcome?.enteredChapter?.title, 'Whisperwood');
      expect(controller.frontierPuzzle?.order, 21);

      for (final puzzle in puzzles.take(119)) {
        controller.records[puzzle.id] = CompletionRecord(
          status:
              puzzle.order == 7
                  ? CompletionStatus.assistedSolved
                  : CompletionStatus.cleanSolved,
        );
      }
      final finalPuzzle = puzzles.last;
      controller.openPuzzle(finalPuzzle);
      PuzzleCompletionOutcome? finalOutcome;
      for (final cell
          in const ExactSolver()
              .solve(finalPuzzle, limit: 1)
              .solutions
              .single) {
        finalOutcome = controller.setCell(
          finalPuzzle,
          cell,
          ManualCellState.crown,
        );
      }
      expect(finalOutcome?.isJourneyComplete, isTrue);
      expect(controller.isJourneyComplete, isTrue);
      expect(controller.recommendedPuzzle().order, 7);
      expect(puzzles.every(controller.canOpenPuzzle), isTrue);
      controller.dispose();
    },
  );

  test(
    'journey migration resets progress once but preserves preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = AppController();
      await first.initialize();
      await first.finishTutorial();
      first.updateSettings(
        first.settings.copyWith(themeMode: ThemeMode.dark, reducedMotion: true),
      );
      await first.markStoryBeatSeen('opening');
      final puzzle = first.catalog!.puzzles.first;
      first.openPuzzle(puzzle);
      first.cycle(puzzle, const Cell(0, 0));
      await first.flushPersistence();
      first.dispose();

      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt('regalia.journeySchemaVersion', 0);

      final migrated = AppController();
      await migrated.initialize();
      expect(migrated.boards, isEmpty);
      expect(migrated.records, isEmpty);
      expect(migrated.lastPuzzleId, isNull);
      expect(migrated.seenStoryBeatIds, isEmpty);
      expect(migrated.tutorialComplete, isTrue);
      expect(migrated.settings.themeMode, ThemeMode.dark);
      expect(migrated.settings.reducedMotion, isTrue);
      expect(preferences.getInt('regalia.journeySchemaVersion'), 1);
      migrated.dispose();
    },
  );
}
