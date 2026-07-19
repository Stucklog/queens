import 'dart:math';

import 'exact_solver.dart';
import 'human_solver.dart';
import 'models.dart';
import 'rule_engine.dart';

class GenerationRequest {
  const GenerationRequest(
    this.tier,
    this.size,
    this.count, {
    this.puzzleId,
    this.reserveTierOrdinal = false,
  }) : assert(puzzleId == null || count == 1);

  final DifficultyTier tier;
  final int size;
  final int count;
  final String? puzzleId;

  /// Bosses use named IDs. Same-tier bosses reserve the ordinary numeric ID
  /// they replace so later regular puzzle IDs retain their published order.
  final bool reserveTierOrdinal;
}

/// Required size/difficulty allocation for the bundled 120-puzzle catalog.
const launchPlan = <GenerationRequest>[
  GenerationRequest(DifficultyTier.easy, 6, 19),
  GenerationRequest(DifficultyTier.easy, 7, 10),
  GenerationRequest(DifficultyTier.medium, 7, 10),
  GenerationRequest(DifficultyTier.medium, 8, 20),
  GenerationRequest(DifficultyTier.hard, 8, 20),
  GenerationRequest(DifficultyTier.hard, 9, 10),
  GenerationRequest(DifficultyTier.expert, 9, 10),
  GenerationRequest(DifficultyTier.expert, 10, 20),
  GenerationRequest(DifficultyTier.expert, 12, 1),
];

/// Story-ordered generation plan. Boss slots sit at each chapter boundary.
const originStoryGenerationPlan = <GenerationRequest>[
  GenerationRequest(DifficultyTier.easy, 6, 19),
  GenerationRequest(
    DifficultyTier.easy,
    7,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/starfall-stag',
    reserveTierOrdinal: true,
  ),
  GenerationRequest(DifficultyTier.easy, 7, 9),
  GenerationRequest(
    DifficultyTier.medium,
    7,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/elderroot-wyrm',
  ),
  GenerationRequest(DifficultyTier.medium, 7, 9),
  GenerationRequest(
    DifficultyTier.medium,
    8,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/tempest-roc',
    reserveTierOrdinal: true,
  ),
  GenerationRequest(DifficultyTier.medium, 8, 19),
  GenerationRequest(
    DifficultyTier.hard,
    8,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/abyssal-bellkeeper',
  ),
  GenerationRequest(DifficultyTier.hard, 8, 19),
  GenerationRequest(
    DifficultyTier.hard,
    9,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/cindermaw-behemoth',
    reserveTierOrdinal: true,
  ),
  GenerationRequest(DifficultyTier.hard, 9, 9),
  GenerationRequest(
    DifficultyTier.expert,
    9,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/gilded-war-colossus',
  ),
  GenerationRequest(DifficultyTier.expert, 9, 9),
  GenerationRequest(
    DifficultyTier.expert,
    10,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/sevenfold-wraith',
    reserveTierOrdinal: true,
  ),
  GenerationRequest(DifficultyTier.expert, 10, 19),
  GenerationRequest(
    DifficultyTier.expert,
    12,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/hollow-star',
  ),
];

const originBossGenerationPlan = <GenerationRequest>[
  GenerationRequest(
    DifficultyTier.easy,
    7,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/starfall-stag',
  ),
  GenerationRequest(
    DifficultyTier.medium,
    7,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/elderroot-wyrm',
  ),
  GenerationRequest(
    DifficultyTier.medium,
    8,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/tempest-roc',
  ),
  GenerationRequest(
    DifficultyTier.hard,
    8,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/abyssal-bellkeeper',
  ),
  GenerationRequest(
    DifficultyTier.hard,
    9,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/cindermaw-behemoth',
  ),
  GenerationRequest(
    DifficultyTier.expert,
    9,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/gilded-war-colossus',
  ),
  GenerationRequest(
    DifficultyTier.expert,
    10,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/sevenfold-wraith',
  ),
  GenerationRequest(
    DifficultyTier.expert,
    12,
    1,
    puzzleId: 'regalia:puzzle/origin/boss/hollow-star',
  ),
];

class GeneratedPuzzle {
  const GeneratedPuzzle(
    this.definition,
    this.solution,
    this.exact,
    this.human,
    this.generationScore,
    this.seed, {
    this.diversitySignature,
    this.attemptCount = 1,
  });
  final PuzzleDefinition definition;
  final List<Cell> solution;
  final ExactSolveResult exact;
  final DifficultyReport human;
  final GenerationScore generationScore;
  final int seed;
  final PuzzleDiversitySignature? diversitySignature;
  final int attemptCount;
}

