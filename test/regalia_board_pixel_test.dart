import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/widgets/regalia_board.dart';

void main() {
  testWidgets('pixel board exposes typed cues and selection accessibly', (
    tester,
  ) async {
    final catalog = PuzzleCatalog.fromJsonString(
      File('assets/puzzles/catalog.json').readAsStringSync(),
    );
    final puzzle = catalog.puzzles.first;
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    final cues = <Cell, BoardCue>{
      const Cell(0, 0): BoardCue.hintSource,
      const Cell(0, 1): BoardCue.hintElimination,
      const Cell(0, 2): BoardCue.hintPlacement,
      const Cell(0, 3): BoardCue.checkError,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 360,
              child: RegaliaBoard(
                puzzle: puzzle,
                board: board,
                cues: cues,
                selected: const Cell(0, 2),
                onCellPressed: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const ValueKey('cell-0-0'))),
      matchesSemantics(
        label:
            'Row 1, column A, region ${puzzle.regionAt(const Cell(0, 0)) + 1}',
        value: 'empty, hint source',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cell-0-2'))),
      matchesSemantics(
        label:
            'Row 1, column C, region ${puzzle.regionAt(const Cell(0, 2)) + 1}',
        value: 'empty, hint says place a crown here, selected',
        isButton: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(RegaliaBoard),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });
}
