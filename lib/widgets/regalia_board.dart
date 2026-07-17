import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';

/// A visual explanation attached to a board cell.
///
/// Cues are deliberately separate from the cell's manual state: a hint may
/// explain an empty cell without turning it into a mark, and a progress check
/// may call attention to a mark without changing it.
enum BoardCue { hintSource, hintElimination, hintPlacement, checkError }

class RegaliaBoard extends StatelessWidget {
  const RegaliaBoard({
    super.key,
    required this.puzzle,
    required this.board,
    required this.onCellPressed,
    this.onCellExcluded,
    this.onExclusionDragStarted,
    this.onExclusionDragEnded,
    this.automaticExclusions = const {},
    this.conflicts = const {},
    this.highlighted = const {},
    this.cues = const {},
    this.selected,
  });

  final PuzzleDefinition puzzle;
  final BoardState board;
  final ValueChanged<Cell> onCellPressed;
  final ValueChanged<Cell>? onCellExcluded;
  final VoidCallback? onExclusionDragStarted;
  final VoidCallback? onExclusionDragEnded;
  final Set<Cell> automaticExclusions;
  final Set<Cell> conflicts;

  /// Legacy, untyped emphasis retained for callers that have not moved to
  /// [cues]. Explicit cues take precedence for the same cell.
  final Set<Cell> highlighted;
  final Map<Cell, BoardCue> cues;
  final Cell? selected;

