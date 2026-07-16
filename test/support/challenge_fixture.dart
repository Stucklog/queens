import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/core/challenge_generator.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/models.dart';

ChallengePuzzleResult challengeFixtureForSpec(
  AppController controller,
  ChallengeGenerationSpec spec,
) => challengeFixtureFromCatalog(controller.catalog!, spec);

ChallengePuzzleResult challengeFixtureFromCatalog(
  PuzzleCatalog catalog,
  ChallengeGenerationSpec spec,
) {
  final source = catalog.puzzles.firstWhere(
    (puzzle) => puzzle.tier == spec.tier && puzzle.size == spec.size,
  );
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
  final solution = const ExactSolver().solve(puzzle, limit: 1).solutions.single;
  return ChallengePuzzleResult(
    puzzle: puzzle,
    signature: const PuzzleGenerator().diversitySignature(
      puzzle,
      solution,
      familyId: 'fixture-${source.contentHash}',
    ),
  );
}
