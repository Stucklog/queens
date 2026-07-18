import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('board drags place and remove X marks across edges and corners', (
    tester,
  ) async {
    final puzzle = _firstPuzzle();
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    await _pumpBoard(tester, puzzle, board);

    final boardRect = tester.getRect(find.byType(RegaliaBoard));
    await _quickDrag(
      tester,
      _cellCenter(boardRect, puzzle.size, const Cell(0, 0)),
      _cellCenter(boardRect, puzzle.size, Cell(0, puzzle.size - 1)),
    );

    for (var column = 0; column < puzzle.size; column++) {
      expect(
        board.at(Cell(0, column)),
        ManualCellState.cross,
        reason: 'horizontal drag should reach every top-edge cell',
      );
    }
    expect(board.undoStack, hasLength(1));

    for (var row = 0; row < puzzle.size; row++) {
      board.set(
        Cell(row, puzzle.size - 1),
        ManualCellState.cross,
        recordUndo: false,
      );
    }
    board.undoStack.clear();
    await _quickDrag(
      tester,
      _cellCenter(boardRect, puzzle.size, Cell(0, puzzle.size - 1)),
      _cellCenter(
        boardRect,
        puzzle.size,
        Cell(puzzle.size - 1, puzzle.size - 1),
      ),
    );

    for (var row = 0; row < puzzle.size; row++) {
      expect(
        board.at(Cell(row, puzzle.size - 1)),
        ManualCellState.empty,
        reason: 'vertical drag from an X should remove the full edge',
      );
    }
    expect(board.undoStack, hasLength(1));

    board.cells.fillRange(0, board.cells.length, ManualCellState.empty);
    board.undoStack.clear();
    await _quickDrag(
      tester,
      _cellCenter(boardRect, puzzle.size, const Cell(0, 0)),
      _cellCenter(
        boardRect,
        puzzle.size,
        Cell(puzzle.size - 1, puzzle.size - 1),
      ),
    );

    for (var index = 0; index < puzzle.size; index++) {
      expect(
        board.at(Cell(index, index)),
        ManualCellState.cross,
        reason: 'one fast update should interpolate the corner path',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'vertical board drag places and removes Xs without scrolling the page',
    (tester) async {
      final session = await _pumpGame(tester);
      final boardRect = tester.getRect(find.byType(RegaliaBoard));
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('puzzle-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      await _quickDrag(
        tester,
        _cellCenter(boardRect, session.puzzle.size, const Cell(0, 1)),
        _cellCenter(
          boardRect,
          session.puzzle.size,
          Cell(session.puzzle.size - 1, 1),
        ),
      );

      for (var row = 0; row < session.puzzle.size; row++) {
        expect(
          session.controller.boardFor(session.puzzle).at(Cell(row, 1)),
          ManualCellState.cross,
        );
      }
      expect(scrollable.position.pixels, 0);

      await _quickDrag(
        tester,
        _cellCenter(boardRect, session.puzzle.size, const Cell(0, 1)),
        _cellCenter(
          boardRect,
          session.puzzle.size,
          Cell(session.puzzle.size - 1, 1),
        ),
      );
      for (var row = 0; row < session.puzzle.size; row++) {
        expect(
          session.controller.boardFor(session.puzzle).at(Cell(row, 1)),
          ManualCellState.empty,
        );
      }
      expect(scrollable.position.pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dragging outside the board keeps normal page scrolling', (
    tester,
  ) async {
    final session = await _pumpGame(tester);
    final safeRect = tester.getRect(
      find.byKey(const ValueKey('puzzle-scroll-safe-area')),
    );
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('puzzle-scroll-view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.timedDragFrom(
      Offset(8, safeRect.center.dy),
      const Offset(0, -220),
      const Duration(milliseconds: 400),
    );
    await tester.pump();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      session.controller.boardFor(session.puzzle).cells,
      everyElement(ManualCellState.empty),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull-down and recoil stay below the banner safe area', (
    tester,
  ) async {
    await _pumpGame(tester);
    final safeFinder = find.byKey(const ValueKey('puzzle-scroll-safe-area'));
    final scrollFinder = find.byKey(const ValueKey('puzzle-scroll-view'));
    final bannerFinder = find.byKey(
      const ValueKey('puzzle-knight-companion-surface'),
    );
    final safeRect = tester.getRect(safeFinder);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(of: scrollFinder, matching: find.byType(Scrollable))
          .first,
    );

    expect(
      tester.widget<SingleChildScrollView>(scrollFinder).physics,
      isA<ClampingScrollPhysics>(),
    );
    expect(
      safeRect.top,
      greaterThanOrEqualTo(tester.getRect(bannerFinder).bottom),
    );

    final pullDown = await tester.startGesture(
      Offset(8, safeRect.top + safeRect.height / 3),
    );
    await pullDown.moveBy(const Offset(0, 180));
    await tester.pump();
    expect(scrollable.position.pixels, 0);
    expect(
      tester.getRect(find.byType(RegaliaBoard)).top,
      greaterThanOrEqualTo(safeRect.top),
    );
    await pullDown.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(scrollable.position.pixels, 0);

    await tester.timedDragFrom(
      Offset(8, safeRect.center.dy),
      const Offset(0, -180),
      const Duration(milliseconds: 400),
    );
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.timedDragFrom(
      Offset(8, safeRect.center.dy),
      const Offset(0, 500),
      const Duration(milliseconds: 500),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(scrollable.position.pixels, 0);
    expect(
      tester.getRect(find.byType(RegaliaBoard)).top,
      greaterThanOrEqualTo(safeRect.top),
    );
    expect(tester.takeException(), isNull);
  });
}

PuzzleDefinition _firstPuzzle() =>
    PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    ).puzzles.first;

Future<void> _pumpBoard(
  WidgetTester tester,
  PuzzleDefinition puzzle,
  BoardState board,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 360,
            child: RegaliaBoard(
              puzzle: puzzle,
              board: board,
              onCellPressed: board.cycle,
              onCellDragged: (cell, targetState) {
                if (board.at(cell) != ManualCellState.crown) {
                  board.set(cell, targetState);
                }
              },
              onExclusionDragStarted: board.beginBatch,
              onExclusionDragEnded: board.endBatch,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<_GameSession> _pumpGame(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = _TimerlessController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  final puzzle = controller.catalog!.puzzles.first;
  controller.openPuzzle(puzzle);
  await tester.pumpWidget(
    MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
  );
  await tester.pump();
  return _GameSession(controller, puzzle);
}

Offset _cellCenter(Rect board, int boardSize, Cell cell) => Offset(
  board.left + (cell.column + .5) * board.width / boardSize,
  board.top + (cell.row + .5) * board.height / boardSize,
);

Future<void> _quickDrag(WidgetTester tester, Offset start, Offset end) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveTo(end);
  await gesture.up();
  await tester.pump();
}

class _GameSession {
  const _GameSession(this.controller, this.puzzle);

  final AppController controller;
  final PuzzleDefinition puzzle;
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
