import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
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

  testWidgets('dragging across the board excludes every crossed cell', (
    tester,
  ) async {
    final catalog = PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    );
    final puzzle = catalog.puzzles.first;
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size)
      ..set(const Cell(0, 2), ManualCellState.crown);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 480,
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
    );

    final topLeft = tester.getTopLeft(find.byType(RegaliaBoard));
    final cellSize = 480 / puzzle.size;
    await tester.dragFrom(
      topLeft + Offset(cellSize / 2, cellSize / 2),
      Offset(cellSize * 3, 0),
    );
    await tester.pump();

    expect(board.at(const Cell(0, 0)), ManualCellState.cross);
    expect(board.at(const Cell(0, 1)), ManualCellState.cross);
    expect(board.at(const Cell(0, 2)), ManualCellState.crown);
    expect(board.at(const Cell(0, 3)), ManualCellState.cross);

    expect(board.undo(), isTrue);
    expect(board.at(const Cell(0, 0)), ManualCellState.empty);
    expect(board.at(const Cell(0, 1)), ManualCellState.empty);
    expect(board.at(const Cell(0, 2)), ManualCellState.crown);
    expect(board.at(const Cell(0, 3)), ManualCellState.empty);
  });

  testWidgets('full route exposes clean, assisted, current, and locked nodes', (
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
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(journeyChapters.first.storyBeatId);
    final puzzles = controller.catalog!.puzzles;
    controller.records[puzzles[0].id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
    controller.records[puzzles[1].id] = const CompletionRecord(
      status: CompletionStatus.assistedSolved,
    );

    await tester.pumpWidget(
      MaterialApp(home: JourneyScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('QUEEN’S REGALIA'), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-node-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-node-120')), findsOneWidget);
    Finder semanticsWithLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );
    expect(semanticsWithLabel('Puzzle 1, clean.'), findsOneWidget);
    expect(semanticsWithLabel('Puzzle 2, assisted.'), findsOneWidget);
    expect(semanticsWithLabel('Puzzle 3, current.'), findsOneWidget);
    expect(
      semanticsWithLabel(
        'Puzzle 4 with Vale Thornling encounter, locked. '
        'Complete puzzle 3 first.',
      ),
      findsOneWidget,
    );
    expect(semanticsWithLabel('Crown bearer at puzzle 3'), findsOneWidget);

    final beforeBoards = Map<String, BoardState>.of(controller.boards);
    expect(controller.openPuzzle(puzzles[3]), isFalse);
    expect(controller.boards, beforeBoards);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support action opens the approved Buy Me a Coffee page', (
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
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(journeyChapters.first.storyBeatId);
    Uri? launchedUri;

    await tester.pumpWidget(
      MaterialApp(
        home: JourneyScreen(
          controller: controller,
          externalUrlLauncher: (uri) async {
            launchedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Support Queen’s Regalia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('buy-me-a-coffee')));
    await tester.pump();

    expect(launchedUri, Uri.parse('https://buymeacoffee.com/philosophyforge'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('prologue tile replays every page without changing progress', (
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
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(journeyChapters.first.storyBeatId);
    final firstPuzzle = controller.catalog!.puzzles.first;
    controller.records[firstPuzzle.id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
    final recordsBefore = Map<String, CompletionRecord>.of(controller.records);
    final unlocksBefore = Set<String>.of(controller.unlockedContentIds);
    final seenBefore = Set<String>.of(controller.seenStoryBeatIds);
    final storyWriteAttemptsBefore = controller.storyWriteAttempts;

    await tester.pumpWidget(
      MaterialApp(home: JourneyScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final introTile = find.byKey(const ValueKey('intro-landmark'));
    await tester.ensureVisible(introTile);
    await tester.tap(introTile);
    await tester.pumpAndSettle();

    expect(find.byType(StorySceneScreen), findsOneWidget);
    expect(find.byType(PixelStoryKnightSprite), findsOneWidget);
    expect(find.text('PROLOGUE · 1 of 3'), findsOneWidget);
    expect(find.text('The Stolen Dawn'), findsOneWidget);

    await tester.ensureVisible(find.text('See what happened'));
    await tester.tap(find.text('See what happened'));
    await tester.pumpAndSettle();
    expect(find.text('PROLOGUE · 2 of 3'), findsOneWidget);
    expect(find.text('The Falling Crown'), findsOneWidget);

    await tester.ensureVisible(find.text('Follow the crown'));
    await tester.tap(find.text('Follow the crown'));
    await tester.pumpAndSettle();
    expect(find.text('PROLOGUE · 3 of 3'), findsOneWidget);
    expect(find.text('The Knight’s Choice'), findsOneWidget);

    await tester.ensureVisible(find.text('Begin the journey'));
    await tester.tap(find.text('Begin the journey'));
    await tester.pumpAndSettle();

    expect(find.byType(JourneyScreen), findsOneWidget);
    expect(controller.records, recordsBefore);
    expect(controller.unlockedContentIds, unlocksBefore);
    expect(controller.seenStoryBeatIds, seenBefore);
    expect(controller.storyWriteAttempts, storyWriteAttemptsBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape host retains every panorama landmark', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
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
    await controller.markStoryBeatSeen(StoryBeatIds.opening);
    await controller.markStoryBeatSeen(journeyChapters.first.storyBeatId);

    await tester.pumpWidget(
      MaterialApp(home: JourneyScreen(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    for (final chapter in journeyChapters) {
      expect(find.byKey(ValueKey('landmark-${chapter.id}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('final-landmark')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TimerlessController extends AppController {
  int storyWriteAttempts = 0;

  @override
  Future<void> markStoryBeatSeen(String id) {
    storyWriteAttempts++;
    return super.markStoryBeatSeen(id);
  }

  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