class PuzzleDiversitySignature {
  const PuzzleDiversitySignature({
    required this.size,
    required this.canonicalFingerprint,
    required this.boundarySignature,
    required this.solutionKey,
    required this.canonicalSolutionKey,
    required this.familyId,
  });

  final int size;
  final String canonicalFingerprint;
  final String boundarySignature;
  final String solutionKey;
  final String canonicalSolutionKey;
  final String familyId;

  Map<String, Object> toJson() => {
    'size': size,
    'canonicalFingerprint': canonicalFingerprint,
    'boundarySignature': boundarySignature,
    'solutionKey': solutionKey,
    'canonicalSolutionKey': canonicalSolutionKey,
    'familyId': familyId,
  };

  factory PuzzleDiversitySignature.fromJson(Map<String, Object?> json) {
    final size = (json['size']! as num).toInt();
    final boundarySignature = json['boundarySignature']! as String;
    final solutionKey = json['solutionKey']! as String;
    final canonicalSolutionKey = json['canonicalSolutionKey']! as String;
    final canonicalFingerprint = json['canonicalFingerprint']! as String;
    final familyId = json['familyId']! as String;
    if (size < 1 ||
        boundarySignature.length != 2 * size * (size - 1) ||
        !RegExp(r'^[01]+$').hasMatch(boundarySignature) ||
        !_validSolutionKey(size, solutionKey) ||
        !_validSolutionKey(size, canonicalSolutionKey) ||
        !_validFingerprint(size, canonicalFingerprint) ||
        familyId.isEmpty) {
      throw const FormatException('Invalid puzzle diversity signature');
    }
    return PuzzleDiversitySignature(
      size: size,
      canonicalFingerprint: canonicalFingerprint,
      boundarySignature: boundarySignature,
      solutionKey: solutionKey,
      canonicalSolutionKey: canonicalSolutionKey,
      familyId: familyId,
    );
  }

  static bool _validSolutionKey(int size, String key) {
    if (!key.startsWith('$size:')) return false;
    final values =
        key
            .substring(key.indexOf(':') + 1)
            .split(',')
            .map(int.tryParse)
            .toList();
    if (values.length != size || values.any((value) => value == null)) {
      return false;
    }
    final columns = values.cast<int>();
    if (columns.any((value) => value < 0 || value >= size) ||
        columns.toSet().length != size) {
      return false;
    }
    for (var row = 1; row < size; row++) {
      if ((columns[row] - columns[row - 1]).abs() <= 1) return false;
    }
    return true;
  }

