import 'package:flutter/foundation.dart';

import '../app/challenge.dart';
import 'generator.dart';
import 'models.dart';

typedef ChallengePuzzleFactory =
    Future<PuzzleDefinition> Function(ChallengeGenerationSpec spec);

Future<PuzzleDefinition> generateChallengePuzzle(
  ChallengeGenerationSpec spec,
) async {
  final json = await compute(_generateChallengePuzzle, spec.toJson());
  return PuzzleDefinition.fromJson(json);
}

Map<String, Object> _generateChallengePuzzle(Map<String, Object> message) {
  final spec = ChallengeGenerationSpec.fromJson(message);
  final generated =
      const PuzzleGenerator()
          .generateCatalog(
            seed: spec.generationSeed,
            plan: [GenerationRequest(spec.tier, spec.size, 1)],
          )
          .single;
  final source = generated.definition;
  return PuzzleDefinition(
    id: spec.puzzleId,
    order: spec.number,
    size: source.size,
    tier: source.tier,
    regions: source.regions,
    schemaVersion: source.schemaVersion,
    contentHash: source.contentHash,
    difficultyScore: source.difficultyScore,
    scoringModel: source.scoringModel,
  ).toJson();
}
