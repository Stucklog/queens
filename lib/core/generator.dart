import 'dart:math';

import 'exact_solver.dart';
import 'human_solver.dart';
import 'models.dart';
import 'rule_engine.dart';

class GenerationRequest {
  const GenerationRequest(this.tier, this.size, this.count);
  final DifficultyTier tier;
  final int size;
  final int count;
}

const launchPlan = <GenerationRequest>[
  GenerationRequest(DifficultyTier.easy, 6, 20),
  GenerationRequest(DifficultyTier.easy, 7, 10),
  GenerationRequest(DifficultyTier.medium, 7, 10),
  GenerationRequest(DifficultyTier.medium, 8, 20),
  GenerationRequest(DifficultyTier.hard, 8, 20),
  GenerationRequest(DifficultyTier.hard, 9, 10),
  GenerationRequest(DifficultyTier.expert, 9, 10),
  GenerationRequest(DifficultyTier.expert, 10, 20),
];

class GeneratedPuzzle {
  const GeneratedPuzzle(
    this.definition,
    this.solution,
    this.exact,
    this.human,
    this.generationScore,
    this.seed,
  );
  final PuzzleDefinition definition;
  final List<Cell> solution;
  final ExactSolveResult exact;
  final DifficultyReport human;
  final GenerationScore generationScore;
  final int seed;
}

class GenerationScore {
  const GenerationScore({
    required this.uniqueness,
    required this.difficultyFit,
    required this.visualBalance,
    required this.novelty,
  });

  final int uniqueness;
  final int difficultyFit;
  final int visualBalance;
  final int novelty;

  int get total =>
      uniqueness * 4 + difficultyFit * 3 + visualBalance * 2 + novelty;

  Map<String, int> toJson() => {
    'uniqueness': uniqueness,
    'difficultyFit': difficultyFit,
    'visualBalance': visualBalance,
    'novelty': novelty,
    'total': total,
  };
}

class PuzzleGenerator {
  const PuzzleGenerator({
    this.exactSolver = const ExactSolver(),
    this.humanSolver = const HumanSolver(),
  });
  final ExactSolver exactSolver;
  final HumanSolver humanSolver;

