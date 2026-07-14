import 'exact_solver.dart';
import 'models.dart';

class CrownConflict {
  const CrownConflict(this.first, this.second, this.reason);
  final Cell first;
  final Cell second;
  final String reason;
}

class ProgressCheck {
  const ProgressCheck({
    required this.isValid,
    required this.isComplete,
    required this.message,
    this.conflicts = const [],
    this.inconsistentMarks = const {},
  });

  final bool isValid;
  final bool isComplete;
  final String message;
  final List<CrownConflict> conflicts;
  final Set<Cell> inconsistentMarks;
}

class RuleEngine {
  const RuleEngine({this.exactSolver = const ExactSolver()});
  final ExactSolver exactSolver;

  List<Cell> crowns(PuzzleDefinition puzzle, BoardState board) => [
    for (final cell in puzzle.cells)
      if (board.at(cell) == ManualCellState.crown) cell,
  ];

  List<CrownConflict> directConflicts(
    PuzzleDefinition puzzle,
    BoardState board,
  ) {
    final placed = crowns(puzzle, board);
    final conflicts = <CrownConflict>[];
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        final a = placed[i];
        final b = placed[j];
        String? reason;
        if (a.row == b.row) {
          reason = 'Two crowns share row ${a.row + 1}.';
        } else if (a.column == b.column) {
          reason =
              'Two crowns share column ${String.fromCharCode(65 + a.column)}.';
        } else if (puzzle.regionAt(a) == puzzle.regionAt(b)) {
          reason = 'Two crowns share the same region.';
        } else if ((a.row - b.row).abs() == 1 &&
            (a.column - b.column).abs() == 1) {
          reason = 'Crowns may not touch diagonally.';
        }
        if (reason != null) conflicts.add(CrownConflict(a, b, reason));
      }
    }
    return conflicts;
  }

  Set<Cell> automaticExclusions(PuzzleDefinition puzzle, BoardState board) {
    final result = <Cell>{};
    final placed = crowns(puzzle, board);
    for (final crown in placed) {
      for (final cell in puzzle.cells) {
        if (cell == crown) continue;
        if (cell.row == crown.row ||
            cell.column == crown.column ||
            puzzle.regionAt(cell) == puzzle.regionAt(crown) ||
            ((cell.row - crown.row).abs() == 1 &&
                (cell.column - crown.column).abs() == 1)) {
          result.add(cell);
        }
      }
    }
    return result;
  }

  bool isComplete(PuzzleDefinition puzzle, BoardState board) =>
      crowns(puzzle, board).length == puzzle.size &&
      directConflicts(puzzle, board).isEmpty;

  ProgressCheck check(PuzzleDefinition puzzle, BoardState board) {
    final conflicts = directConflicts(puzzle, board);
    if (conflicts.isNotEmpty) {
      return ProgressCheck(
        isValid: false,
        isComplete: false,
        message: conflicts.first.reason,
        conflicts: conflicts,
      );
    }
    final exact = exactSolver.solve(puzzle, board: board, limit: 1);
    if (exact.solutionCount == 0) {
      final marks = <Cell>{
        for (final cell in puzzle.cells)
          if (board.at(cell) != ManualCellState.empty) cell,
      };
      final minimal = _minimalInconsistentSet(puzzle, board, marks);
      return ProgressCheck(
        isValid: false,
        isComplete: false,
        message:
            minimal.length == 1
                ? '${minimal.first} prevents every valid completion.'
                : 'These ${minimal.length} marks cannot all belong to one valid completion.',
        inconsistentMarks: minimal,
      );
    }
    final complete = isComplete(puzzle, board);
    return ProgressCheck(
      isValid: true,
      isComplete: complete,
      message:
          complete
              ? 'Every row, column, and region is crowned.'
              : 'Your board still has a valid completion.',
    );
  }

  Set<Cell> _minimalInconsistentSet(
    PuzzleDefinition puzzle,
    BoardState original,
    Set<Cell> marks,
  ) {
    final working = Set<Cell>.of(marks);
    for (final candidate in marks.toList()) {
      if (working.length == 1) break;
      final trial = BoardState(
        puzzleId: original.puzzleId,
        size: original.size,
      );
      for (final cell in working) {
        if (cell != candidate) {
          trial.set(cell, original.at(cell), recordUndo: false);
        }
      }
      if (exactSolver.solve(puzzle, board: trial, limit: 1).solutionCount ==
          0) {
        working.remove(candidate);
      }
    }
    return working;
  }

  bool regionsAreConnected(PuzzleDefinition puzzle) {
    for (var region = 0; region < puzzle.size; region++) {
      final cells =
          puzzle.cells.where((cell) => puzzle.regionAt(cell) == region).toSet();
      if (cells.isEmpty) return false;
      final reached = <Cell>{cells.first};
      final queue = <Cell>[cells.first];
      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        for (final neighbor in _orthogonalNeighbors(cell, puzzle.size)) {
          if (cells.contains(neighbor) && reached.add(neighbor)) {
            queue.add(neighbor);
          }
        }
      }
      if (reached.length != cells.length) return false;
    }
    return true;
  }

  Iterable<Cell> _orthogonalNeighbors(Cell cell, int size) sync* {
    if (cell.row > 0) yield Cell(cell.row - 1, cell.column);
    if (cell.row + 1 < size) yield Cell(cell.row + 1, cell.column);
    if (cell.column > 0) yield Cell(cell.row, cell.column - 1);
    if (cell.column + 1 < size) yield Cell(cell.row, cell.column + 1);
  }
}
