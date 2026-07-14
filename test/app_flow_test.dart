import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tutorial to clean solve to persistence to replay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.text('Welcome to Regalia'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your royal journey'), findsOneWidget);

    await tester.tap(find.text('Play next'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final puzzle = controller.catalog!.puzzles.first;
    expect(
      find.text('${puzzle.tier.label} · ${puzzle.size} × ${puzzle.size}'),
      findsOneWidget,
    );

    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    await tester.pump();
    final last = solution.last;
    final lastCell = find.byKey(ValueKey('cell-${last.row}-${last.column}'));
    expect(lastCell, findsOneWidget);
    await tester.ensureVisible(lastCell);
    await tester.pump();
    await tester.tap(lastCell);
    await tester.pump();
    await tester.tap(lastCell);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('A clean coronation'), findsOneWidget);
    expect(
      controller.recordFor(puzzle.id).status,
      CompletionStatus.cleanSolved,
    );

    await tester.tap(find.text('Replay'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.boardFor(puzzle).cells,
      everyElement(ManualCellState.empty),
    );
    await tester.runAsync(controller.flushPersistence);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();

    final restored = AppController();
    await tester.runAsync(restored.initialize);
    expect(restored.tutorialComplete, isTrue);
    expect(restored.recordFor(puzzle.id).status, CompletionStatus.cleanSolved);
    expect(
      restored.boardFor(puzzle).cells,
      everyElement(ManualCellState.empty),
    );
    restored.dispose();
  });
}