  List<GeneratedPuzzle> generateCatalog({
    int seed = 20260714,
    List<GenerationRequest> plan = launchPlan,
    int maxAttemptsPerPuzzle = 5000,
  }) {
    final output = <GeneratedPuzzle>[];
    final fingerprints = <String>{};
    final tierNumbers = <DifficultyTier, int>{};
    final baseByBand =
        <
          ({int size, DifficultyTier tier}),
          ({List<List<int>> grid, List<Cell> solution})
        >{};
    final latestBaseBySize =
        <int, ({List<List<int>> grid, List<Cell> solution})>{};
    final workingBaseByBand =
        <
          ({int size, DifficultyTier tier}),
          ({
            List<List<int>> grid,
            List<Cell> solution,
            int distance,
            int directionPenalty,
            int score,
          })
        >{};
    var sequence = 0;
    for (final request in plan) {
      for (var index = 0; index < request.count; index++) {
        sequence++;
        GeneratedPuzzle? accepted;
        final diagnostics = <String, int>{};
        for (var attempt = 0; attempt < maxAttemptsPerPuzzle; attempt++) {
          final candidateSeed =
              seed +
              sequence * 104729 +
              attempt * 15485863 +
              request.size * 8191;
          final random = Random(candidateSeed);
          final bandKey = (size: request.size, tier: request.tier);
          final working = workingBaseByBand[bandKey];
          final base =
              baseByBand[bandKey] ??
              (working == null
                  ? latestBaseBySize[request.size]
                  : (grid: working.grid, solution: working.solution));
          late final List<Cell> solution;
          late final List<List<int>> regions;
          if (base == null) {
            solution = _generateCrownLayout(request.size, random);
            regions = _growRegions(request.size, solution, random);
            _mutateBoundaries(regions, solution, random);
            if (!_eliminateAlternativeSolutions(regions, solution, random)) {
              diagnostics['could not isolate solution'] =
                  (diagnostics['could not isolate solution'] ?? 0) + 1;
              continue;
            }
          } else {
            solution = List.of(base.solution);
            regions = [for (final row in base.grid) List.of(row)];
            if (!_mutateUniqueVariant(
              regions,
              solution,
              random,
              2 + attempt % request.size,
            )) {
              diagnostics['variant mutation failed'] =
                  (diagnostics['variant mutation failed'] ?? 0) + 1;
              continue;
            }
          }
          final number = (tierNumbers[request.tier] ?? 0) + 1;
          final id =
              'regalia-${request.tier.name}-${number.toString().padLeft(3, '0')}';
          final definition = PuzzleDefinition(
            id: id,
            order: sequence,
            size: request.size,
            tier: request.tier,
            regions: regions.expand((row) => row).toList(),
            schemaVersion: 2,
            contentHash: PuzzleDefinition.stableHash(
              request.size,
              regions.expand((row) => row).toList(),
            ),
            difficultyScore:
                request.tier.bandStart + ((index * 23 + request.size * 3) % 25),
            scoringModel: HumanSolver.scoringModel,
          );
          final quality = validateRegionQuality(definition);
          if (quality != null) {
            diagnostics[quality] = (diagnostics[quality] ?? 0) + 1;
            continue;
          }
          final fingerprint = canonicalFingerprint(definition);
          if (fingerprints.contains(fingerprint)) {
            diagnostics['canonical duplicate'] =
                (diagnostics['canonical duplicate'] ?? 0) + 1;
            continue;
          }
          final exact = exactSolver.solve(definition, limit: 2);
          if (exact.solutionCount != 1 ||
              exact.solutions.single
                  .toSet()
                  .difference(solution.toSet())
                  .isNotEmpty) {
            diagnostics['not uniquely solved by generated layout'] =
                (diagnostics['not uniquely solved by generated layout'] ?? 0) +
                1;
            continue;
          }
          final human = humanSolver.analyze(definition);
          if (!human.solved) {
            diagnostics['not explainable'] =
                (diagnostics['not explainable'] ?? 0) + 1;
            continue;
          }
          final generationScore = GenerationScore(
            uniqueness: 100,
            difficultyFit: (100 -
                    (human.tier.index - request.tier.index).abs() * 30)
                .clamp(0, 100),
            visualBalance: _visualBalanceScore(definition),
            novelty: _noveltyScore(fingerprint, fingerprints, request.size),
          );
          if (human.tier != request.tier) {
            final key = 'difficulty ${human.tier.name}';
            diagnostics[key] = (diagnostics[key] ?? 0) + 1;
            final distance = (human.tier.index - request.tier.index).abs();
            final directionPenalty =
                human.tier.index > request.tier.index ? 1 : 0;
            if (working == null || distance <= working.distance) {
              workingBaseByBand[bandKey] = (
                grid: List.generate(
                  request.size,
                  (row) => definition.regions.sublist(
                    row * request.size,
                    (row + 1) * request.size,
                  ),
                ),
                solution: List.of(exact.solutions.single),
                distance: distance,
                directionPenalty: directionPenalty,
                score: generationScore.total,
              );
            }
            continue;
          }
          if (generationScore.novelty < 4) {
            diagnostics['low novelty'] = (diagnostics['low novelty'] ?? 0) + 1;
            continue;
          }
          final scoredDefinition = PuzzleDefinition(
            id: definition.id,
            order: definition.order,
            size: definition.size,
            tier: definition.tier,
            regions: definition.regions,
            schemaVersion: definition.schemaVersion,
            contentHash: definition.contentHash,
            difficultyScore: human.score,
            scoringModel: definition.scoringModel,
          );
          accepted = GeneratedPuzzle(
            scoredDefinition,
            exact.solutions.single,
            exact,
            human,
            generationScore,
            candidateSeed,
          );
          fingerprints.add(fingerprint);
          tierNumbers[request.tier] = number;
          final acceptedBase = (
            grid: List.generate(
              request.size,
              (row) => scoredDefinition.regions.sublist(
                row * request.size,
                (row + 1) * request.size,
              ),
            ),
            solution: List.of(exact.solutions.single),
          );
          baseByBand[bandKey] = acceptedBase;
          latestBaseBySize[request.size] = acceptedBase;
          workingBaseByBand.remove(bandKey);
          break;
        }
        if (accepted == null) {
          throw StateError(
            'Unable to fill ${request.tier.label} ${request.size}x${request.size} slot ${index + 1}/${request.count}. '
            'Rejections: $diagnostics',
          );
        }
        output.add(accepted);
      }
    }
    return output;
  }

