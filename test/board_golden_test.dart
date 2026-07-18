@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/core/rule_engine.dart';
import 'package:regalia/widgets/completion_dialog.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:regalia/widgets/regalia_board.dart';

void main() {
  late PuzzleCatalog catalog;

  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
    catalog = PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    );
  });

  testWidgets('6x6 narrow midnight board with large text and focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final puzzle = catalog.puzzles.firstWhere((entry) => entry.size == 6);
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    const selected = Cell(2, 3);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('golden'),
                child: SizedBox.square(
                  dimension: 358,
                  child: RegaliaBoard(
                    puzzle: puzzle,
                    board: board,
                    selected: selected,
                    onCellPressed: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/board_6_midnight_narrow.png'),
    );
  });

  testWidgets('10x10 wide midnight completed board', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final puzzle = catalog.puzzles.firstWhere(
      (entry) => entry.size == 10 && !entry.id.contains('/boss/'),
    );
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    for (final cell
        in const ExactSolver().solve(puzzle, limit: 1).solutions.single) {
      board.set(cell, ManualCellState.crown, recordUndo: false);
    }
    final automatic = const RuleEngine().automaticExclusions(puzzle, board);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('golden'),
              child: SizedBox.square(
                dimension: 680,
                child: RegaliaBoard(
                  puzzle: puzzle,
                  board: board,
                  automaticExclusions: automatic,
                  onCellPressed: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/board_10_midnight_complete.png'),
    );
  });

  testWidgets('6x6 pixel board state atlas', (tester) async {
    tester.view.physicalSize = const Size(520, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final puzzle = catalog.puzzles.firstWhere((entry) => entry.size == 6);
    final board =
        BoardState(puzzleId: puzzle.id, size: puzzle.size)
          ..set(const Cell(0, 0), ManualCellState.crown, recordUndo: false)
          ..set(const Cell(5, 5), ManualCellState.crown, recordUndo: false)
          ..set(const Cell(4, 4), ManualCellState.cross, recordUndo: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('pixel-state-atlas'),
              child: SizedBox.square(
                dimension: 444,
                child: RegaliaBoard(
                  puzzle: puzzle,
                  board: board,
                  automaticExclusions: {
                    const Cell(0, 5),
                    const Cell(3, 3),
                    const Cell(5, 0),
                  },
                  selected: const Cell(2, 3),
                  conflicts: {const Cell(5, 5)},
                  cues: {
                    const Cell(1, 1): BoardCue.hintSource,
                    const Cell(1, 4): BoardCue.hintElimination,
                    const Cell(4, 1): BoardCue.hintPlacement,
                    // A progress-check cue belongs on the mark being checked.
                    const Cell(4, 4): BoardCue.checkError,
                  },
                  onCellPressed: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('pixel-state-atlas')),
      matchesGoldenFile('goldens/board_pixel_state_atlas.png'),
    );
  });

  testWidgets('clean completion presentation in narrow midnight layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = BoardState(puzzleId: 'complete', size: 6)
      ..elapsedSeconds = 83;
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('completion-golden'),
            child: Center(
              child: CompletionDialog(
                board: board,
                onReplay: () {},
                onNext: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await _loadKnightAsset(tester);
    await expectLater(
      find.byKey(const ValueKey('completion-golden')),
      matchesGoldenFile('goldens/completion_clean_midnight_narrow.png'),
    );
  });

  testWidgets('assisted completion presentation in wide midnight layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final board = BoardState(
      puzzleId: 'assisted',
      size: 10,
      elapsedSeconds: 426,
      hintCount: 2,
      checkCount: 1,
      assisted: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey('completion-golden'),
            child: Center(
              child: CompletionDialog(
                board: board,
                onReplay: () {},
                onNext: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await _loadKnightAsset(tester);
    await expectLater(
      find.byKey(const ValueKey('completion-golden')),
      matchesGoldenFile('goldens/completion_assisted_midnight_wide.png'),
    );
  });
}

Future<void> _loadKnightAsset(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pump();
}
