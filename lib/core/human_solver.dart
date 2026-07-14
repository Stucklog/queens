import 'exact_solver.dart';
import 'models.dart';
import 'rule_engine.dart';

enum DeductionTechnique {
  directExclusion,
  singleRemaining,
  lockedIntersection,
  adjacentRowSupport,
  hallPair,
  hallTriple,
  oneStepContradiction,
}

extension DeductionRank on DeductionTechnique {
  int get rank => switch (this) {
    DeductionTechnique.directExclusion ||
    DeductionTechnique.singleRemaining => 0,
    DeductionTechnique.lockedIntersection ||
    DeductionTechnique.adjacentRowSupport => 1,
    DeductionTechnique.hallPair || DeductionTechnique.hallTriple => 2,
    DeductionTechnique.oneStepContradiction => 3,
  };
}

class Deduction {
  const Deduction({
    required this.technique,
    required this.explanation,
    this.placement,
    this.eliminated = const {},
    this.sources = const {},
  });
  final DeductionTechnique technique;
  final String explanation;
  final Cell? placement;
  final Set<Cell> eliminated;
  final Set<Cell> sources;
}

class DifficultyReport {
  const DifficultyReport({
    required this.solved,
    required this.tier,
    required this.score,
    required this.trace,
    required this.scoringModel,
  });
  final bool solved;
  final DifficultyTier tier;
  final int score;
  final List<Deduction> trace;
  final String scoringModel;
}

class HumanSolver {
  const HumanSolver({
    this.exactSolver = const ExactSolver(),
    this.ruleEngine = const RuleEngine(),
  });
  final ExactSolver exactSolver;
  final RuleEngine ruleEngine;
  static const scoringModel = 'human-v3';

  Deduction? nextDeduction(PuzzleDefinition puzzle, BoardState board) {
    final progress = ruleEngine.check(puzzle, board);
    if (!progress.isValid) {
      return Deduction(
        technique: DeductionTechnique.directExclusion,
        explanation: progress.message,
        sources: {
          ...progress.inconsistentMarks,
          for (final conflict in progress.conflicts) ...[
            conflict.first,
            conflict.second,
          ],
        },
      );
    }
    final placed = ruleEngine.crowns(puzzle, board).toSet();
    final candidates = _initialCandidates(puzzle, board, placed);
    return _findDeduction(
      puzzle,
      placed,
      candidates,
      maxTechniqueRank: puzzle.tier.index,
      allowContradiction: true,
    );
  }

  DifficultyReport analyze(PuzzleDefinition puzzle, {int maxSteps = 500}) {
    ({bool solved, List<Deduction> trace})? result;
    var maxRank = 0;
    for (var rank = 0; rank < DifficultyTier.values.length; rank++) {
      final attempt = _solveWithLimit(puzzle, rank, maxSteps);
      result = attempt;
      maxRank = rank;
      if (attempt.solved) break;
    }
    final trace = result!.trace;
    final weighted = trace.fold<int>(
      0,
      (sum, item) => sum + item.technique.rank + 1,
    );
    final score = (maxRank * 25 + ((weighted / (puzzle.size * 6)) * 24).round())
        .clamp(maxRank * 25, maxRank * 25 + 24);
    return DifficultyReport(
      solved: result.solved,
      tier: DifficultyTier.values[maxRank],
      score: score,
      trace: List.unmodifiable(trace),
      scoringModel: scoringModel,
    );
  }

  ({bool solved, List<Deduction> trace}) _solveWithLimit(
    PuzzleDefinition puzzle,
    int maxTechniqueRank,
    int maxSteps,
  ) {
    final placed = <Cell>{};
    final candidates = puzzle.cells.toSet();
    final trace = <Deduction>[];
    while (placed.length < puzzle.size && trace.length < maxSteps) {
      final deduction = _findDeduction(
        puzzle,
        placed,
        candidates,
        maxTechniqueRank: maxTechniqueRank,
        allowContradiction: maxTechniqueRank >= 3,
      );
      if (deduction == null) break;
      trace.add(deduction);
      _apply(puzzle, placed, candidates, deduction);
    }
    return (solved: placed.length == puzzle.size, trace: trace);
  }

  Set<Cell> _initialCandidates(
    PuzzleDefinition puzzle,
    BoardState board,
    Set<Cell> placed,
  ) {
    final candidates = <Cell>{};
    final exclusions = ruleEngine.automaticExclusions(puzzle, board);
    for (final cell in puzzle.cells) {
      if (board.at(cell) != ManualCellState.cross &&
          !exclusions.contains(cell) &&
          !placed.contains(cell)) {
        candidates.add(cell);
      }
    }
    return candidates;
  }