  static bool _validFingerprint(int size, String fingerprint) {
    if (!fingerprint.startsWith('$size:')) return false;
    final values =
        fingerprint
            .substring(fingerprint.indexOf(':') + 1)
            .split(',')
            .map(int.tryParse)
            .toList();
    return values.length == size * size &&
        values.every((value) => value != null && value >= 0 && value < size) &&
        values.whereType<int>().toSet().length == size;
  }
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
    final solutionLayouts = <String>{};
    final tierNumbers = <DifficultyTier, int>{};
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
          if (attempt > 0 && attempt % 300 == 0) {
            // Some crown layouts cannot be shaped into every requested human
            // tier. Restart periodically instead of cloning a previously
            // accepted puzzle for the rest of the band.
            workingBaseByBand.remove(bandKey);
          }
          final working = workingBaseByBand[bandKey];
          final base =
              working == null
                  ? null
                  : (grid: working.grid, solution: working.solution);
          late final List<Cell> solution;
          late final List<List<int>> regions;
          ExactSolveResult? constructionExact;
          if (base == null) {
            solution = _generateCrownLayout(request.size, random);
            if (solutionLayouts.contains(solutionKey(request.size, solution))) {
              diagnostics['duplicate crown layout'] =
                  (diagnostics['duplicate crown layout'] ?? 0) + 1;
              continue;
            }
            regions = _growRegions(request.size, solution, random);
            _mutateBoundaries(regions, solution, random);
            constructionExact = _eliminateAlternativeSolutions(
              regions,
              solution,
              random,
            );
            if (constructionExact == null) {
              diagnostics['could not isolate solution'] =
                  (diagnostics['could not isolate solution'] ?? 0) + 1;
              continue;
            }
          } else {
            solution = List.of(base.solution);
            regions = [for (final row in base.grid) List.of(row)];
            constructionExact = _mutateUniqueVariant(
              regions,
              solution,
              random,
              2 + attempt % request.size,
            );
            if (constructionExact == null) {
              diagnostics['variant mutation failed'] =
                  (diagnostics['variant mutation failed'] ?? 0) + 1;
              continue;
            }
          }
          final number = (tierNumbers[request.tier] ?? 0) + 1;
          final id =
              request.puzzleId ??
              'regalia:puzzle/origin/${request.tier.name}-${number.toString().padLeft(3, '0')}';
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
          final exact = constructionExact;
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
          final solvedLayoutKey = solutionKey(
            request.size,
            exact.solutions.single,
          );
          if (solutionLayouts.contains(solvedLayoutKey)) {
            diagnostics['duplicate crown layout'] =
                (diagnostics['duplicate crown layout'] ?? 0) + 1;
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
          solutionLayouts.add(solvedLayoutKey);
          if (request.puzzleId == null || request.reserveTierOrdinal) {
            tierNumbers[request.tier] = number;
          }
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

  GeneratedPuzzle generateChallengeVariant({
    required int seed,
    required DifficultyTier tier,
    required int size,
    required List<PuzzleDefinition> storyPuzzles,
    required List<PuzzleDiversitySignature> recentSignatures,
    int retrySalt = 0,
    int maxAttempts = 128,
  }) {
    final starters =
        storyPuzzles
            .where((puzzle) => puzzle.tier == tier && puzzle.size == size)
            .toList();
    final references =
        storyPuzzles.where((puzzle) => puzzle.size == size).toList();
    if (starters.isEmpty || references.isEmpty) {
      throw StateError('No calibrated $tier ${size}x$size challenge bases');
    }

    final recent =
        recentSignatures.where((signature) => signature.size == size).toList();
    final storyFingerprints = {
      for (final puzzle in references) canonicalFingerprint(puzzle),
    };
    final storyBoundaries = [
      for (final puzzle in references) boundarySignature(puzzle),
    ];
    final recentFingerprints = {
      for (final signature in recent) signature.canonicalFingerprint,
    };
    final recentBoundaries = [
      for (final signature in recent) signature.boundarySignature,
    ];
    final starterSolutions = <String, List<Cell>>{};
    final starterCanonicalSolutions = <String, String>{};
    final storySolutionKeys = <String>[];
    final starterHashes = {for (final starter in starters) starter.contentHash};
    for (final reference in references) {
      final exact = exactSolver.solve(reference, limit: 2);
      if (exact.solutionCount != 1) {
        throw StateError('${reference.id} is not a unique calibrated base');
      }
      final solution = exact.solutions.single;
      storySolutionKeys.add(solutionKey(size, solution));
      if (starterHashes.contains(reference.contentHash)) {
        starterSolutions[reference.contentHash] = solution;
        starterCanonicalSolutions[reference.contentHash] = canonicalSolutionKey(
          size,
          solution,
        );
      }
    }

    // Boundary mutations deliberately retain a calibrated base solution. A
    // permanent ban on reusing those finite solution families would make an
    // endless run impossible after 9–20 boards, depending on the band. Keep a
    // strong LRU cooldown while always leaving at least one family available.
    final availableCanonicalSolutions =
        starterCanonicalSolutions.values.toSet();
    final solutionCooldownLimit = min(
      8,
      max(0, availableCanonicalSolutions.length - 1),
    );
    final solutionCooldown = <PuzzleDiversitySignature>[];
    final cooldownCanonicalSolutions = <String>{};
    if (solutionCooldownLimit > 0) {
      for (final signature in recent.reversed) {
        if (!availableCanonicalSolutions.contains(
              signature.canonicalSolutionKey,
            ) ||
            !cooldownCanonicalSolutions.add(signature.canonicalSolutionKey)) {
          continue;
        }
        solutionCooldown.add(signature);
        if (solutionCooldown.length == solutionCooldownLimit) break;
      }
    }
    final recentSolutionKeys = [
      for (final signature in solutionCooldown) signature.solutionKey,
    ];
    final recentFamilies =
        recent.map((signature) => signature.familyId).toSet();
    var basePool =
        starters
            .where(
              (puzzle) =>
                  !recentFamilies.contains(puzzle.contentHash) &&
                  !cooldownCanonicalSolutions.contains(
                    starterCanonicalSolutions[puzzle.contentHash],
                  ),
            )
            .toList();
    if (basePool.isEmpty) {
      basePool =
          starters
              .where(
                (puzzle) =>
                    !cooldownCanonicalSolutions.contains(
                      starterCanonicalSolutions[puzzle.contentHash],
                    ),
              )
              .toList();
    }
    if (basePool.isEmpty) basePool = List.of(starters);
    basePool.shuffle(Random(seed ^ (retrySalt * 104729)));

    final edgeCount = 2 * size * (size - 1);
    final minimumStoryBoundaryDistance = max(10, (edgeCount * .10).ceil());
    final minimumRecentBoundaryDistance = (edgeCount * .15).ceil();
    final minimumSolutionDistance = max(3, (size * .40).ceil());
    final diagnostics = <String, int>{};

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final candidateSeed =
          seed + retrySalt * 32452843 + (attempt + 1) * 15485863 + size * 8191;
      final random = Random(candidateSeed);
      final starter = basePool[attempt % basePool.length];
      final transform = random.nextInt(8);
      final transformed = _transformPuzzle(starter, transform);
      final intended = [
        for (final cell in starterSolutions[starter.contentHash]!)
          _transformCell(cell, size, transform),
      ]..sort();
      final regions = List.generate(
        size,
        (row) => transformed.regions.sublist(row * size, (row + 1) * size),
      );

      final exact = _mutateUniqueVariant(
        regions,
        intended,
        random,
        max(4, minimumStoryBoundaryDistance ~/ 2 + attempt % 3),
        requireAllChanges: true,
        deferExactCheck: size == 12,
      );
      if (exact == null) {
        diagnostics['could not retain unique solution'] =
            (diagnostics['could not retain unique solution'] ?? 0) + 1;
        continue;
      }

      final flat = regions.expand((row) => row).toList();
      final definition = PuzzleDefinition(
        id: 'regalia:puzzle/system/challenge-candidate',
        order: 0,
        size: size,
        tier: tier,
        regions: flat,
        schemaVersion: 2,
        contentHash: PuzzleDefinition.stableHash(size, flat),
        difficultyScore: tier.bandStart,
        scoringModel: HumanSolver.scoringModel,
      );
      final quality = validateRegionQuality(definition);
      if (quality != null) {
        diagnostics[quality] = (diagnostics[quality] ?? 0) + 1;
        continue;
      }

      final fingerprint = canonicalFingerprint(definition);
      if (storyFingerprints.contains(fingerprint) ||
          recentFingerprints.contains(fingerprint)) {
        diagnostics['canonical duplicate'] =
            (diagnostics['canonical duplicate'] ?? 0) + 1;
        continue;
      }
      final storyBoundaryDistance = minimumBoundaryDistance(
        definition,
        storyBoundaries,
      );
      if (storyBoundaryDistance < minimumStoryBoundaryDistance) {
        diagnostics['too close to story'] =
            (diagnostics['too close to story'] ?? 0) + 1;
        continue;
      }
      final recentBoundaryDistance = minimumBoundaryDistance(
        definition,
        recentBoundaries,
      );
      if (recentBoundaryDistance < minimumRecentBoundaryDistance) {
        diagnostics['too close to recent challenge'] =
            (diagnostics['too close to recent challenge'] ?? 0) + 1;
        continue;
      }

      final solved = exact.solutions.single;
      final solvedKey = solutionKey(size, solved);
      if (storySolutionKeys.any(
            (other) =>
                solutionDistance(solvedKey, other) < minimumSolutionDistance,
          ) ||
          recentSolutionKeys.any(
            (other) =>
                solutionDistance(solvedKey, other) < minimumSolutionDistance,
          )) {
        diagnostics['repeated crown layout'] =
            (diagnostics['repeated crown layout'] ?? 0) + 1;
        continue;
      }
      final canonicalSolvedKey = canonicalSolutionKey(size, solved);
      if (cooldownCanonicalSolutions.contains(canonicalSolvedKey)) {
        diagnostics['symmetric crown duplicate'] =
            (diagnostics['symmetric crown duplicate'] ?? 0) + 1;
        continue;
      }

      final human = humanSolver.analyze(definition);
      if (!human.solved || human.tier != tier) {
        final key =
            human.solved ? 'difficulty ${human.tier.name}' : 'not explainable';
        diagnostics[key] = (diagnostics[key] ?? 0) + 1;
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
        scoringModel: HumanSolver.scoringModel,
      );
      final noveltyDistance = min(
        storyBoundaryDistance,
        recentBoundaries.isEmpty ? edgeCount : recentBoundaryDistance,
      );
      final generationScore = GenerationScore(
        uniqueness: 100,
        difficultyFit: 100,
        visualBalance: _visualBalanceScore(scoredDefinition),
        novelty: (noveltyDistance * 100 / edgeCount).round(),
      );
      final signature = PuzzleDiversitySignature(
        size: size,
        canonicalFingerprint: fingerprint,
        boundarySignature: boundarySignature(scoredDefinition),
        solutionKey: solvedKey,
        canonicalSolutionKey: canonicalSolvedKey,
        familyId: starter.contentHash,
      );
      return GeneratedPuzzle(
        scoredDefinition,
        solved,
        exact,
        human,
        generationScore,
        candidateSeed,
        diversitySignature: signature,
        attemptCount: attempt + 1,
      );
    }

    throw StateError(
      'Unable to generate a diverse ${tier.label} ${size}x$size challenge '
      'after $maxAttempts attempts. Rejections: $diagnostics',
    );
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
    Random random, {
    int? mutationCount,
  }) {
    final size = grid.length;
    final protected = solution.toSet();
    // Repeated connectivity-preserving mutations explore nearby boundary shapes
    // before uniqueness is scored.
    for (var mutation = 0; mutation < (mutationCount ?? size * 2); mutation++) {
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

  ExactSolveResult? _eliminateAlternativeSolutions(
    List<List<int>> grid,
    List<Cell> intended,
    Random random,
  ) {
    final size = grid.length;
    final protected = intended.toSet();
    for (var round = 0; round < size * size * 3; round++) {
      final flat = grid.expand((row) => row).toList();
      final puzzle = PuzzleDefinition(
        id: 'regalia:puzzle/system/generation-candidate',
        order: 0,
        size: size,
        tier: DifficultyTier.easy,
        regions: flat,
        schemaVersion: 2,
        contentHash: PuzzleDefinition.stableHash(size, flat),
        difficultyScore: 0,
      );
      final result = exactSolver.solve(
        puzzle,
        limit: 2,
        nodeLimit: size >= 12 ? 100000 : null,
      );
      if (!result.searchComplete) return null;
      if (result.solutionCount == 1) {
        return result.solutions.single.toSet().containsAll(intended)
            ? result
            : null;
      }
      if (result.solutionCount == 0) return null;
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
      if (!changed) return null;
    }
    return null;
  }

  ExactSolveResult? _mutateUniqueVariant(
    List<List<int>> grid,
    List<Cell> solution,
    Random random,
    int desiredChanges, {
    bool requireAllChanges = false,
    bool deferExactCheck = false,
  }) {
    final size = grid.length;
    final protected = solution.toSet();
    var changes = 0;
    ExactSolveResult? latestExact;
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
          id: 'regalia:puzzle/system/generation-variant',
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
          if (deferExactCheck) {
            changes++;
            break;
          }
          final result = exactSolver.solve(
            definition,
            limit: 2,
            nodeLimit: size >= 12 ? 100000 : null,
          );
          if (!result.searchComplete) {
            grid[cell.row][cell.column] = oldRegion;
            continue;
          }
          if (result.solutionCount == 1 &&
              result.solutions.single.toSet().containsAll(solution)) {
            changes++;
            latestExact = result;
            break;
          }
        }
        grid[cell.row][cell.column] = oldRegion;
      }
    }
    if (changes == 0 || (requireAllChanges && changes < desiredChanges)) {
      return null;
    }
    if (!deferExactCheck) return latestExact;

