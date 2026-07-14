import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('board renders accessibly and tap cycles a cell', (tester) async {
    final catalog = PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    );
    final puzzle = catalog.puzzles.first;
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 500,
              child: RegaliaBoard(
                puzzle: puzzle,
                board: board,
                onCellPressed: board.cycle,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InkWell), findsNWidgets(puzzle.size * puzzle.size));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cell-0-0'))),
      matchesSemantics(
        label:
            'Row 1, column A, region ${puzzle.regionAt(const Cell(0, 0)) + 1}',
        value: 'empty',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('cell-0-0')));
    await tester.pump();
    expect(board.at(const Cell(0, 0)), ManualCellState.cross);
  });

  testWidgets('keyboard navigation can mark, crown, and clear cells', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final puzzle = controller.catalog!.puzzles.first;
    controller.openPuzzle(puzzle);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    expect(
      controller.boardFor(puzzle).at(const Cell(0, 1)),
      ManualCellState.cross,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    expect(
      controller.boardFor(puzzle).at(const Cell(0, 1)),
      ManualCellState.crown,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    expect(
      controller.boardFor(puzzle).at(const Cell(0, 1)),
      ManualCellState.empty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