  Deduction? _findDeduction(
    PuzzleDefinition puzzle,
    Set<Cell> placed,
    Set<Cell> candidates, {
    required int maxTechniqueRank,
    required bool allowContradiction,
  }) {
    for (var row = 0; row < puzzle.size; row++) {
      if (placed.any((cell) => cell.row == row)) continue;
      final options = candidates.where((cell) => cell.row == row).toSet();
      if (options.length == 1) {
        return Deduction(
          technique: DeductionTechnique.singleRemaining,
          placement: options.single,
          sources: options,
          explanation:
              'Row ${row + 1} has only one possible cell: ${options.single}.',
        );
      }
    }
    for (var column = 0; column < puzzle.size; column++) {
      if (placed.any((cell) => cell.column == column)) continue;
      final options = candidates.where((cell) => cell.column == column).toSet();
      if (options.length == 1) {
        return Deduction(
          technique: DeductionTechnique.singleRemaining,
          placement: options.single,
          sources: options,
          explanation:
              'Column ${String.fromCharCode(65 + column)} has only one possible cell: ${options.single}.',
        );
      }
    }
    if (maxTechniqueRank >= 1) {
      for (var row = 0; row < puzzle.size; row++) {
        if (placed.any((cell) => cell.row == row)) continue;
        final options = candidates.where((cell) => cell.row == row).toSet();
        final regions = options.map(puzzle.regionAt).toSet();
        if (options.isNotEmpty && regions.length == 1) {
          final region = regions.single;
          final eliminated =
              candidates
                  .where(
                    (cell) =>
                        cell.row != row && puzzle.regionAt(cell) == region,
                  )
                  .toSet();
          if (eliminated.isNotEmpty) {
            return Deduction(
              technique: DeductionTechnique.lockedIntersection,
              eliminated: eliminated,
              sources: options,
              explanation:
                  'Row ${row + 1} must use region ${region + 1}, so the rest of that region can be crossed out.',
            );
          }
        }
      }
      for (var column = 0; column < puzzle.size; column++) {
        if (placed.any((cell) => cell.column == column)) continue;
        final options =
            candidates.where((cell) => cell.column == column).toSet();
        final regions = options.map(puzzle.regionAt).toSet();
        if (options.isNotEmpty && regions.length == 1) {
          final region = regions.single;
          final eliminated =
              candidates
                  .where(
                    (cell) =>
                        cell.column != column &&
                        puzzle.regionAt(cell) == region,
                  )
                  .toSet();
          if (eliminated.isNotEmpty) {
            return Deduction(
              technique: DeductionTechnique.lockedIntersection,
              eliminated: eliminated,
              sources: options,
              explanation:
                  'Column ${String.fromCharCode(65 + column)} must use region ${region + 1}, so the rest of that region can be crossed out.',
            );
          }
        }
      }
    }
    for (var region = 0; region < puzzle.size; region++) {
      if (placed.any((cell) => puzzle.regionAt(cell) == region)) continue;
      final options =
          candidates.where((cell) => puzzle.regionAt(cell) == region).toSet();
      if (options.length == 1) {
        return Deduction(
          technique: DeductionTechnique.singleRemaining,
          placement: options.single,
          sources: options,
          explanation:
              'Region ${region + 1} has only one possible cell: ${options.single}.',
        );
      }
      if (maxTechniqueRank >= 1 && options.isNotEmpty) {
        final rows = options.map((cell) => cell.row).toSet();
        if (rows.length == 1) {
          final eliminated =
              candidates
                  .where(
                    (cell) =>
                        cell.row == rows.single &&
                        puzzle.regionAt(cell) != region,
                  )
                  .toSet();
          if (eliminated.isNotEmpty) {
            return Deduction(
              technique: DeductionTechnique.lockedIntersection,
              eliminated: eliminated,
              sources: options,
              explanation:
                  'Region ${region + 1} must use row ${rows.single + 1}, so the rest of that row can be crossed out.',
            );
          }
        }
        final columns = options.map((cell) => cell.column).toSet();
        if (columns.length == 1) {
          final eliminated =
              candidates
                  .where(
                    (cell) =>
                        cell.column == columns.single &&
                        puzzle.regionAt(cell) != region,
                  )
                  .toSet();
          if (eliminated.isNotEmpty) {
            return Deduction(
              technique: DeductionTechnique.lockedIntersection,
              eliminated: eliminated,
              sources: options,
              explanation:
                  'Region ${region + 1} must use column ${String.fromCharCode(65 + columns.single)}, so other cells there can be crossed out.',
            );
          }
        }
      }
    }

    if (maxTechniqueRank >= 1) {
      for (var sourceRow = 0; sourceRow < puzzle.size; sourceRow++) {
        if (placed.any((cell) => cell.row == sourceRow)) continue;
        final support =
            candidates
                .where((cell) => cell.row == sourceRow)
                .map((cell) => cell.column)
                .toSet();
        if (support.isEmpty) continue;
        for (final targetRow in [sourceRow - 1, sourceRow + 1]) {
          if (targetRow < 0 ||
              targetRow >= puzzle.size ||
              placed.any((cell) => cell.row == targetRow)) {
            continue;
          }
          final targetCandidates =
              candidates.where((cell) => cell.row == targetRow).toSet();
          final eliminated =
              targetCandidates
                  .where(
                    (cell) => support.every(
                      (column) => (column - cell.column).abs() <= 1,
                    ),
                  )
                  .toSet();
          if (eliminated.isNotEmpty &&
              eliminated.length < targetCandidates.length) {
            return Deduction(
              technique: DeductionTechnique.adjacentRowSupport,
              eliminated: eliminated,
              sources:
                  candidates.where((cell) => cell.row == sourceRow).toSet(),
              explanation:
                  'Those cells in row ${targetRow + 1} would touch every possible crown in row ${sourceRow + 1}.',
            );
          }
        }
      }
    }

    final direct = _directExclusion(puzzle, placed, candidates);
    if (direct != null) return direct;

    if (maxTechniqueRank >= 2) {
      final activeRows = [
        for (var row = 0; row < puzzle.size; row++)
          if (!placed.any((cell) => cell.row == row)) row,
      ];
      final preferTriples =
          int.parse(
            puzzle.contentHash.substring(puzzle.contentHash.length - 1),
            radix: 16,
          ).isOdd;
      final hallWidths = preferTriples ? const [3, 2] : const [2, 3];
      for (final width in hallWidths) {
        for (final rows in _combinations(activeRows, width)) {
          final columns = <int>{};
          for (final row in rows) {
            columns.addAll(
              candidates
                  .where((cell) => cell.row == row)
                  .map((cell) => cell.column),
            );
          }
          if (columns.length != width) continue;
          final eliminated =
              candidates
                  .where(
                    (cell) =>
                        !rows.contains(cell.row) &&
                        columns.contains(cell.column),
                  )
                  .toSet();
          if (eliminated.isNotEmpty) {
            return Deduction(
              technique:
                  width == 2
                      ? DeductionTechnique.hallPair
                      : DeductionTechnique.hallTriple,
              eliminated: eliminated,
              sources:
                  candidates
                      .where(
                        (cell) =>
                            rows.contains(cell.row) &&
                            columns.contains(cell.column),
                      )
                      .toSet(),
              explanation:
                  'Rows ${rows.map((row) => row + 1).join(', ')} must occupy ${width == 2 ? 'a pair' : 'a triple'} of columns, excluding them elsewhere.',
            );
          }
        }
      }
    }

    if (allowContradiction) {
      final ordered = candidates.toList()..sort();
      for (final candidate in ordered) {
        final contradiction = _assumptionContradiction(
          puzzle,
          placed,
          candidates,
          candidate,
        );
        if (contradiction != null) return contradiction;
      }
    }
    return null;
  }

