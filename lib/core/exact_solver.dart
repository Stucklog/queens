import 'models.dart';

class ExactSolveResult {
  const ExactSolveResult({
    required this.solutions,
    required this.searchNodes,
    required this.backtracks,
    required this.maxBranching,
  });

  final List<List<Cell>> solutions;
  final int searchNodes;
  final int backtracks;
  final int maxBranching;

  int get solutionCount => solutions.length;
}

class ExactSolver {
  const ExactSolver();

  ExactSolveResult solve(
    PuzzleDefinition puzzle, {
    BoardState? board,
    Set<Cell> required = const {},
    Set<Cell> forbidden = const {},
    int limit = 2,
  }) {
    final requiredCells = <Cell>{...required};
    final forbiddenCells = <Cell>{...forbidden};
    if (board != null) {
      for (final cell in puzzle.cells) {
        switch (board.at(cell)) {
          case ManualCellState.crown:
            requiredCells.add(cell);
          case ManualCellState.cross:
            forbiddenCells.add(cell);
          case ManualCellState.empty:
            break;
        }
      }
    }

    final requiredRows = <int, Cell>{};
    final usedRequiredColumns = <int>{};
    final usedRequiredRegions = <int>{};
    var requiredInvalid = false;
    for (final cell in requiredCells) {
      if (cell.row < 0 ||
          cell.row >= puzzle.size ||
          cell.column < 0 ||
          cell.column >= puzzle.size ||
          forbiddenCells.contains(cell)) {
        requiredInvalid = true;
        break;
      }
      final previous = requiredRows[cell.row];
      final region = puzzle.regionAt(cell);
      if (previous != null ||
          !usedRequiredColumns.add(cell.column) ||
          !usedRequiredRegions.add(region)) {
        requiredInvalid = true;
        break;
      }
      requiredRows[cell.row] = cell;
    }
    if (!requiredInvalid) {
      final values = requiredCells.toList();
      for (var i = 0; i < values.length; i++) {
        for (var j = i + 1; j < values.length; j++) {
          if ((values[i].row - values[j].row).abs() <= 1 &&
              (values[i].column - values[j].column).abs() <= 1) {
            requiredInvalid = true;
          }
        }
      }
    }
    if (requiredInvalid) {
      return const ExactSolveResult(
        solutions: [],
        searchNodes: 0,
        backtracks: 0,
        maxBranching: 0,
      );
    }

    final assigned = <int, Cell>{};
    final usedColumns = <int>{};
    final usedRegions = <int>{};
    final solutions = <List<Cell>>[];
    var searchNodes = 0;
    var backtracks = 0;
    var maxBranching = 0;

    bool legal(Cell cell) {
      if (forbiddenCells.contains(cell) ||
          usedColumns.contains(cell.column) ||
          usedRegions.contains(puzzle.regionAt(cell))) {
        return false;
      }
      for (final other in assigned.values) {
        if ((cell.row - other.row).abs() <= 1 &&
            (cell.column - other.column).abs() <= 1) {
          return false;
        }
      }
      return true;
    }

    List<Cell> candidatesFor(int row) {
      final fixed = requiredRows[row];
      if (fixed != null) return legal(fixed) ? [fixed] : const [];
      return [
        for (var column = 0; column < puzzle.size; column++)
          if (legal(Cell(row, column))) Cell(row, column),
      ];
    }

    void search() {
      if (solutions.length >= limit) return;
      searchNodes++;
      if (assigned.length == puzzle.size) {
        solutions.add(assigned.values.toList()..sort());
        return;
      }
      int? selectedRow;
      var selectedCandidates = <Cell>[];
      for (var row = 0; row < puzzle.size; row++) {
        if (assigned.containsKey(row)) continue;
        final candidates = candidatesFor(row);
        if (selectedRow == null ||
            candidates.length < selectedCandidates.length) {
          selectedRow = row;
          selectedCandidates = candidates;
        }
        if (candidates.isEmpty) break;
      }
      if (selectedCandidates.isEmpty) {
        backtracks++;
        return;
      }
      if (selectedCandidates.length > maxBranching) {
        maxBranching = selectedCandidates.length;
      }
      for (final cell in selectedCandidates) {
        assigned[cell.row] = cell;
        usedColumns.add(cell.column);
        usedRegions.add(puzzle.regionAt(cell));
        search();
        assigned.remove(cell.row);
        usedColumns.remove(cell.column);
        usedRegions.remove(puzzle.regionAt(cell));
        if (solutions.length >= limit) return;
      }
    }

    search();
    return ExactSolveResult(
      solutions: solutions,
      searchNodes: searchNodes,
      backtracks: backtracks,
      maxBranching: maxBranching,
    );
  }

  int countSolutions(
    PuzzleDefinition puzzle, {
    BoardState? board,
    int limit = 2,
  }) => solve(puzzle, board: board, limit: limit).solutionCount;
}
