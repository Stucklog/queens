import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      tester.getSemantics(find.byKey(const ValueKey('cell-0-1'))),
      matchesSemantics(
        label:
            'Row 1, column B, region ${puzzle.regionAt(const Cell(0, 1)) + 1}',
        value: 'empty, hint says exclude this cell',
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
        hasSelectedState: true,
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

  testWidgets(
    'automatic exclusions retain distinct semantics but render as player X marks',
    (tester) async {
      tester.view.physicalSize = const Size(400, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final catalog = PuzzleCatalog.fromJsonString(
        File('assets/puzzles/catalog.json').readAsStringSync(),
      );
      final puzzle = catalog.puzzles.first;
      const target = Cell(1, 1);
      final manualBoard = BoardState(puzzleId: puzzle.id, size: puzzle.size)
        ..set(target, ManualCellState.cross, recordUndo: false);
      final automaticBoard = BoardState(puzzleId: puzzle.id, size: puzzle.size);
      final manualCapture = GlobalKey();
      final automaticCapture = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    key: manualCapture,
                    child: SizedBox.square(
                      dimension: 320,
                      child: RegaliaBoard(
                        key: const ValueKey('manual-cross-board'),
                        puzzle: puzzle,
                        board: manualBoard,
                        onCellPressed: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    key: automaticCapture,
                    child: SizedBox.square(
                      dimension: 320,
                      child: RegaliaBoard(
                        key: const ValueKey('automatic-cross-board'),
                        puzzle: puzzle,
                        board: automaticBoard,
                        automaticExclusions: {target},
                        onCellPressed: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final manualCell = find.descendant(
        of: find.byKey(const ValueKey('manual-cross-board')),
        matching: find.byKey(const ValueKey('cell-1-1')),
      );
      final automaticCell = find.descendant(
        of: find.byKey(const ValueKey('automatic-cross-board')),
        matching: find.byKey(const ValueKey('cell-1-1')),
      );
      final label = 'Row 2, column B, region ${puzzle.regionAt(target) + 1}';
      expect(
        tester.getSemantics(manualCell),
        matchesSemantics(
          label: label,
          value: 'marked X',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(automaticCell),
        matchesSemantics(
          label: label,
          value: 'automatically excluded',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      final manualRaster = await _raster(tester, manualCapture);
      final automaticRaster = await _raster(tester, automaticCapture);
      expect(automaticRaster.width, manualRaster.width);
      expect(automaticRaster.height, manualRaster.height);
      expect(
        listEquals(automaticRaster.pixels, manualRaster.pixels),
        isTrue,
        reason:
            'Changing only the internal exclusion state must not change the rendered board.',
      );
    },
  );
}

Future<({Uint8List pixels, int width, int height})> _raster(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final raster = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = (
      pixels: Uint8List.fromList(bytes!.buffer.asUint8List()),
      width: image.width,
      height: image.height,
    );
    image.dispose();
    return result;
  });
  return raster!;
}
