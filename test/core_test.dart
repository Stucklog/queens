import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/human_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/core/rule_engine.dart';

void main() {
  group('Queens rules', () {
    final puzzle = PuzzleDefinition(
      id: 'fixture',
      order: 1,
      size: 4,
      tier: DifficultyTier.easy,
      regions: [for (var row = 0; row < 4; row++) ...List.filled(4, row)],
      schemaVersion: 2,
      contentHash: PuzzleDefinition.stableHash(4, [
        for (var row = 0; row < 4; row++) ...List.filled(4, row),
      ]),
      difficultyScore: 0,
    );
    const rules = RuleEngine();

    test('only touching diagonal crowns conflict', () {
      final board =
          BoardState(puzzleId: puzzle.id, size: 4)
            ..set(const Cell(0, 0), ManualCellState.crown)
            ..set(const Cell(2, 2), ManualCellState.crown);
      expect(
        rules.directConflicts(puzzle, board),
        isEmpty,
        reason: 'non-adjacent diagonal alignment is allowed',
      );
      board.set(const Cell(2, 2), ManualCellState.empty);
      board.set(const Cell(1, 1), ManualCellState.crown);
      expect(
        rules.directConflicts(puzzle, board).single.reason,
        contains('diagonally'),
      );
    });

    test('row, column, and region conflicts are explained separately', () {
      BoardState board =
          BoardState(puzzleId: puzzle.id, size: 4)
            ..set(const Cell(0, 0), ManualCellState.crown)
            ..set(const Cell(0, 2), ManualCellState.crown);
      expect(
        rules.directConflicts(puzzle, board).single.reason,
        contains('row'),
      );

      board =
          BoardState(puzzleId: puzzle.id, size: 4)
            ..set(const Cell(0, 0), ManualCellState.crown)
            ..set(const Cell(2, 0), ManualCellState.crown);
      expect(
        rules.directConflicts(puzzle, board).single.reason,
        contains('column'),
      );

      final regionPuzzle = PuzzleDefinition(
        id: 'region-fixture',
        order: 1,
        size: 4,
        tier: DifficultyTier.easy,
        regions: [
          for (var row = 0; row < 4; row++)
            for (var column = 0; column < 4; column++) (row + column) % 4,
        ],
        schemaVersion: 2,
        contentHash: PuzzleDefinition.stableHash(4, [
          for (var row = 0; row < 4; row++)
            for (var column = 0; column < 4; column++) (row + column) % 4,
        ]),
        difficultyScore: 0,
      );
      board =
          BoardState(puzzleId: regionPuzzle.id, size: 4)
            ..set(const Cell(0, 0), ManualCellState.crown)
            ..set(const Cell(2, 2), ManualCellState.crown);
      expect(
        rules.directConflicts(regionPuzzle, board).single.reason,
        contains('region'),
      );
    });

    test(
      'automatic exclusions include row, column, region, and touching diagonals',
      () {
        final board = BoardState(puzzleId: puzzle.id, size: 4)
          ..set(const Cell(1, 2), ManualCellState.crown);
        final exclusions = rules.automaticExclusions(puzzle, board);
        expect(
          exclusions,
          containsAll(const [
            Cell(1, 0),
            Cell(0, 2),
            Cell(1, 3),
            Cell(0, 1),
            Cell(2, 3),
          ]),
        );
        expect(exclusions, isNot(contains(const Cell(3, 0))));
      },
    );
  });

  test('manual cell state cycles and undo/redo preserve assistance', () {
    final board = BoardState(puzzleId: 'test', size: 4);
    const cell = Cell(1, 1);
    board.cycle(cell);
    expect(board.at(cell), ManualCellState.cross);
    board.cycle(cell);
    expect(board.at(cell), ManualCellState.crown);
    board.assisted = true;
    expect(board.undo(), isTrue);
    expect(board.at(cell), ManualCellState.cross);
    expect(board.assisted, isTrue);
    expect(board.redo(), isTrue);
    expect(board.at(cell), ManualCellState.crown);
  });

  test('completion records allow a clean replay upgrade', () {
    var record = const CompletionRecord(
      status: CompletionStatus.inProgress,
      attemptCount: 1,
    );
    record = record.complete(assisted: true, seconds: 90);
    expect(record.status, CompletionStatus.assistedSolved);
    record = record.complete(assisted: false, seconds: 120);
    expect(record.status, CompletionStatus.cleanSolved);
    expect(record.bestAssistedSeconds, 90);
    expect(record.bestCleanSeconds, 120);
  });

  test('version-one numeric board cells migrate on restore', () {
    final restored = BoardState.fromJson({
      'puzzleId': 'legacy',
      'size': 2,
      'cells': [0, 1, 2, 0],
      'elapsedSeconds': 12,
    });
    expect(restored.cells, [
      ManualCellState.empty,
      ManualCellState.cross,
      ManualCellState.crown,
      ManualCellState.empty,
    ]);
    expect(restored.elapsedSeconds, 12);
  });

  test('version-one numeric completion status migrates on restore', () {
    final restored = CompletionRecord.fromJson({
      'status': 2,
      'bestAssistedSeconds': 45,
      'attemptCount': 3,
    });
    expect(restored.status, CompletionStatus.assistedSolved);
    expect(restored.bestAssistedSeconds, 45);
    expect(restored.attemptCount, 3);
  });

  test('reset is undoable while clearing the whole board', () {
    final board =
        BoardState(puzzleId: 'test', size: 4)
          ..set(const Cell(0, 0), ManualCellState.crown)
          ..set(const Cell(2, 3), ManualCellState.cross);
    board.reset();
    expect(board.cells, everyElement(ManualCellState.empty));
    expect(board.undo(), isTrue);
    expect(board.at(const Cell(0, 0)), ManualCellState.crown);
    expect(board.at(const Cell(2, 3)), ManualCellState.cross);
  });

  group('bundled catalog', () {
    late PuzzleCatalog catalog;
    late PuzzleDefinition tutorial;

    setUpAll(() async {
      catalog = PuzzleCatalog.fromJsonString(
        await File('assets/puzzles/catalog.json').readAsString(),
      );
      tutorial = PuzzleDefinition.fromJson(
        jsonDecode(await File('assets/puzzles/tutorial.json').readAsString())
            as Map<String, Object?>,
      );
    });

    test('guided tutorial is valid, unique, and separate from the 120', () {
      expect(tutorial.id, 'regalia:puzzle/system/guided-tutorial');
      expect(
        catalog.puzzles.map((puzzle) => puzzle.id),
        isNot(contains(tutorial.id)),
      );
      expect(const ExactSolver().solve(tutorial, limit: 2).solutionCount, 1);
      expect(const HumanSolver().analyze(tutorial).tier, DifficultyTier.easy);
      final fingerprints =
          catalog.puzzles
              .map(const PuzzleGenerator().canonicalFingerprint)
              .toSet();
      expect(
        fingerprints,
        isNot(contains(const PuzzleGenerator().canonicalFingerprint(tutorial))),
      );
    });

    test('contains the exact launch allocation', () {
      expect(catalog.puzzles, hasLength(120));
      for (final request in launchPlan) {
        expect(
          catalog.puzzles.where(
            (puzzle) =>
                puzzle.tier == request.tier && puzzle.size == request.size,
          ),
          hasLength(request.count),
        );
      }
    });

    test('curated hand-rated fixtures stay in their expected bands', () async {
      final fixtures =
          jsonDecode(
                await File(
                  'test/fixtures/difficulty_fixtures.json',
                ).readAsString(),
              )
              as List<Object?>;
      for (final raw in fixtures) {
        final fixture = raw! as Map<String, Object?>;
        final puzzle = catalog.byId(fixture['id']! as String);
        final expected = DifficultyTierLabel.parse(
          fixture['expectedTier']! as String,
        );
        final report = const HumanSolver().analyze(puzzle);
        expect(report.tier, expected, reason: fixture['ratingNote']! as String);
        expect(
          report.score,
          inInclusiveRange(expected.bandStart, expected.bandStart + 24),
        );
      }
    });

    test(
      'shipped entries omit solutions and private generation data',
      () async {
        final source = await File('assets/puzzles/catalog.json').readAsString();
        expect(source, isNot(contains('"solution"')));
        expect(source, isNot(contains('"seed"')));
        expect(source, isNot(contains('"trace"')));
      },
    );

    test(
      'development report retains solutions, traces, and quality scores',
      () async {
        final report =
            jsonDecode(await File('tool/validation_report.json').readAsString())
                as Map<String, Object?>;
        final entries = report['puzzles']! as List<Object?>;
        expect(entries, hasLength(120));
        final solutionLayouts = <String>{};
        for (final raw in entries) {
          final entry = raw! as Map<String, Object?>;
          final puzzle = catalog.byId(entry['id']! as String);
          final solution = entry['solution']! as List<Object?>;
          expect(solution, hasLength(puzzle.size));
          final columnsByRow = List.filled(puzzle.size, -1);
          for (final rawCell in solution) {
            final cell = rawCell! as Map<String, Object?>;
            columnsByRow[(cell['row']! as num).toInt()] =
                (cell['column']! as num).toInt();
          }
          expect(
            solutionLayouts.add('${puzzle.size}:${columnsByRow.join(',')}'),
            isTrue,
            reason: '${puzzle.id} repeats a crown layout',
          );
          final human = entry['human']! as Map<String, Object?>;
          expect(human['deductions']! as List<Object?>, isNotEmpty);
          final score = entry['generationScore']! as Map<String, Object?>;
          expect((score['novelty']! as num).toInt(), greaterThanOrEqualTo(4));
          expect(
            (score['visualBalance']! as num).toInt(),
            inInclusiveRange(0, 100),
          );
        }
      },
    );

    test(
      'every puzzle is connected, unique, explainable, and symmetry-distinct',
      () {
        const exact = ExactSolver();
        const generator = PuzzleGenerator();
        const human = HumanSolver();
        final fingerprints = <String>{};
        final techniques = <DeductionTechnique>{};
        for (final puzzle in catalog.puzzles) {
          expect(
            generator.validateRegionQuality(puzzle),
            isNull,
            reason: puzzle.id,
          );
          expect(
            exact.solve(puzzle, limit: 2).solutionCount,
            1,
            reason: puzzle.id,
          );
          final report = human.analyze(puzzle);
          expect(report.solved, isTrue, reason: puzzle.id);
          expect(report.tier, puzzle.tier, reason: puzzle.id);
          expect(report.score, puzzle.difficultyScore, reason: puzzle.id);
          expect(report.scoringModel, HumanSolver.scoringModel);
          techniques.addAll(report.trace.map((step) => step.technique));
          expect(
            fingerprints.add(generator.canonicalFingerprint(puzzle)),
            isTrue,
            reason: puzzle.id,
          );
        }
        expect(techniques, containsAll(DeductionTechnique.values));
      },
    );

    test('a wrong cross produces a minimal one-mark contradiction', () {
      final puzzle = catalog.puzzles.first;
      final solution =
          const ExactSolver().solve(puzzle, limit: 1).solutions.single;
      final board = BoardState(puzzleId: puzzle.id, size: puzzle.size)
        ..set(solution.first, ManualCellState.cross);
      final progress = const RuleEngine().check(puzzle, board);
      expect(progress.isValid, isFalse);
      expect(progress.conflicts, isEmpty);
      expect(progress.inconsistentMarks, {solution.first});
      expect(progress.message, contains('prevents every valid completion'));
    });

    test('canonical fingerprint matches a rotated relabeling', () {
      final puzzle = catalog.puzzles.first;
      final rotated = List.filled(puzzle.size * puzzle.size, 0);
      for (final cell in puzzle.cells) {
        final row = cell.column;
        final column = puzzle.size - 1 - cell.row;
        rotated[row * puzzle.size + column] = puzzle.regionAt(cell) + 10;
      }
      final labels = <int, int>{};
      var next = 0;
      final normalized = [
        for (final value in rotated) labels.putIfAbsent(value, () => next++),
      ];
      final transformed = PuzzleDefinition(
        id: 'rotated',
        order: 0,
        size: puzzle.size,
        tier: puzzle.tier,
        regions: normalized,
        schemaVersion: 2,
        contentHash: PuzzleDefinition.stableHash(puzzle.size, normalized),
        difficultyScore: puzzle.difficultyScore,
        scoringModel: puzzle.scoringModel,
      );
      const generator = PuzzleGenerator();
      expect(
        generator.canonicalFingerprint(transformed),
        generator.canonicalFingerprint(puzzle),
      );
    });

    test('deterministic generation reproduces a fixture', () {
      const request = [GenerationRequest(DifficultyTier.easy, 6, 1)];
      final first =
          const PuzzleGenerator()
              .generateCatalog(seed: 77, plan: request)
              .single;
      final second =
          const PuzzleGenerator()
              .generateCatalog(seed: 77, plan: request)
              .single;
      expect(first.definition.regions, second.definition.regions);
      expect(first.solution, second.solution);
      expect(first.definition.contentHash, second.definition.contentHash);
    });
  });
}
