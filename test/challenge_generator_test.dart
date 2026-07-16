import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/human_solver.dart';
import 'package:regalia/core/models.dart';

void main() {
  const generator = PuzzleGenerator();
  const exactSolver = ExactSolver();
  const humanSolver = HumanSolver();
  late PuzzleCatalog catalog;

  setUpAll(() async {
    catalog = PuzzleCatalog.fromJsonString(
      await File('assets/puzzles/catalog.json').readAsString(),
    );
  });

  group('calibrated challenge generation', () {
    final cases = <({DifficultyTier tier, int size, int seed})>[
      (tier: DifficultyTier.hard, size: 8, seed: 7301),
      (tier: DifficultyTier.hard, size: 9, seed: 7302),
      (tier: DifficultyTier.expert, size: 9, seed: 7303),
      (tier: DifficultyTier.expert, size: 10, seed: 7304),
    ];

    for (final testCase in cases) {
      test(
        '${testCase.tier.name} ${testCase.size}x${testCase.size} preserves quality and safe hints',
        () {
          final references = _references(catalog, testCase.size);
          final generated = generator.generateChallengeVariant(
            seed: testCase.seed,
            tier: testCase.tier,
            size: testCase.size,
            storyPuzzles: references,
            recentSignatures: const [],
          );
          final puzzle = generated.definition;
          final exact = exactSolver.solve(puzzle, limit: 2);
          final human = humanSolver.analyze(puzzle);
          final storyFingerprints = {
            for (final reference in references)
              generator.canonicalFingerprint(reference),
          };
          final edgeCount = 2 * puzzle.size * (puzzle.size - 1);
          final minimumStoryDistance = max(10, (edgeCount * .10).ceil());

          expect(exact.solutionCount, 1);
          expect(generator.validateRegionQuality(puzzle), isNull);
          expect(human.solved, isTrue);
          expect(human.tier, testCase.tier);
          expect(human.score, puzzle.difficultyScore);
          expect(human.scoringModel, HumanSolver.scoringModel);
          expect(
            storyFingerprints,
            isNot(contains(generated.diversitySignature!.canonicalFingerprint)),
          );
          expect(
            generator.minimumBoundaryDistance(
              puzzle,
              references.map(generator.boundarySignature),
            ),
            greaterThanOrEqualTo(minimumStoryDistance),
          );
          expect(generated.attemptCount, inInclusiveRange(1, 128));

          final solution = exact.solutions.single.toSet();
          final hint = humanSolver.nextDeduction(
            puzzle,
            BoardState(puzzleId: puzzle.id, size: puzzle.size),
          );
          expect(hint, isNotNull);
          expect(hint!.technique.rank, lessThanOrEqualTo(puzzle.tier.index));
          if (hint.placement != null) {
            expect(solution, contains(hint.placement));
          }
          expect(hint.eliminated.intersection(solution), isEmpty);
        },
      );
    }

    test('the same request and context are deterministic', () {
      final references = _references(catalog, 8);
      GeneratedPuzzle generate() => generator.generateChallengeVariant(
        seed: 99117,
        tier: DifficultyTier.hard,
        size: 8,
        storyPuzzles: references,
        recentSignatures: const [],
      );

      final first = generate();
      final second = generate();

      expect(second.definition.toJson(), first.definition.toJson());
      expect(
        second.diversitySignature!.toJson(),
        first.diversitySignature!.toJson(),
      );
      expect(second.solution, first.solution);
      expect(second.attemptCount, first.attemptCount);
    });

    test('diversity signatures round-trip and reject poisoned history', () {
      final puzzle = catalog.puzzles.first;
      final solution = exactSolver.solve(puzzle, limit: 1).solutions.single;
      final signature = generator.diversitySignature(
        puzzle,
        solution,
        familyId: puzzle.contentHash,
      );

      expect(
        PuzzleDiversitySignature.fromJson(signature.toJson()).toJson(),
        signature.toJson(),
      );
      final damagedSolution = Map<String, Object?>.from(signature.toJson())
        ..['solutionKey'] =
            '${puzzle.size}:${List.filled(puzzle.size, 0).join(',')}';
      final damagedFingerprint = Map<String, Object?>.from(signature.toJson())
        ..['canonicalFingerprint'] = '${puzzle.size}:0,1';
      expect(
        () => PuzzleDiversitySignature.fromJson(damagedSolution),
        throwsFormatException,
      );
      expect(
        () => PuzzleDiversitySignature.fromJson(damagedFingerprint),
        throwsFormatException,
      );
    });

    test('recent boards force a different family, shape, and solution', () {
      final references = _references(catalog, 10);
      final first = generator.generateChallengeVariant(
        seed: 12001,
        tier: DifficultyTier.expert,
        size: 10,
        storyPuzzles: references,
        recentSignatures: const [],
      );
      final second = generator.generateChallengeVariant(
        seed: 12002,
        tier: DifficultyTier.expert,
        size: 10,
        storyPuzzles: references,
        recentSignatures: [first.diversitySignature!],
      );
      final edgeCount = 2 * 10 * 9;

      expect(
        second.diversitySignature!.familyId,
        isNot(first.diversitySignature!.familyId),
      );
      expect(
        generator.minimumBoundaryDistance(second.definition, [
          first.diversitySignature!.boundarySignature,
        ]),
        greaterThanOrEqualTo((edgeCount * .15).ceil()),
      );
      expect(
        generator.solutionDistance(
          second.diversitySignature!.solutionKey,
          first.diversitySignature!.solutionKey,
        ),
        greaterThanOrEqualTo(max(3, (10 * .40).ceil())),
      );
      expect(
        second.diversitySignature!.canonicalSolutionKey,
        isNot(first.diversitySignature!.canonicalSolutionKey),
      );
    });

    test('a long fixed-size run cycles families without exhausting them', () {
      const sessionSeed = 21845;
      final references = _references(catalog, 9);
      var recent = <PuzzleDiversitySignature>[];
      final fingerprints = <String>{};
      String? previousFamily;

      for (var number = 1; number <= 16; number++) {
        final generationSeed =
            (sessionSeed +
                number * 104729 +
                DifficultyTier.hard.index * 15485863) &
            0x7fffffff;
        final generated = generator.generateChallengeVariant(
          seed: generationSeed,
          tier: DifficultyTier.hard,
          size: 9,
          storyPuzzles: references,
          recentSignatures: recent,
        );
        final signature = generated.diversitySignature!;

        expect(fingerprints.add(signature.canonicalFingerprint), isTrue);
        expect(signature.familyId, isNot(previousFamily));
        previousFamily = signature.familyId;
        recent = [...recent, signature];
        if (recent.length > 16) recent = recent.sublist(recent.length - 16);
      }

      expect(fingerprints, hasLength(16));
    });
  });
}

List<PuzzleDefinition> _references(PuzzleCatalog catalog, int size) => [
  for (final puzzle in catalog.puzzles)
    if (puzzle.size == size) puzzle,
];