    // Large boards make checking uniqueness after every boundary move
    // needlessly expensive. The intended crown cells are protected above, so
    // they remain a valid solution; verify uniqueness once after the complete
    // batch instead.
    final flat = grid.expand((row) => row).toList();
    final definition = PuzzleDefinition(
      id: 'regalia:puzzle/system/generation-variant',
      order: 0,
      size: size,
      tier: DifficultyTier.easy,
      regions: flat,
      schemaVersion: 2,
      contentHash: PuzzleDefinition.stableHash(size, flat),
      difficultyScore: 0,
    );
    final result = exactSolver.solve(definition, limit: 2, nodeLimit: 100000);
    return result.searchComplete &&
            result.solutionCount == 1 &&
            result.solutions.single.toSet().containsAll(solution)
        ? result
        : null;
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

  String boundarySignature(PuzzleDefinition puzzle) {
    final bits = StringBuffer();
    for (var row = 0; row < puzzle.size; row++) {
      for (var column = 0; column + 1 < puzzle.size; column++) {
        bits.write(
          puzzle.regionAt(Cell(row, column)) ==
                  puzzle.regionAt(Cell(row, column + 1))
              ? '0'
              : '1',
        );
      }
    }
    for (var row = 0; row + 1 < puzzle.size; row++) {
      for (var column = 0; column < puzzle.size; column++) {
        bits.write(
          puzzle.regionAt(Cell(row, column)) ==
                  puzzle.regionAt(Cell(row + 1, column))
              ? '0'
              : '1',
        );
      }
    }
    return bits.toString();
  }

