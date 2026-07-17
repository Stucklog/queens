import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('puzzle knight reacts to marks, conflicts, help, and victory', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final puzzle = controller.catalog!.puzzles.first;
    expect(controller.openPuzzle(puzzle), isTrue);
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    final validCrown = solution.first;
    final conflictingCrown = Cell(
      validCrown.row,
      (validCrown.column + 1) % puzzle.size,
    );

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();

    final companion = find.byKey(const ValueKey('puzzle-knight-sprite'));
    KnightAnimation currentAnimation() =>
        tester.widget<PixelKnightSprite>(companion).animation;
    expect(currentAnimation(), KnightAnimation.bounce);

    await _tapCell(tester, validCrown);
    expect(currentAnimation(), KnightAnimation.defend);
    await _tapCell(tester, validCrown);
    expect(currentAnimation(), KnightAnimation.attack);

    await _tapCell(tester, conflictingCrown);
    expect(currentAnimation(), KnightAnimation.defend);
    await _tapCell(tester, conflictingCrown);
    expect(currentAnimation(), KnightAnimation.damage);
    await _tapCell(tester, conflictingCrown);
    expect(currentAnimation(), KnightAnimation.surprised);

    await tester.ensureVisible(find.text('Check progress'));
    await tester.tap(find.text('Check progress'));
    await tester.pump();
    expect(currentAnimation(), KnightAnimation.dance);

    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(currentAnimation(), KnightAnimation.surprised);

    for (final cell in solution.skip(1).take(solution.length - 2)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    await tester.pump();
    final finalCrown = solution.last;
    await _tapCell(tester, finalCrown);
    await _tapCell(tester, finalCrown);
    expect(currentAnimation(), KnightAnimation.special);
    expect(find.byKey(const ValueKey('completion-knight')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion holds reactions and clears stale help on undo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final puzzle = controller.catalog!.puzzles.first;
    expect(controller.openPuzzle(puzzle), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: GameScreen(controller: controller, puzzle: puzzle),
      ),
    );
    await tester.pump();
    final companion = find.byKey(const ValueKey('puzzle-knight-sprite'));

    await _tapCell(tester, const Cell(0, 0));
    final firstDefend = tester.widget<PixelKnightSprite>(companion);
    expect(firstDefend.animation, KnightAnimation.defend);
    await _tapCell(tester, const Cell(0, 1));
    final repeatedDefend = tester.widget<PixelKnightSprite>(companion);
    expect(repeatedDefend.animation, KnightAnimation.defend);
    expect(repeatedDefend.restartToken, greaterThan(firstDefend.restartToken));
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<PixelKnightSprite>(companion).animation,
      KnightAnimation.defend,
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('puzzle-knight-companion')),
      ),
      matchesSemantics(
        label: 'Knight companion. That square is guarded.',
        isLiveRegion: true,
      ),
    );

    await tester.ensureVisible(find.text('Hint'));
    await tester.tap(find.text('Hint'));
    await tester.pump();
    expect(
      tester.widget<RegaliaBoard>(find.byType(RegaliaBoard)).cues,
      isNotEmpty,
    );
    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    final afterUndo = tester.widget<RegaliaBoard>(find.byType(RegaliaBoard));
    expect(afterUndo.cues, isEmpty);
    expect(afterUndo.conflicts, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('replaying a solved board resets the victory reaction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final puzzle = controller.catalog!.puzzles.first;
    expect(controller.openPuzzle(puzzle), isTrue);
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    for (final cell in solution) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    controller.reset(puzzle);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    await tester.pump();
    await _tapCell(tester, solution.last);
    await _tapCell(tester, solution.last);
    expect(find.text('Replay'), findsOneWidget);
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('puzzle-knight-sprite')),
          )
          .animation,
      KnightAnimation.special,
    );

    await tester.tap(find.text('Replay'));
    await tester.pump();
    expect(find.text('Replay'), findsNothing);
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('puzzle-knight-sprite')),
          )
          .animation,
      KnightAnimation.bounce,
    );
    expect(
      controller.boardFor(puzzle).cells,
      everyElement(ManualCellState.empty),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _tapCell(WidgetTester tester, Cell cell) async {
  final finder = find.byKey(ValueKey('cell-${cell.row}-${cell.column}'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
