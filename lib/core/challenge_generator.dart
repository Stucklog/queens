import 'package:flutter/foundation.dart';

import '../app/challenge.dart';
import 'exact_solver.dart';
import 'generator.dart';
import 'models.dart';

class ChallengeGenerationContext {
  const ChallengeGenerationContext({
    required this.storyPuzzles,
    this.recentPuzzles = const [],
    this.recentSignatures = const [],
    this.retrySalt = 0,
  });

  final List<PuzzleDefinition> storyPuzzles;
  final List<PuzzleDefinition> recentPuzzles;
  final List<PuzzleDiversitySignature> recentSignatures;
  final int retrySalt;

  Map<String, Object> toJson() => {
    'storyPuzzles': [for (final puzzle in storyPuzzles) puzzle.toJson()],
    'recentPuzzles': [for (final puzzle in recentPuzzles) puzzle.toJson()],
    'recentSignatures': [
      for (final signature in recentSignatures) signature.toJson(),
    ],
    'retrySalt': retrySalt,
  };

  factory ChallengeGenerationContext.fromJson(Map<String, Object?> json) =>
      ChallengeGenerationContext(
        storyPuzzles: [
          for (final raw in json['storyPuzzles']! as List<Object?>)
            PuzzleDefinition.fromJson(raw! as Map<String, Object?>),
        ],
        recentPuzzles: [
          for (final raw in json['recentPuzzles'] as List<Object?>? ?? const [])
            PuzzleDefinition.fromJson(raw! as Map<String, Object?>),
        ],
        recentSignatures: [
          for (final raw
              in json['recentSignatures'] as List<Object?>? ?? const [])
            PuzzleDiversitySignature.fromJson(raw! as Map<String, Object?>),
        ],
        retrySalt: (json['retrySalt'] as num?)?.toInt() ?? 0,
      );
}

class ChallengePuzzleResult {
  const ChallengePuzzleResult({required this.puzzle, required this.signature});

  final PuzzleDefinition puzzle;
  final PuzzleDiversitySignature signature;

  Map<String, Object> toJson() => {
    'puzzle': puzzle.toJson(),
    'signature': signature.toJson(),
  };

  factory ChallengePuzzleResult.fromJson(Map<String, Object?> json) =>
      ChallengePuzzleResult(
        puzzle: PuzzleDefinition.fromJson(
          json['puzzle']! as Map<String, Object?>,
        ),
        signature: PuzzleDiversitySignature.fromJson(
          json['signature']! as Map<String, Object?>,
        ),
      );
}

typedef ChallengePuzzleFactory =
    Future<ChallengePuzzleResult> Function(
      ChallengeGenerationSpec spec,
      ChallengeGenerationContext context,
    );

Future<ChallengePuzzleResult> generateChallengePuzzle(
  ChallengeGenerationSpec spec,
  ChallengeGenerationContext context,
) async {
  final json = await compute(_generateChallengePuzzle, {
    'spec': spec.toJson(),
    'context': context.toJson(),
  });
  return ChallengePuzzleResult.fromJson(json);
}

Map<String, Object> _generateChallengePuzzle(Map<String, Object> message) {
  final spec = ChallengeGenerationSpec.fromJson(
    message['spec']! as Map<String, Object?>,
  );
  final context = ChallengeGenerationContext.fromJson(
    message['context']! as Map<String, Object?>,
  );
  const generator = PuzzleGenerator();
  const exactSolver = ExactSolver();
  final recentSignatures = List<PuzzleDiversitySignature>.of(
    context.recentSignatures,
  );
  final knownFingerprints = {
    for (final signature in recentSignatures) signature.canonicalFingerprint,
  };
  for (final puzzle in context.recentPuzzles) {
    final fingerprint = generator.canonicalFingerprint(puzzle);
    if (!knownFingerprints.add(fingerprint)) continue;
    final exact = exactSolver.solve(puzzle, limit: 2);
    if (exact.solutionCount != 1) continue;
    recentSignatures.add(
      generator.diversitySignature(
        puzzle,
        exact.solutions.single,
        familyId: 'legacy-${puzzle.contentHash}',
      ),
    );
  }

  final generated = generator.generateChallengeVariant(
    seed: spec.generationSeed,
    tier: spec.tier,
    size: spec.size,
    storyPuzzles: context.storyPuzzles,
    recentSignatures: recentSignatures,
    retrySalt: context.retrySalt,
  );
  final source = generated.definition;
  final puzzle = PuzzleDefinition(
    id: spec.puzzleId,
    order: spec.number,
    size: source.size,
    tier: source.tier,
    regions: source.regions,
    schemaVersion: source.schemaVersion,
    contentHash: source.contentHash,
    difficultyScore: source.difficultyScore,
    scoringModel: source.scoringModel,
  );
  return ChallengePuzzleResult(
    puzzle: puzzle,
    signature: generated.diversitySignature!,
  ).toJson();
}