  static const _regionColors = [
    Color(0xff263f67), // sapphire
    Color(0xff4b385f), // amethyst
    Color(0xff285551), // emerald
    Color(0xff5a3547), // garnet
    Color(0xff5b4b2d), // bronze
    Color(0xff31546b), // steel
    Color(0xff3d3e68), // indigo
    Color(0xff45543c), // moss
    Color(0xff563a54), // plum
    Color(0xff624334), // ember
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boardColors = theme.colorScheme;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: _DragExcluder(
        boardSize: puzzle.size,
        onCellExcluded: onCellExcluded,
        onDragStarted: onExclusionDragStarted,
        onDragEnded: onExclusionDragEnded,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(color: Color(0xaa080d20), offset: Offset(5, 5)),
            ],
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PixelBoardPainter(
                puzzle: puzzle,
                devicePixelRatio: devicePixelRatio,
                regionColors: _regionColors,
                seamColor: const Color(0xff111831),
                wallColor: boardColors.onSurface,
              ),
              foregroundPainter: _PixelBoardOverlayPainter(
                puzzle: puzzle,
                devicePixelRatio: devicePixelRatio,
                colorScheme: boardColors,
                conflicts: Set<Cell>.unmodifiable(conflicts),
                highlighted: Set<Cell>.unmodifiable(highlighted),
                cues: Map<Cell, BoardCue>.unmodifiable(cues),
                selected: selected,
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: puzzle.size,
                ),
                itemCount: puzzle.size * puzzle.size,
                itemBuilder: (context, index) {
                  final cell = Cell.fromIndex(index, puzzle.size);
                  final state = board.at(cell);
                  final region = puzzle.regionAt(cell);
                  return Semantics(
                    button: true,
                    selected: selected == cell ? true : null,
                    label:
                        'Row ${cell.row + 1}, column ${String.fromCharCode(65 + cell.column)}, region ${region + 1}',
                    value: _semanticValue(cell, state),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: ValueKey('cell-${cell.row}-${cell.column}'),
                        onTap: () => onCellPressed(cell),
                        focusColor: boardColors.primary.withValues(
                          alpha: .18,
                        ),
                        hoverColor: boardColors.onSurface.withValues(
                          alpha: .06,
                        ),
                        child: Center(
                          child: _PixelCellMark(
                            state: state,
                            automaticallyExcluded: automaticExclusions.contains(
                              cell,
                            ),
                            conflicting: conflicts.contains(cell),
                            devicePixelRatio: devicePixelRatio,
                            colorScheme: boardColors,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticValue(Cell cell, ManualCellState state) {
    final parts = <String>[
      switch (state) {
        ManualCellState.empty =>
          automaticExclusions.contains(cell)
              ? 'automatically excluded'
              : 'empty',
        ManualCellState.cross => 'marked X',
        ManualCellState.crown =>
          conflicts.contains(cell) ? 'crown, conflicting' : 'crown',
      },
    ];
    final cue = cues[cell];
    if (cue != null) {
      parts.add(switch (cue) {
        BoardCue.hintSource => 'hint source',
        BoardCue.hintElimination => 'hint says exclude this cell',
        BoardCue.hintPlacement => 'hint says place a crown here',
        BoardCue.checkError => 'check found an inconsistent mark',
      });
    } else if (highlighted.contains(cell)) {
      parts.add('highlighted');
    }
    if (selected == cell) parts.add('selected');
    return parts.join(', ');
  }
}

class _PixelBoardPainter extends CustomPainter {
  const _PixelBoardPainter({
    required this.puzzle,
    required this.devicePixelRatio,
    required this.regionColors,
    required this.seamColor,
    required this.wallColor,
  });

  final PuzzleDefinition puzzle;
  final double devicePixelRatio;
  final List<Color> regionColors;
  final Color seamColor;
  final Color wallColor;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PixelGridGeometry(
      size: size,
      boardSize: puzzle.size,
      devicePixelRatio: devicePixelRatio,
    );
    final fill = Paint()..isAntiAlias = false;

    for (var index = 0; index < puzzle.size * puzzle.size; index++) {
      final cell = Cell.fromIndex(index, puzzle.size);
      final region = puzzle.regionAt(cell);
      final color = regionColors[region % regionColors.length];
      final rect = geometry.cellRect(cell);
      canvas.drawRect(rect, fill..color = color);
      _drawDither(canvas, geometry, rect, region, color);
    }

    for (var row = 0; row < puzzle.size; row++) {
      for (var column = 1; column < puzzle.size; column++) {
        final left = Cell(row, column - 1);
        final right = Cell(row, column);
        final regionWall = puzzle.regionAt(left) != puzzle.regionAt(right);
        geometry.drawVerticalSegment(
          canvas,
          geometry.columnEdge(column),
          geometry.rowEdge(row),
          geometry.rowEdge(row + 1),
          regionWall ? 3 : 1,
          regionWall ? wallColor : seamColor,
        );
      }
    }
    for (var row = 1; row < puzzle.size; row++) {
      for (var column = 0; column < puzzle.size; column++) {
        final above = Cell(row - 1, column);
        final below = Cell(row, column);
        final regionWall = puzzle.regionAt(above) != puzzle.regionAt(below);
        geometry.drawHorizontalSegment(
          canvas,
          geometry.rowEdge(row),
          geometry.columnEdge(column),
          geometry.columnEdge(column + 1),
          regionWall ? 3 : 1,
          regionWall ? wallColor : seamColor,
        );
      }
    }
  }

  void _drawDither(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    int region,
    Color base,
  ) {
    const patterns = <List<Offset>>[
      [Offset(3, 3), Offset(11, 11)],
      [Offset(11, 3), Offset(3, 11)],
      [Offset(3, 7), Offset(11, 7)],
      [Offset(7, 3), Offset(7, 11)],
      [Offset(3, 3), Offset(11, 3), Offset(7, 11)],
    ];
    final unit = math.min(rect.width, rect.height) / 16;
    final color =
        Color.lerp(base, region.isEven ? Colors.white : Colors.black, .08)!;
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    for (final point in patterns[region % patterns.length]) {
      canvas.drawRect(
        geometry.snapRect(
          Rect.fromLTWH(
            rect.left + point.dx * unit,
            rect.top + point.dy * unit,
            unit,
            unit,
          ),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PixelBoardPainter oldDelegate) =>
      oldDelegate.puzzle != puzzle ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.seamColor != seamColor ||
      oldDelegate.wallColor != wallColor ||
      oldDelegate.regionColors != regionColors;
}

class _PixelBoardOverlayPainter extends CustomPainter {
  const _PixelBoardOverlayPainter({
    required this.puzzle,
    required this.devicePixelRatio,
    required this.colorScheme,
    required this.conflicts,
    required this.highlighted,
    required this.cues,
    required this.selected,
  });

  static const _hintSource = Color(0xff73d9df);
  static const _hintElimination = Color(0xffffbd61);
  static const _gold = Color(0xffffd95a);
  static const _frameInk = Color(0xff080d20);

  final PuzzleDefinition puzzle;
  final double devicePixelRatio;
  final ColorScheme colorScheme;
  final Set<Cell> conflicts;
  final Set<Cell> highlighted;
  final Map<Cell, BoardCue> cues;
  final Cell? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PixelGridGeometry(
      size: size,
      boardSize: puzzle.size,
      devicePixelRatio: devicePixelRatio,
    );
    for (var index = 0; index < puzzle.size * puzzle.size; index++) {
      final cell = Cell.fromIndex(index, puzzle.size);
      final rect = geometry.cellRect(cell);
      final cue = cues[cell];
      if (cue != null) {
        switch (cue) {
          case BoardCue.hintSource:
            _drawEdgeTicks(canvas, geometry, rect, _hintSource);
          case BoardCue.hintElimination:
            _drawDiagonalCorners(canvas, geometry, rect, _hintElimination);
          case BoardCue.hintPlacement:
            _drawBrackets(canvas, geometry, rect, _gold, inset: 4, arm: 4);
          case BoardCue.checkError:
            _drawCheckerFrame(canvas, geometry, rect, colorScheme.error);
        }
      } else if (highlighted.contains(cell)) {
        _drawEdgeTicks(canvas, geometry, rect, colorScheme.secondary);
      }
      if (selected == cell) {
        _drawBrackets(
          canvas,
          geometry,
          rect,
          colorScheme.primary,
          inset: 2,
          arm: 5,
        );
      }
      if (conflicts.contains(cell)) {
        _drawConflictCorners(canvas, geometry, rect, colorScheme.error);
      }
    }
    _drawFrame(canvas, geometry);
  }

  void _drawEdgeTicks(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    Color color,
  ) {
    final unit = geometry.scaledPixel(rect, 1);
    final length = unit * 4;
    final inset = unit * 2;
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    final centerX = geometry.snap((rect.left + rect.right) / 2);
    final centerY = geometry.snap((rect.top + rect.bottom) / 2);
    for (final tick in [
      Rect.fromCenter(
        center: Offset(centerX, rect.top + inset),
        width: length,
        height: unit,
      ),
      Rect.fromCenter(
        center: Offset(centerX, rect.bottom - inset),
        width: length,
        height: unit,
      ),
      Rect.fromCenter(
        center: Offset(rect.left + inset, centerY),
        width: unit,
        height: length,
      ),
      Rect.fromCenter(
        center: Offset(rect.right - inset, centerY),
        width: unit,
        height: length,
      ),
    ]) {
      canvas.drawRect(geometry.snapRect(tick), paint);
    }
  }

  void _drawDiagonalCorners(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    Color color,
  ) {
    final unit = geometry.scaledPixel(rect, 1);
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    for (var step = 0; step < 3; step++) {
      final delta = unit * (2 + step);
      canvas.drawRect(
        geometry.snapRect(
          Rect.fromLTWH(rect.left + delta, rect.top + delta, unit * 2, unit),
        ),
        paint,
      );
      canvas.drawRect(
        geometry.snapRect(
          Rect.fromLTWH(
            rect.right - delta - unit * 2,
            rect.bottom - delta - unit,
            unit * 2,
            unit,
          ),
        ),
        paint,
      );
    }
  }

  void _drawBrackets(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    Color color, {
    required double inset,
    required double arm,
  }) {
    final unit = geometry.scaledPixel(rect, 1);
    final edge = unit * inset;
    final length = unit * arm;
    final left = rect.left + edge;
    final top = rect.top + edge;
    final right = rect.right - edge;
    final bottom = rect.bottom - edge;
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    for (final piece in [
      Rect.fromLTWH(left, top, length, unit),
      Rect.fromLTWH(left, top, unit, length),
      Rect.fromLTWH(right - length, top, length, unit),
      Rect.fromLTWH(right - unit, top, unit, length),
      Rect.fromLTWH(left, bottom - unit, length, unit),
      Rect.fromLTWH(left, bottom - length, unit, length),
      Rect.fromLTWH(right - length, bottom - unit, length, unit),
      Rect.fromLTWH(right - unit, bottom - length, unit, length),
    ]) {
      canvas.drawRect(geometry.snapRect(piece), paint);
    }
  }

  void _drawCheckerFrame(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    Color color,
  ) {
    final unit = geometry.scaledPixel(rect, 1);
    final paint =
        Paint()
          ..color = color
          ..isAntiAlias = false;
    final inset = unit * 2;
    for (var step = 0; step < 5; step += 2) {
      final offset = unit * step;
      for (final pixel in [
        Rect.fromLTWH(rect.left + inset + offset, rect.top + inset, unit, unit),
        Rect.fromLTWH(
          rect.right - inset - offset - unit,
          rect.top + inset,
          unit,
          unit,
        ),
        Rect.fromLTWH(
          rect.left + inset + offset,
          rect.bottom - inset - unit,
          unit,
          unit,
        ),
        Rect.fromLTWH(
          rect.right - inset - offset - unit,
          rect.bottom - inset - unit,
          unit,
          unit,
        ),
      ]) {
        canvas.drawRect(geometry.snapRect(pixel), paint);
      }
    }
  }

  void _drawConflictCorners(
    Canvas canvas,
    _PixelGridGeometry geometry,
    Rect rect,
    Color color,
  ) {
    _drawBrackets(canvas, geometry, rect, color, inset: 1, arm: 3);
    final unit = geometry.scaledPixel(rect, 1);
    final paint =
        Paint()
          ..color = _frameInk
          ..isAntiAlias = false;
    final warning = Rect.fromLTWH(
      rect.right - unit * 5,
      rect.top + unit,
      unit * 3,
      unit * 4,
    );
    canvas.drawRect(geometry.snapRect(warning), paint);
    paint.color = color;
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(warning.left + unit, warning.top + unit, unit, unit * 2),
      ),
      paint,
    );
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(warning.left + unit, warning.bottom - unit, unit, unit),
      ),
      paint,
    );
  }

  void _drawFrame(Canvas canvas, _PixelGridGeometry geometry) {
    final size = geometry.size;
    final dark = geometry.snapLength(4);
    final gold = geometry.snapLength(1);
    final corner = geometry.snapLength(6);
    final inkPaint =
        Paint()
          ..color = _frameInk
          ..isAntiAlias = false;
    final goldPaint =
        Paint()
          ..color = _gold
          ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, dark), inkPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - dark, size.width, dark),
      inkPaint,
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, dark, size.height), inkPaint);
    canvas.drawRect(
      Rect.fromLTWH(size.width - dark, 0, dark, size.height),
      inkPaint,
    );
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(corner, dark - gold, size.width - corner * 2, gold),
      ),
      goldPaint,
    );
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(
          corner,
          size.height - dark,
          size.width - corner * 2,
          gold,
        ),
      ),
      goldPaint,
    );
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(dark - gold, corner, gold, size.height - corner * 2),
      ),
      goldPaint,
    );
    canvas.drawRect(
      geometry.snapRect(
        Rect.fromLTWH(
          size.width - dark,
          corner,
          gold,
          size.height - corner * 2,
        ),
      ),
      goldPaint,
    );
    for (final cornerPixel in [
      Rect.fromLTWH(dark - gold, dark - gold, gold * 2, gold * 2),
      Rect.fromLTWH(size.width - dark - gold, dark - gold, gold * 2, gold * 2),
      Rect.fromLTWH(dark - gold, size.height - dark - gold, gold * 2, gold * 2),
      Rect.fromLTWH(
        size.width - dark - gold,
        size.height - dark - gold,
        gold * 2,
        gold * 2,
      ),
    ]) {
      canvas.drawRect(geometry.snapRect(cornerPixel), goldPaint);
    }
  }

  @override
  bool shouldRepaint(_PixelBoardOverlayPainter oldDelegate) =>
      oldDelegate.puzzle != puzzle ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.colorScheme != colorScheme ||
      !setEquals(oldDelegate.conflicts, conflicts) ||
      !setEquals(oldDelegate.highlighted, highlighted) ||
      !mapEquals(oldDelegate.cues, cues) ||
      oldDelegate.selected != selected;
}

