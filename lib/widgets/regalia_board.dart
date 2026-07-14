import 'package:flutter/material.dart';

import '../core/models.dart';
import 'crown_mark.dart';

class RegaliaBoard extends StatelessWidget {
  const RegaliaBoard({
    super.key,
    required this.puzzle,
    required this.board,
    required this.onCellPressed,
    this.automaticExclusions = const {},
    this.conflicts = const {},
    this.highlighted = const {},
    this.selected,
  });

  final PuzzleDefinition puzzle;
  final BoardState board;
  final ValueChanged<Cell> onCellPressed;
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