  Deduction? _assumptionContradiction(
    PuzzleDefinition puzzle,
    Set<Cell> placed,
    Set<Cell> candidates,
    Cell assumption,
  ) {
    final trialPlaced = Set<Cell>.of(placed);
    final trialCandidates = Set<Cell>.of(candidates);
    _apply(
      puzzle,
      trialPlaced,
      trialCandidates,
      Deduction(
        technique: DeductionTechnique.directExclusion,
        explanation: '',
        placement: assumption,
      ),
    );
    for (var step = 0; step < puzzle.size * puzzle.size * 4; step++) {
      final emptyUnit = _emptyRequiredUnit(
        puzzle,
        trialPlaced,
        trialCandidates,
      );
      if (emptyUnit != null) {
        return Deduction(
          technique: DeductionTechnique.oneStepContradiction,
          eliminated: {assumption},
          sources: {assumption},
          explanation:
              'Assume $assumption holds a crown. The resulting direct, locked, and Hall deductions leave ${emptyUnit.$1} with no possible cell, so $assumption can be crossed out.',
        );
      }
      if (trialPlaced.length == puzzle.size) return null;
      final deduction = _findDeduction(
        puzzle,
        trialPlaced,
        trialCandidates,
        maxTechniqueRank: 2,
        allowContradiction: false,
      );
      if (deduction == null) return null;
      _apply(puzzle, trialPlaced, trialCandidates, deduction);
    }
    return null;
  }

