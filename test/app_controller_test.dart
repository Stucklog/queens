import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
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
}