  int minimumBoundaryDistance(
    PuzzleDefinition puzzle,
    Iterable<String> referenceSignatures,
  ) {
    final references = referenceSignatures.toList();
    final edgeCount = 2 * puzzle.size * (puzzle.size - 1);
    if (references.isEmpty) return edgeCount;
    var minimum = edgeCount;
    for (var transform = 0; transform < 8; transform++) {
      final candidate = boundarySignature(_transformPuzzle(puzzle, transform));
      for (final reference in references) {
        if (reference.length != edgeCount) continue;
        var distance = 0;
        for (var index = 0; index < edgeCount; index++) {
          if (candidate.codeUnitAt(index) != reference.codeUnitAt(index)) {
            distance++;
          }
        }
        if (distance < minimum) minimum = distance;
      }
    }
    return minimum;
  }

  String solutionKey(int size, Iterable<Cell> solution) {
    final byRow = List.filled(size, -1);
    for (final cell in solution) {
      byRow[cell.row] = cell.column;
    }
    return '$size:${byRow.join(',')}';
  }

  String canonicalSolutionKey(int size, Iterable<Cell> solution) {
    final values = <String>[];
    for (var transform = 0; transform < 8; transform++) {
      values.add(
        solutionKey(
          size,
          solution.map((cell) => _transformCell(cell, size, transform)),
        ),
      );
    }
    values.sort();
    return values.first;
  }

