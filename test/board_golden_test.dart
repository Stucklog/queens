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
import 'package:regalia/widgets/regalia_board.dart';
import 'package:regalia/widgets/completion_dialog.dart';

void main() {
  late PuzzleCatalog catalog;

  setUpAll(() async {
    await (FontLoader('RegaliaSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader('RegaliaDisplay')..addFont(
      rootBundle.load('assets/fonts/RobotoCondensed-Bold.ttf'),
    )).load();
    catalog = PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    );
  });

  testWidgets('6x6 narrow light board with large text and focus', (
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
        theme: RegaliaTheme.light(),
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
      matchesGoldenFile('goldens/board_6_light_narrow.png'),
    );
  });

  testWidgets('10x10 wide dark completed board', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final puzzle = catalog.puzzles.firstWhere((entry) => entry.size == 10);
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    for (final cell
        in const ExactSolver().solve(puzzle, limit: 1).solutions.single) {
      board.set(cell, ManualCellState.crown, recordUndo: false);
    }
    final automatic = const RuleEngine().automaticExclusions(puzzle, board);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.light(),
        darkTheme: RegaliaTheme.dark(),
        themeMode: ThemeMode.dark,
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
      matchesGoldenFile('goldens/board_10_dark_complete.png'),
    );
  });

  testWidgets('clean completion presentation in narrow light layout', (
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
        theme: RegaliaTheme.light(),
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
    await expectLater(
      find.byKey(const ValueKey('completion-golden')),
      matchesGoldenFile('goldens/completion_clean_light_narrow.png'),
    );
  });

  testWidgets('assisted completion presentation in wide dark layout', (
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
        theme: RegaliaTheme.light(),
        darkTheme: RegaliaTheme.dark(),
        themeMode: ThemeMode.dark,
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
    await expectLater(
      find.byKey(const ValueKey('completion-golden')),
      matchesGoldenFile('goldens/completion_assisted_dark_wide.png'),
    );
  });
}
