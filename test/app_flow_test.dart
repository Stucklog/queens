import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tutorial to opening to puzzle one and map movement', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.text("Welcome to Queen's Regalia"), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('The Crown Takes Flight'), findsOneWidget);

    await tester.tap(find.text('Begin journey'));
    await tester.pumpAndSettle();
    expect(find.text('Clovermead'), findsWidgets);
    expect(find.text('Follow the road'), findsOneWidget);

    await tester.tap(find.text('Follow the road'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('puzzle-node-120')), findsOneWidget);

    final firstNode = find.byKey(const ValueKey('puzzle-node-1'));
    await tester.ensureVisible(firstNode);
    await tester.tap(firstNode);
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Advance'));
    for (
      var frame = 0;
      frame < 16 && find.byType(GameScreen).evaluate().isNotEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GameScreen), findsNothing);
    expect(find.textContaining('tap to skip'), findsOneWidget);
    await tester.tap(find.textContaining('tap to skip'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 450));
    expect(controller.frontierPuzzle?.order, 2);
    expect(find.byKey(const ValueKey('puzzle-node-2')), findsOneWidget);

    expect(find.text('Next puzzle'), findsOneWidget);
    final secondNode = find.byKey(const ValueKey('puzzle-node-2'));
    await tester.ensureVisible(secondNode);
    await tester.tap(secondNode);
    await tester.pumpAndSettle();
    final second = controller.catalog!.puzzles[1];
    expect(find.text('Puzzle ${second.order} of 120'), findsOneWidget);

    await tester.runAsync(controller.flushPersistence);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();

    final restored = AppController();
    await tester.runAsync(restored.initialize);
    expect(restored.tutorialComplete, isTrue);
    expect(restored.recordFor(puzzle.id).status, CompletionStatus.cleanSolved);
    expect(restored.frontierPuzzle?.order, 2);
    expect(restored.hasSeenStoryBeat('opening'), isTrue);
    restored.dispose();
  });
}