class _PixelCellMark extends StatelessWidget {
  const _PixelCellMark({
    required this.state,
    required this.automaticallyExcluded,
    required this.conflicting,
    required this.devicePixelRatio,
    required this.colorScheme,
  });

  final ManualCellState state;
  final bool automaticallyExcluded;
  final bool conflicting;
  final double devicePixelRatio;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: CustomPaint(
      painter: _PixelCellMarkPainter(
        state: state,
        automaticallyExcluded: automaticallyExcluded,
        conflicting: conflicting,
        devicePixelRatio: devicePixelRatio,
        colorScheme: colorScheme,
      ),
    ),
  );
}

class _PixelCellMarkPainter extends CustomPainter {
  const _PixelCellMarkPainter({
    required this.state,
    required this.automaticallyExcluded,
    required this.conflicting,
    required this.devicePixelRatio,
    required this.colorScheme,
  });

  static const _crownGold = Color(0xffe0a52f);
  static const _crownLight = Color(0xfffff3bc);
  static const _crownInk = Color(0xff2b1b24);

  final ManualCellState state;
  final bool automaticallyExcluded;
  final bool conflicting;
  final double devicePixelRatio;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = _CellSpriteCanvas(
      canvas: canvas,
      size: size,
      devicePixelRatio: devicePixelRatio,
    );
    switch (state) {
      case ManualCellState.crown:
        _drawCrown(pixels);
      case ManualCellState.cross:
        _drawCross(pixels);
      case ManualCellState.empty:
        if (automaticallyExcluded) _drawAutomaticExclusion(pixels);
    }
  }

  void _drawCrown(_CellSpriteCanvas pixels) {
    final face = conflicting ? colorScheme.error : _crownGold;
    final shadow = Color.lerp(face, Colors.black, .38)!;
    final highlight = conflicting ? colorScheme.onError : _crownLight;
    pixels.polygon(const [
      Offset(1, 14),
      Offset(1, 5),
      Offset(4, 9),
      Offset(5, 2),
      Offset(7, 9),
      Offset(8, 0),
      Offset(9, 9),
      Offset(11, 2),
      Offset(12, 9),
      Offset(15, 5),
      Offset(15, 14),
    ], _crownInk);
    pixels.polygon([
      const Offset(2, 12),
      const Offset(2, 7),
      const Offset(4.5, 10.5),
      const Offset(5.3, 5),
      const Offset(7.3, 11),
      const Offset(8, 3),
      const Offset(8.7, 11),
      const Offset(10.7, 5),
      const Offset(11.5, 10.5),
      const Offset(14, 7),
      const Offset(14, 12),
    ], face);
    pixels.rect(1, 11, 14, 4, _crownInk);
    pixels.rect(2, 12, 12, 2, face);
    pixels.rect(3, 12, 10, 1, highlight);
    pixels.rect(3, 14, 10, 1, shadow);
    pixels.rect(7, 12, 2, 2, highlight);
  }

  void _drawCross(_CellSpriteCanvas pixels) {
    final ink = const Color(0xff111831);
    final face = colorScheme.onSurface;
    for (var step = 0; step < 5; step++) {
      final coordinate = 3.0 + step * 2;
      pixels.rect(coordinate - 1, coordinate - 1, 4, 4, ink);
      pixels.rect(12 - step * 2, coordinate - 1, 4, 4, ink);
    }
    for (var step = 0; step < 5; step++) {
      final coordinate = 3.0 + step * 2;
      pixels.rect(coordinate, coordinate, 2, 2, face);
      pixels.rect(13 - step * 2, coordinate, 2, 2, face);
    }
  }

  void _drawAutomaticExclusion(_CellSpriteCanvas pixels) {
    final shade = colorScheme.onSurface.withValues(alpha: .25);
    final face = colorScheme.onSurfaceVariant.withValues(alpha: .5);
    pixels.rect(7, 5, 2, 6, shade);
    pixels.rect(5, 7, 6, 2, shade);
    pixels.rect(7, 7, 2, 2, face);
  }

  @override
  bool shouldRepaint(_PixelCellMarkPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.automaticallyExcluded != automaticallyExcluded ||
      oldDelegate.conflicting != conflicting ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.colorScheme != colorScheme;
}