  (String, Set<Cell>)? _emptyRequiredUnit(
    PuzzleDefinition puzzle,
    Set<Cell> placed,
    Set<Cell> candidates,
  ) {
    for (var row = 0; row < puzzle.size; row++) {
      if (!placed.any((cell) => cell.row == row) &&
          !candidates.any((cell) => cell.row == row)) {
        return ('row ${row + 1}', const {});
      }
    }
    for (var column = 0; column < puzzle.size; column++) {
      if (!placed.any((cell) => cell.column == column) &&
          !candidates.any((cell) => cell.column == column)) {
        return ('column ${String.fromCharCode(65 + column)}', const {});
      }
    }
    for (var region = 0; region < puzzle.size; region++) {
      if (!placed.any((cell) => puzzle.regionAt(cell) == region) &&
          !candidates.any((cell) => puzzle.regionAt(cell) == region)) {
        return ('region ${region + 1}', const {});
      }
    }
    return null;
  }

  Deduction? _directExclusion(
    PuzzleDefinition puzzle,
    Set<Cell> placed,
    Set<Cell> candidates,
  ) {
    final ordered = candidates.toList()..sort();
    for (final candidate in ordered) {
      for (var row = 0; row < puzzle.size; row++) {
        if (row == candidate.row || placed.any((cell) => cell.row == row)) {
          continue;
        }
        final support = candidates.where((cell) => cell.row == row).toSet();
        if (support.isNotEmpty &&
            support.every((cell) => _sameColumnOrTouch(candidate, cell))) {
          return Deduction(
            technique: DeductionTechnique.directExclusion,
            eliminated: {candidate},
            sources: {candidate, ...support},
            explanation:
                'A crown at $candidate would exclude every cell in row ${row + 1}, so $candidate can be crossed out.',
          );
        }
      }
      for (var column = 0; column < puzzle.size; column++) {
        if (column == candidate.column ||
            placed.any((cell) => cell.column == column)) {
          continue;
        }
        final support =
            candidates.where((cell) => cell.column == column).toSet();
        if (support.isNotEmpty &&
            support.every((cell) => _sameRowOrTouch(candidate, cell))) {
          return Deduction(
            technique: DeductionTechnique.directExclusion,
            eliminated: {candidate},
            sources: {candidate, ...support},
            explanation:
                'A crown at $candidate would exclude every cell in column ${String.fromCharCode(65 + column)}, so $candidate can be crossed out.',
          );
        }
      }
      for (var region = 0; region < puzzle.size; region++) {
        if (region == puzzle.regionAt(candidate) ||
            placed.any((cell) => puzzle.regionAt(cell) == region)) {
          continue;
        }
        final support =
            candidates.where((cell) => puzzle.regionAt(cell) == region).toSet();
        if (support.isNotEmpty &&
            support.every((cell) => _sameUnitOrTouch(candidate, cell))) {
          return Deduction(
            technique: DeductionTechnique.directExclusion,
            eliminated: {candidate},
            sources: {candidate, ...support},
            explanation:
                'A crown at $candidate would directly exclude every cell in region ${region + 1}, so $candidate can be crossed out.',
          );
        }
      }
    }
    return null;
  }

  bool _sameColumnOrTouch(Cell first, Cell second) =>
      first.column == second.column || _touchesDiagonally(first, second);

  bool _sameRowOrTouch(Cell first, Cell second) =>
      first.row == second.row || _touchesDiagonally(first, second);

  bool _sameUnitOrTouch(Cell first, Cell second) =>
      first.row == second.row ||
      first.column == second.column ||
      _touchesDiagonally(first, second);

  bool _touchesDiagonally(Cell first, Cell second) =>
      (first.row - second.row).abs() == 1 &&
      (first.column - second.column).abs() == 1;

  void _apply(
    PuzzleDefinition puzzle,
    Set<Cell> placed,
    Set<Cell> candidates,
    Deduction deduction,
  ) {
    candidates.removeAll(deduction.eliminated);
    final crown = deduction.placement;
    if (crown == null) return;
    placed.add(crown);
    candidates.removeWhere(
      (cell) =>
          cell == crown ||
          cell.row == crown.row ||
          cell.column == crown.column ||
          puzzle.regionAt(cell) == puzzle.regionAt(crown) ||
          ((cell.row - crown.row).abs() == 1 &&
              (cell.column - crown.column).abs() == 1),
    );
  }

  Iterable<List<int>> _combinations(
    List<int> values,
    int width, [
    int start = 0,
    List<int> prefix = const [],
  ]) sync* {
    if (prefix.length == width) {
      yield prefix;
      return;
    }
    for (
      var index = start;
      index <= values.length - (width - prefix.length);
      index++
    ) {
      yield* _combinations(values, width, index + 1, [
        ...prefix,
        values[index],
      ]);
    }
  }
}
