import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/challenge_generator.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('challenge specs are deterministic and use calibrated board sizes', () {
    final first = challengeSpec(
      mode: ChallengeMode.expert,
      sessionSeed: 42,
      number: 3,
    );
    final again = challengeSpec(
      mode: ChallengeMode.expert,
      sessionSeed: 42,
      number: 3,
    );
    expect(first.toJson(), again.toJson());
    expect(first.tier, DifficultyTier.expert);
    expect(first.size, anyOf(9, 10));
    expect(first.puzzleId, 'challenge-2a-00003');

    final mixed = {
      for (var number = 1; number <= 4; number++)
        challengeSpec(
          mode: ChallengeMode.mixed,
          sessionSeed: 12,
          number: number,
        ).tier,
    };
    expect(mixed, DifficultyTier.values.toSet());
  });

  test('default challenge factory generates a unique offline board', () async {
    final spec = challengeSpec(
      mode: ChallengeMode.easy,
      sessionSeed: 77,
      number: 1,
    );
    final puzzle = await generateChallengePuzzle(spec);

    expect(puzzle.id, spec.puzzleId);
    expect(puzzle.order, 1);
    expect(puzzle.tier, DifficultyTier.easy);
    expect(puzzle.size, spec.size);
    expect(const ExactSolver().solve(puzzle, limit: 2).solutionCount, 1);
  });

  test(
    'challenge completion advances its run but not the story frontier',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      late AppController controller;
      controller = AppController(
        challengePuzzleFactory:
            (spec) async => _fixtureForSpec(controller, spec),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      expect(
        await controller.startChallenge(ChallengeMode.easy, seed: 77),
        isTrue,
      );
      await controller.ensureChallengeQueued();
      final session = controller.challengeSession!;
      final puzzle = session.currentPuzzle;
      expect(session.queuedPuzzle, isNotNull);
      expect(controller.frontierPuzzle?.order, 1);
      expect(controller.openChallengePuzzle(), isTrue);

      PuzzleCompletionOutcome? outcome;
      for (final cell
          in const ExactSolver().solve(puzzle, limit: 1).solutions.single) {
        outcome = controller.setCell(puzzle, cell, ManualCellState.crown);
      }

      expect(outcome?.isChallenge, isTrue);
      expect(outcome?.advancedJourney, isFalse);
      expect(controller.challengeSession?.completedCount, 1);
      expect(controller.challengeSession?.cleanCount, 1);
      expect(controller.records, isEmpty);
      expect(controller.frontierPuzzle?.order, 1);

      final next = await controller.advanceChallenge();
      expect(next, isNotNull);
      expect(controller.challengeSession?.currentNumber, 2);
      expect(
        controller.challengeSession?.board.cells,
        everyElement(ManualCellState.empty),
      );
      expect(controller.frontierPuzzle?.order, 1);
    },
  );

  test(
    'challenge board, queue, assistance, and run statistics persist',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      late AppController first;
      first = AppController(
        challengePuzzleFactory: (spec) async => _fixtureForSpec(first, spec),
      );
      await first.initialize();
      await first.startChallenge(ChallengeMode.mixed, seed: 91);
      await first.ensureChallengeQueued();
      final puzzle = first.challengeSession!.currentPuzzle;
      first.setCell(puzzle, const Cell(0, 0), ManualCellState.cross);
      first.checkProgress(puzzle);
      await first.flushPersistence();
      first.dispose();

      late AppController restored;
      restored = AppController(
        challengePuzzleFactory: (spec) async => _fixtureForSpec(restored, spec),
      );
      await restored.initialize();
      addTearDown(restored.dispose);

      final session = restored.challengeSession!;
      expect(session.mode, ChallengeMode.mixed);
      expect(session.seed, 91);
      expect(session.currentNumber, 1);
      expect(session.queuedPuzzle, isNotNull);
      expect(session.board.at(const Cell(0, 0)), ManualCellState.cross);
      expect(session.board.assisted, isTrue);
      expect(session.board.checkCount, 1);
    },
  );

  test(
    'invalid challenge persistence is ignored without touching story',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
        'regalia.challengeSession': '{not valid json',
      });
      final controller = AppController();
      await controller.initialize();
      addTearDown(controller.dispose);

      expect(controller.challengeSession, isNull);
      expect(controller.frontierPuzzle?.order, 1);
    },
  );
}

PuzzleDefinition _fixtureForSpec(
  AppController controller,
  ChallengeGenerationSpec spec,
) {
  final source = controller.catalog!.puzzles.firstWhere(
    (puzzle) => puzzle.tier == spec.tier && puzzle.size == spec.size,
  );
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
  );
}
