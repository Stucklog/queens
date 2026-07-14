import 'package:flutter/material.dart';

import '../core/models.dart';
import 'crown_mark.dart';

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
  final Set<Cell> highlighted;
  final Cell? selected;

  static const _lightRegions = [
    Color(0xffffd8c9),
    Color(0xffd9e9cb),
    Color(0xffcfe2ef),
    Color(0xffffe8ad),
    Color(0xffe1d5ef),
    Color(0xffcde9df),
    Color(0xfff2d1dc),
    Color(0xffd9d4bd),
    Color(0xffcbd7ec),
    Color(0xffecd5b8),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 1,
      child: _DragExcluder(
        boardSize: puzzle.size,
        onCellExcluded: onCellExcluded,
        onDragStarted: onExclusionDragStarted,
        onDragEnded: onExclusionDragEnded,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
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
                final base = _lightRegions[region % _lightRegions.length];
                final background =
                    dark
                        ? Color.alphaBlend(
                          Colors.black.withValues(alpha: .54),
                          base,
                        )
                        : base;
                final top =
                    cell.row == 0 ||
                    puzzle.regionAt(Cell(cell.row - 1, cell.column)) != region;
                final left =
                    cell.column == 0 ||
                    puzzle.regionAt(Cell(cell.row, cell.column - 1)) != region;
                final bottom =
                    cell.row == puzzle.size - 1 ||
                    puzzle.regionAt(Cell(cell.row + 1, cell.column)) != region;
                final right =
                    cell.column == puzzle.size - 1 ||
                    puzzle.regionAt(Cell(cell.row, cell.column + 1)) != region;
                final regionColor = Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .82);
                return Semantics(
                  button: true,
                  label:
                      'Row ${cell.row + 1}, column ${String.fromCharCode(65 + cell.column)}, region ${region + 1}',
                  value: switch (state) {
                    ManualCellState.empty =>
                      automaticExclusions.contains(cell)
                          ? 'automatically excluded'
                          : 'empty',
                    ManualCellState.cross => 'marked X',
                    ManualCellState.crown =>
                      conflicts.contains(cell) ? 'crown, conflicting' : 'crown',
                  },
                  child: Material(
                    color:
                        highlighted.contains(cell)
                            ? Color.alphaBlend(
                              Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: .38),
                              background,
                            )
                            : background,
                    child: InkWell(
                      key: ValueKey('cell-${cell.row}-${cell.column}'),
                      onTap: () => onCellPressed(cell),
                      focusColor: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: .45),
                      child: AnimatedContainer(
                        duration:
                            MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: regionColor,
                              width: top ? 2.2 : .25,
                            ),
                            left: BorderSide(
                              color: regionColor,
                              width: left ? 2.2 : .25,
                            ),
                            bottom: BorderSide(
                              color: regionColor,
                              width: bottom ? 2.2 : .25,
                            ),
                            right: BorderSide(
                              color: regionColor,
                              width: right ? 2.2 : .25,
                            ),
                          ),
                        ),
                        foregroundDecoration:
                            selected == cell
                                ? BoxDecoration(
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    width: 3,
                                  ),
                                )
                                : null,
                        child: Center(child: _mark(context, cell, state)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget? _mark(BuildContext context, Cell cell, ManualCellState state) {
    if (state == ManualCellState.crown) {
      return Padding(
        padding: const EdgeInsets.all(5),
        child: FittedBox(
          child: CrownMark(
            color:
                conflicts.contains(cell)
                    ? Theme.of(context).colorScheme.error
                    : null,
            size: 30,
          ),
        ),
      );
    }
    if (state == ManualCellState.cross) {
      return FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.close_rounded,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .9),
            size: 28,
          ),
        ),
      );
    }
    if (automaticExclusions.contains(cell)) {
      return FractionallySizedBox(
        widthFactor: .18,
        heightFactor: .18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .25),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return null;
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