  List<Cell> _generateCrownLayout(int size, Random random) {
    final columns = List.generate(size, (index) => index)..shuffle(random);
    bool search(int row) {
      if (row == size) return true;
      final choices = List.generate(size, (index) => index)..shuffle(random);
      for (final column in choices) {
        if (columns.take(row).contains(column)) continue;
        if (row > 0 && (columns[row - 1] - column).abs() <= 1) continue;
        columns[row] = column;
        if (search(row + 1)) return true;
      }
      return false;
    }

    if (!search(0)) throw StateError('No legal crown layout for $size');
    return [for (var row = 0; row < size; row++) Cell(row, columns[row])];
  }

  List<List<int>> _growRegions(int size, List<Cell> solution, Random random) {
    final grid = List.generate(size, (_) => List.filled(size, -1));
    final counts = List.filled(size, 1);
    for (var region = 0; region < size; region++) {
      grid[solution[region].row][solution[region].column] = region;
    }
    var remaining = size * size - size;
    while (remaining > 0) {
      final frontier = <Cell>[];
      for (var row = 0; row < size; row++) {
        for (var column = 0; column < size; column++) {
          if (grid[row][column] == -1 &&
              _neighbors(
                Cell(row, column),
                size,
              ).any((cell) => grid[cell.row][cell.column] >= 0)) {
            frontier.add(Cell(row, column));
          }
        }
      }
      final cell = frontier[random.nextInt(frontier.length)];
      final adjacent =
          _neighbors(cell, size)
              .map((neighbor) => grid[neighbor.row][neighbor.column])
              .where((id) => id >= 0)
              .toSet();
      final minimum = adjacent.map((id) => counts[id]).reduce(min);
      var balanced =
          adjacent
              .where((id) => counts[id] <= minimum + 1 && counts[id] < size * 2)
              .toList();
      if (balanced.isEmpty) {
        balanced = adjacent.where((id) => counts[id] == minimum).toList();
      }
      final region = balanced[random.nextInt(balanced.length)];
      grid[cell.row][cell.column] = region;
      counts[region]++;
      remaining--;
    }
    return grid;
  }

  void _mutateBoundaries(
    List<List<int>> grid,
    List<Cell> solution,
    Random random,
  ) {
    final size = grid.length;
    final protected = solution.toSet();
    // Repeated connectivity-preserving mutations explore nearby boundary shapes
    // before uniqueness is scored.
    for (var mutation = 0; mutation < size * 2; mutation++) {
      final candidates = <Cell>[];
      for (var row = 0; row < size; row++) {
        for (var column = 0; column < size; column++) {
          final cell = Cell(row, column);
          if (!protected.contains(cell) &&
              _neighbors(cell, size).any(
                (neighbor) =>
                    grid[neighbor.row][neighbor.column] != grid[row][column],
              )) {
            candidates.add(cell);
          }
        }
      }
      if (candidates.isEmpty) return;
      final cell = candidates[random.nextInt(candidates.length)];
      final oldRegion = grid[cell.row][cell.column];
      final targets =
          _neighbors(cell, size)
              .map((neighbor) => grid[neighbor.row][neighbor.column])
              .where((id) => id != oldRegion)
              .toSet()
              .toList();
      if (targets.isEmpty) continue;
      final target = targets[random.nextInt(targets.length)];
      grid[cell.row][cell.column] = target;
      if (!_regionConnected(grid, oldRegion) ||
          !_regionConnected(grid, target)) {
        grid[cell.row][cell.column] = oldRegion;
      }
    }
  }