  int solutionDistance(String first, String second) {
    final firstSeparator = first.indexOf(':');
    final secondSeparator = second.indexOf(':');
    if (firstSeparator < 0 || secondSeparator < 0) return 1 << 30;
    final firstSize = int.tryParse(first.substring(0, firstSeparator));
    final secondSize = int.tryParse(second.substring(0, secondSeparator));
    if (firstSize == null || firstSize != secondSize) return 1 << 30;
    final firstValues = first.substring(firstSeparator + 1).split(',');
    final secondValues = second.substring(secondSeparator + 1).split(',');
    if (firstValues.length != firstSize || secondValues.length != firstSize) {
      return 1 << 30;
    }
    var distance = 0;
    for (var index = 0; index < firstSize; index++) {
      if (firstValues[index] != secondValues[index]) distance++;
    }
    return distance;
  }

  PuzzleDiversitySignature diversitySignature(
    PuzzleDefinition puzzle,
    Iterable<Cell> solution, {
    required String familyId,
  }) => PuzzleDiversitySignature(
    size: puzzle.size,
    canonicalFingerprint: canonicalFingerprint(puzzle),
    boundarySignature: boundarySignature(puzzle),
    solutionKey: solutionKey(puzzle.size, solution),
    canonicalSolutionKey: canonicalSolutionKey(puzzle.size, solution),
    familyId: familyId,
  );

  PuzzleDefinition _transformPuzzle(PuzzleDefinition puzzle, int transform) {
    final regions = List.filled(puzzle.size * puzzle.size, 0);
    for (final cell in puzzle.cells) {
      final target = _transformCell(cell, puzzle.size, transform);
      regions[target.index(puzzle.size)] = puzzle.regionAt(cell);
    }
    return PuzzleDefinition(
      id: puzzle.id,
      order: puzzle.order,
      size: puzzle.size,
      tier: puzzle.tier,
      regions: regions,
      schemaVersion: puzzle.schemaVersion,
      contentHash: PuzzleDefinition.stableHash(puzzle.size, regions),
      difficultyScore: puzzle.difficultyScore,
      scoringModel: puzzle.scoringModel,
    );
  }

  Cell _transformCell(Cell cell, int size, int transform) {
    var row = cell.row;
    var column = transform >= 4 ? size - 1 - cell.column : cell.column;
    for (var turn = 0; turn < transform % 4; turn++) {
      final nextRow = column;
      column = size - 1 - row;
      row = nextRow;
    }
    return Cell(row, column);
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
