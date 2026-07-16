import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/challenge_generator.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/challenge_fixture.dart';

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
    final catalog = PuzzleCatalog.fromJsonString(
      await File('assets/puzzles/catalog.json').readAsString(),
    );
    final result = await generateChallengePuzzle(
      spec,
      ChallengeGenerationContext(
        storyPuzzles: [
          for (final puzzle in catalog.puzzles)
            if (puzzle.size == spec.size) puzzle,
        ],
      ),
    );
    final puzzle = result.puzzle;

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
            (spec, _) async => challengeFixtureForSpec(controller, spec),
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
        challengePuzzleFactory:
            (spec, _) async => challengeFixtureForSpec(first, spec),
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
        challengePuzzleFactory:
            (spec, _) async => challengeFixtureForSpec(restored, spec),
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

  test(
    'schema v1 challenge state migrates with its queued board intact',
    () async {
      final catalog = PuzzleCatalog.fromJsonString(
        await File('assets/puzzles/catalog.json').readAsString(),
      );
      const seed = 771;
      final currentSpec = challengeSpec(
        mode: ChallengeMode.easy,
        sessionSeed: seed,
        number: 1,
      );
      final queuedSpec = challengeSpec(
        mode: ChallengeMode.easy,
        sessionSeed: seed,
        number: 2,
      );
      final current = challengeFixtureFromCatalog(catalog, currentSpec).puzzle;
      final queued = challengeFixtureFromCatalog(catalog, queuedSpec).puzzle;
      final board = BoardState(
        puzzleId: current.id,
        size: current.size,
        elapsedSeconds: 37,
        hintCount: 2,
        checkCount: 1,
        assisted: true,
      )..set(const Cell(0, 0), ManualCellState.cross, recordUndo: false);
      final stored = <String, Object?>{
        'schemaVersion': 1,
        'seed': seed,
        'mode': ChallengeMode.easy.name,
        'currentNumber': 1,
        'currentPuzzle': current.toJson(),
        'board': board.toJson(),
        'completedCount': 4,
        'cleanCount': 3,
        'assistedCount': 1,
        'currentCompleted': true,
        'queuedPuzzle': queued.toJson(),
      };
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
        'regalia.challengeSession': jsonEncode(stored),
      });
      late AppController controller;
      controller = AppController(
        challengePuzzleFactory:
            (spec, _) async => challengeFixtureForSpec(controller, spec),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      final migrated = controller.challengeSession!;
      expect(
        migrated.toJson()['schemaVersion'],
        ChallengeSession.schemaVersion,
      );
      expect(migrated.currentPuzzle.id, current.id);
      expect(migrated.queuedPuzzle?.id, queued.id);
      expect(migrated.board.at(const Cell(0, 0)), ManualCellState.cross);
      expect(migrated.board.elapsedSeconds, 37);
      expect(migrated.board.hintCount, 2);
      expect(migrated.board.checkCount, 1);
      expect(migrated.board.assisted, isTrue);
      expect(migrated.currentCompleted, isTrue);
      expect(migrated.completedCount, 4);
      expect(migrated.cleanCount, 3);
      expect(migrated.assistedCount, 1);
    },
  );

  test(
    'the preparation queue is serial, bounded, and retained on advance',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      late AppController controller;
      final requested = <int>[];
      var activeFactories = 0;
      var maximumFactories = 0;
      controller = AppController(
        challengePuzzleFactory: (spec, _) async {
          requested.add(spec.number);
          activeFactories++;
          if (activeFactories > maximumFactories) {
            maximumFactories = activeFactories;
          }
          try {
            await Future<void>.delayed(const Duration(milliseconds: 2));
            return challengeFixtureForSpec(controller, spec);
          } finally {
            activeFactories--;
          }
        },
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      expect(
        await controller.startChallenge(ChallengeMode.hard, seed: 7101),
        isTrue,
      );
      await _eventually(
        () =>
            controller.challengeSession?.preparedPuzzles.length ==
            ChallengeSession.preparedCapacity,
      );
      expect(
        controller.challengeSession!.preparedPuzzles.map(
          (puzzle) => puzzle.order,
        ),
        [2, 3],
      );
      expect(requested.take(3), [1, 2, 3]);
      expect(maximumFactories, 1);

      final current = controller.challengeSession!.currentPuzzle;
      for (final cell
          in const ExactSolver().solve(current, limit: 1).solutions.single) {
        controller.setCell(current, cell, ManualCellState.crown);
      }
      expect(controller.challengeSession?.currentCompleted, isTrue);
      expect((await controller.advanceChallenge())?.order, 2);
      expect(controller.challengeSession?.currentNumber, 2);
      expect(controller.challengeSession!.preparedPuzzles.first.order, 3);

      await _eventually(
        () =>
            controller.challengeSession?.preparedPuzzles.length ==
            ChallengeSession.preparedCapacity,
      );
      expect(
        controller.challengeSession!.preparedPuzzles.map(
          (puzzle) => puzzle.order,
        ),
        [3, 4],
      );
      expect(requested.take(4), [1, 2, 3, 4]);
      expect(maximumFactories, 1);
    },
  );

  test(
    'abandoning an in-flight first board cannot resurrect the run',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      final generation = Completer<ChallengePuzzleResult>();
      late ChallengeGenerationSpec requested;
      late AppController controller;
      controller = AppController(
        challengePuzzleFactory: (spec, _) {
          requested = spec;
          return generation.future;
        },
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      final starting = controller.startChallenge(
        ChallengeMode.expert,
        seed: 88,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.isStartingChallenge, isTrue);
      await controller.abandonChallenge();
      generation.complete(challengeFixtureForSpec(controller, requested));

      expect(await starting, isFalse);
      expect(controller.challengeSession, isNull);
      expect(controller.isStartingChallenge, isFalse);
    },
  );

  test(
    'a failed deterministic request resumes with a persisted retry salt',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      final first = AppController(
        challengePuzzleFactory:
            (_, _) async => throw StateError('bounded generation failed'),
      );
      await first.initialize();
      expect(
        await first.startChallenge(ChallengeMode.expert, seed: 5150),
        isFalse,
      );
      await first.flushPersistence();
      first.dispose();

      ChallengeGenerationContext? restoredContext;
      late AppController restored;
      restored = AppController(
        challengePuzzleFactory: (spec, context) async {
          restoredContext ??= context;
          return challengeFixtureForSpec(restored, spec);
        },
      );
      await restored.initialize();
      addTearDown(restored.dispose);

      expect(
        await restored.startChallenge(ChallengeMode.expert, seed: 5150),
        isTrue,
      );
      expect(restoredContext?.retrySalt, 1);
    },
  );

  test(
    'diversity history survives ending a run and stays bounded per size',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      final contexts = <ChallengeGenerationContext>[];
      late AppController first;
      first = AppController(
        challengePuzzleFactory: (spec, context) async {
          contexts.add(context);
          return challengeFixtureForSpec(first, spec);
        },
      );
      await first.initialize();
      expect(await first.startChallenge(ChallengeMode.easy, seed: 141), isTrue);
      final remembered = first.challengeSession!.recentSignatures.first;
      await first.abandonChallenge();
      await first.flushPersistence();
      first.dispose();

      late AppController restored;
      restored = AppController(
        challengePuzzleFactory: (spec, context) async {
          contexts.add(context);
          return challengeFixtureForSpec(restored, spec);
        },
      );
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(
        await restored.startChallenge(ChallengeMode.easy, seed: 140),
        isTrue,
      );
      final newRunContext = contexts.lastWhere(
        (context) =>
            context.storyPuzzles.first.size ==
            challengeSpec(
              mode: ChallengeMode.easy,
              sessionSeed: 140,
              number: 1,
            ).size,
      );
      expect(
        newRunContext.recentSignatures.map(
          (signature) => signature.canonicalFingerprint,
        ),
        contains(remembered.canonicalFingerprint),
      );

      var history = const <PuzzleDiversitySignature>[];
      for (var size = 6; size <= 7; size++) {
        for (var index = 0; index < 18; index++) {
          history = ChallengeSession.rememberSignature(
            history,
            _fakeSignature(size, index),
          );
        }
      }
      expect(history.where((signature) => signature.size == 6), hasLength(16));
      expect(history.where((signature) => signature.size == 7), hasLength(16));
    },
  );
}

Future<void> _eventually(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not reached');
}

PuzzleDiversitySignature _fakeSignature(int size, int index) {
  final boundary = List.filled(2 * size * (size - 1), '0').join();
  final columns = List.generate(size, (column) => column).join(',');
  return PuzzleDiversitySignature(
    size: size,
    canonicalFingerprint: '$size:fake-$index',
    boundarySignature: boundary,
    solutionKey: '$size:$columns',
    canonicalSolutionKey: '$size:$columns',
    familyId: 'family-$size-$index',
  );
}