  bool _eliminateAlternativeSolutions(
    List<List<int>> grid,
    List<Cell> intended,
    Random random,
  ) {
    final size = grid.length;
    final protected = intended.toSet();
    for (var round = 0; round < size * size * 3; round++) {
      final flat = grid.expand((row) => row).toList();
      final puzzle = PuzzleDefinition(
        id: 'candidate',
        order: 0,
        size: size,
        tier: DifficultyTier.easy,
        regions: flat,
        schemaVersion: 2,
        contentHash: PuzzleDefinition.stableHash(size, flat),
        difficultyScore: 0,
      );
      final result = exactSolver.solve(puzzle, limit: 2);
      if (result.solutionCount == 1) {
        return result.solutions.single.toSet().containsAll(intended);
      }
      if (result.solutionCount == 0) return false;
      final alternative =
          result.solutions.first.toSet().containsAll(intended)
              ? result.solutions.last
              : result.solutions.first;
      final regionsUsed =
          alternative.map((cell) => grid[cell.row][cell.column]).toList();
      final moves = <(Cell, int)>[];
      for (final cell in alternative) {
        if (protected.contains(cell)) continue;
        final oldRegion = grid[cell.row][cell.column];
        for (final target
            in _neighbors(
              cell,
              size,
            ).map((neighbor) => grid[neighbor.row][neighbor.column]).toSet()) {
          if (target != oldRegion &&
              regionsUsed.where((region) => region == target).isNotEmpty) {
            moves.add((cell, target));
          }
        }
      }
      moves.shuffle(random);
      var changed = false;
      for (final move in moves) {
        final cell = move.$1;
        final oldRegion = grid[cell.row][cell.column];
        grid[cell.row][cell.column] = move.$2;
        final oldCount =
            grid
                .expand((row) => row)
                .where((region) => region == oldRegion)
                .length;
        final newCount =
            grid
                .expand((row) => row)
                .where((region) => region == move.$2)
                .length;
        if (oldCount >= 2 &&
            newCount <= size * 2 &&
            _regionConnected(grid, oldRegion) &&
            _regionConnected(grid, move.$2)) {
          changed = true;
          break;
        }
        grid[cell.row][cell.column] = oldRegion;
      }
      if (!changed) return false;
    }
    return false;
  }

  bool _mutateUniqueVariant(
    List<List<int>> grid,
    List<Cell> solution,
    Random random,
    int desiredChanges,
  ) {
    final size = grid.length;
    final protected = solution.toSet();
    var changes = 0;
    for (
      var attempt = 0;
      attempt < size * size * 8 && changes < desiredChanges;
      attempt++
    ) {
      final boundary = <Cell>[];
      for (var row = 0; row < size; row++) {
        for (var column = 0; column < size; column++) {
          final cell = Cell(row, column);
          if (!protected.contains(cell) &&
              _neighbors(cell, size).any(
                (neighbor) =>
                    grid[neighbor.row][neighbor.column] != grid[row][column],
              )) {
            boundary.add(cell);
          }
        }
      }
      if (boundary.isEmpty) break;
      final cell = boundary[random.nextInt(boundary.length)];
      final oldRegion = grid[cell.row][cell.column];
      final targets =
          _neighbors(cell, size)
              .map((neighbor) => grid[neighbor.row][neighbor.column])
              .where((region) => region != oldRegion)
              .toSet()
              .toList()
            ..shuffle(random);
      for (final target in targets) {
        grid[cell.row][cell.column] = target;
        final flat = grid.expand((row) => row).toList();
        final definition = PuzzleDefinition(
          id: 'variant',
          order: 0,
          size: size,
          tier: DifficultyTier.easy,
          regions: flat,
          schemaVersion: 2,
          contentHash: PuzzleDefinition.stableHash(size, flat),
          difficultyScore: 0,
        );
        final oldCount = flat.where((region) => region == oldRegion).length;
        final targetCount = flat.where((region) => region == target).length;
        if (oldCount >= 2 &&
            targetCount <= size * 2 &&
            _regionConnected(grid, oldRegion) &&
            _regionConnected(grid, target) &&
            !_hasHole(definition)) {
          final result = exactSolver.solve(definition, limit: 2);
          if (result.solutionCount == 1 &&
              result.solutions.single.toSet().containsAll(solution)) {
            changes++;
            break;
          }
        }
        grid[cell.row][cell.column] = oldRegion;
      }
    }
    return changes > 0;
  }

  String? validateRegionQuality(PuzzleDefinition puzzle) {
    final engine = RuleEngine(exactSolver: exactSolver);
    if (!engine.regionsAreConnected(puzzle)) return 'disconnected region';
    for (var region = 0; region < puzzle.size; region++) {
      final count = puzzle.regions.where((value) => value == region).length;
      if (count < 2) return 'single-cell region';
      if (count > puzzle.size * 2) return 'oversized region';
    }
    if (_hasHole(puzzle)) return 'region hole';
    return null;
  }