class _CellSpriteCanvas {
  _CellSpriteCanvas({
    required this.canvas,
    required this.size,
    required this.devicePixelRatio,
  }) {
    final desired = math.min(size.width, size.height) / 20;
    unit = math.max(1 / devicePixelRatio, _snap(desired));
    origin = Offset(
      _snap((size.width - unit * 16) / 2),
      _snap((size.height - unit * 16) / 2),
    );
  }

  final Canvas canvas;
  final Size size;
  final double devicePixelRatio;
  late final double unit;
  late final Offset origin;

  double _snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  void rect(double x, double y, double width, double height, Color color) {
    canvas.drawRect(
      Rect.fromLTRB(
        _snap(origin.dx + x * unit),
        _snap(origin.dy + y * unit),
        _snap(origin.dx + (x + width) * unit),
        _snap(origin.dy + (y + height) * unit),
      ),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  void polygon(List<Offset> points, Color color) {
    final path = Path();
    Offset convert(Offset point) => Offset(
      _snap(origin.dx + point.dx * unit),
      _snap(origin.dy + point.dy * unit),
    );
    final first = convert(points.first);
    path.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final converted = convert(point);
      path.lineTo(converted.dx, converted.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }
}

class _PixelGridGeometry {
  const _PixelGridGeometry({
    required this.size,
    required this.boardSize,
    required this.devicePixelRatio,
  });

  final Size size;
  final int boardSize;
  final double devicePixelRatio;

  double snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  double snapLength(double value) =>
      math.max(1 / devicePixelRatio, snap(value));

  double columnEdge(int column) => snap(size.width * column / boardSize);

  double rowEdge(int row) => snap(size.height * row / boardSize);

  Rect cellRect(Cell cell) => Rect.fromLTRB(
    columnEdge(cell.column),
    rowEdge(cell.row),
    columnEdge(cell.column + 1),
    rowEdge(cell.row + 1),
  );

  Rect snapRect(Rect rect) => Rect.fromLTRB(
    snap(rect.left),
    snap(rect.top),
    snap(rect.right),
    snap(rect.bottom),
  );

  double scaledPixel(Rect cell, double units) {
    final logicalUnit = math.min(cell.width, cell.height) / 18;
    return snapLength(logicalUnit * units);
  }

  void drawVerticalSegment(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    double width,
    Color color,
  ) {
    final half = snapLength(width) / 2;
    canvas.drawRect(
      snapRect(Rect.fromLTRB(x - half, top, x + half, bottom)),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  void drawHorizontalSegment(
    Canvas canvas,
    double y,
    double left,
    double right,
    double width,
    Color color,
  ) {
    final half = snapLength(width) / 2;
    canvas.drawRect(
      snapRect(Rect.fromLTRB(left, y - half, right, y + half)),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }
}

class _DragExcluder extends StatefulWidget {
  const _DragExcluder({
    required this.boardSize,
    required this.onCellExcluded,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.child,
  });

  final int boardSize;
  final ValueChanged<Cell>? onCellExcluded;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;
  final Widget child;

  @override
  State<_DragExcluder> createState() => _DragExcluderState();
}

class _DragExcluderState extends State<_DragExcluder> {
  Cell? _startCell;
  Cell? _lastCell;
  final Set<Cell> _visited = {};

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    excludeFromSemantics: true,
    onPanDown:
        widget.onCellExcluded == null
            ? null
            : (details) => _startCell = _cellAt(details.localPosition),
    onPanStart:
        widget.onCellExcluded == null
            ? null
            : (details) {
              _visited.clear();
              widget.onDragStarted?.call();
              final current = _cellAt(details.localPosition);
              _markPath(_startCell ?? current, current);
              _lastCell = current;
            },
    onPanUpdate:
        widget.onCellExcluded == null
            ? null
            : (details) {
              final current = _cellAt(details.localPosition);
              _markPath(_lastCell ?? current, current);
              _lastCell = current;
            },
    onPanEnd: widget.onCellExcluded == null ? null : (_) => _finishDrag(),
    onPanCancel: widget.onCellExcluded == null ? null : _finishDrag,
    child: widget.child,
  );

  Cell _cellAt(Offset position) {
    final size = context.size ?? Size.zero;
    final column = (position.dx / (size.width / widget.boardSize)).floor();
    final row = (position.dy / (size.height / widget.boardSize)).floor();
    return Cell(
      row.clamp(0, widget.boardSize - 1),
      column.clamp(0, widget.boardSize - 1),
    );
  }

  void _markPath(Cell from, Cell to) {
    final rowDistance = (to.row - from.row).abs();
    final columnDistance = (to.column - from.column).abs();
    final steps = rowDistance > columnDistance ? rowDistance : columnDistance;
    for (var step = 0; step <= steps; step++) {
      final fraction = steps == 0 ? 0.0 : step / steps;
      final cell = Cell(
        (from.row + (to.row - from.row) * fraction).round(),
        (from.column + (to.column - from.column) * fraction).round(),
      );
      if (_visited.add(cell)) widget.onCellExcluded!(cell);
    }
  }

  void _finishDrag() {
    if (_lastCell != null) widget.onDragEnded?.call();
    _startCell = null;
    _lastCell = null;
    _visited.clear();
  }
}
