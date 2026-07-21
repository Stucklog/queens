import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/guided_walkthrough_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('welcome flows through story into guided puzzle one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.text('Welcome to Queen’s Regalia'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Four rules to remember'), findsOneWidget);
    await tester.tap(find.text('Continue to story'));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('The Stolen Dawn'), findsOneWidget);
    expect(find.byKey(const ValueKey('story-prologue-back')), findsOneWidget);

    await tester.ensureVisible(find.text('See what happened'));
    await tester.tap(find.text('See what happened'));
    await _pumpFrames(tester);
    await tester.ensureVisible(find.text('Follow the crown'));
    await tester.tap(find.text('Follow the crown'));
    await _pumpFrames(tester);
    await tester.ensureVisible(find.text('Begin the journey'));
    await tester.tap(find.text('Begin the journey'));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Asterfall Vale'), findsWidgets);
    expect(find.text('Enter Asterfall'), findsOneWidget);

    await tester.ensureVisible(find.text('Enter Asterfall'));
    await tester.tap(find.text('Enter Asterfall'));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(GuidedWalkthroughScreen), findsOneWidget);
    expect(find.text('Your first puzzle'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guided-walkthrough-panel')),
      findsOneWidget,
    );
    final puzzle = controller.catalog!.puzzles.first;

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A clean coronation'), findsOneWidget);
    expect(
      controller.recordFor(puzzle.id).status,
      CompletionStatus.cleanSolved,
    );
    expect(controller.originOnboardingPending, isFalse);

    await tester.tap(find.text('Advance'));
    for (
      var frame = 0;
      frame < 16 &&
          (find.byType(GameScreen).evaluate().isNotEmpty ||
              find.byType(GuidedWalkthroughScreen).evaluate().isNotEmpty);
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
    await _pumpFrames(tester);
    final second = controller.catalog!.puzzles[1];
    expect(find.text('Puzzle ${second.order} of 72'), findsOneWidget);

    await tester.runAsync(controller.flushPersistence);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();

    final restored = AppController();
    await tester.runAsync(restored.initialize);
    expect(restored.tutorialComplete, isTrue);
    expect(restored.originOnboardingPending, isFalse);
    expect(restored.recordFor(puzzle.id).status, CompletionStatus.cleanSolved);
    expect(restored.frontierPuzzle?.order, 2);
    expect(restored.hasSeenStoryBeat('opening'), isTrue);
    restored.dispose();
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