  bool _hasHole(PuzzleDefinition puzzle) {
    for (var region = 0; region < puzzle.size; region++) {
      final outside = <Cell>{};
      final queue = <Cell>[];
      for (final cell in puzzle.cells) {
        if (puzzle.regionAt(cell) == region) continue;
        if (cell.row == 0 ||
            cell.column == 0 ||
            cell.row == puzzle.size - 1 ||
            cell.column == puzzle.size - 1) {
          if (outside.add(cell)) queue.add(cell);
        }
      }
      while (queue.isNotEmpty) {
        final cell = queue.removeLast();
        for (final neighbor in _neighbors(cell, puzzle.size)) {
          if (puzzle.regionAt(neighbor) != region && outside.add(neighbor)) {
            queue.add(neighbor);
          }
        }
      }
      if (puzzle.cells.any(
        (cell) => puzzle.regionAt(cell) != region && !outside.contains(cell),
      )) {
        return true;
      }
    }
    return false;
  }

  bool _regionConnected(List<List<int>> grid, int region) {
    final size = grid.length;
    final cells = <Cell>{
      for (var row = 0; row < size; row++)
        for (var column = 0; column < size; column++)
          if (grid[row][column] == region) Cell(row, column),
    };
    if (cells.isEmpty) return false;
    final reached = <Cell>{cells.first};
    final queue = <Cell>[cells.first];
    while (queue.isNotEmpty) {
      for (final neighbor in _neighbors(queue.removeLast(), size)) {
        if (cells.contains(neighbor) && reached.add(neighbor)) {
          queue.add(neighbor);
        }
      }
    }
    return reached.length == cells.length;
  }

  String canonicalFingerprint(PuzzleDefinition puzzle) {
    final grids = <List<int>>[];
    List<int> transform(bool reflect, int rotations) {
      final output = List.filled(puzzle.size * puzzle.size, 0);
      for (final cell in puzzle.cells) {
        var row = cell.row;
        var column = reflect ? puzzle.size - 1 - cell.column : cell.column;
        for (var turn = 0; turn < rotations; turn++) {
          final nextRow = column;
          column = puzzle.size - 1 - row;
          row = nextRow;
        }
        output[row * puzzle.size + column] = puzzle.regionAt(cell);
      }
      return output;
    }

    for (final reflected in [false, true]) {
      for (var rotations = 0; rotations < 4; rotations++) {
        grids.add(_normalizeLabels(transform(reflected, rotations)));
      }
    }
    final values = grids.map((grid) => grid.join(',')).toList()..sort();
    return '${puzzle.size}:${values.first}';
  }

  int _visualBalanceScore(PuzzleDefinition puzzle) {
    final average = puzzle.size;
    final deviation = [
      for (var region = 0; region < puzzle.size; region++)
        (puzzle.regions.where((value) => value == region).length - average)
            .abs(),
    ].fold<int>(0, (sum, value) => sum + value);
    return (100 - (deviation * 100 / (puzzle.size * puzzle.size)).round())
        .clamp(0, 100);
  }

  int _noveltyScore(String fingerprint, Set<String> accepted, int size) {
    final peers = accepted.where((value) => value.startsWith('$size:'));
    if (peers.isEmpty) return 100;
    final candidate = fingerprint
        .substring(fingerprint.indexOf(':') + 1)
        .split(',');
    var minimumDistance = size * size;
    for (final peer in peers) {
      final values = peer.substring(peer.indexOf(':') + 1).split(',');
      var distance = 0;
      for (var index = 0; index < candidate.length; index++) {
        if (candidate[index] != values[index]) distance++;
      }
      if (distance < minimumDistance) minimumDistance = distance;
    }
    return (minimumDistance * 100 / (size * size)).round();
  }

  List<int> _normalizeLabels(List<int> values) {
    final labels = <int, int>{};
    var next = 0;
    return [
      for (final value in values) labels.putIfAbsent(value, () => next++),
    ];
  }

  Iterable<Cell> _neighbors(Cell cell, int size) sync* {
    if (cell.row > 0) yield Cell(cell.row - 1, cell.column);
    if (cell.row + 1 < size) yield Cell(cell.row + 1, cell.column);
    if (cell.column > 0) yield Cell(cell.row, cell.column - 1);
    if (cell.column + 1 < size) yield Cell(cell.row, cell.column + 1);
  }
}
