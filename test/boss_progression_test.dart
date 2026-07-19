import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/core/rule_engine.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('origin content declares the complete validated boss roster', () async {
    final arc = await _loadOriginArc();
    const expected = [
      ('Starfall Stag', 9, 7, DifficultyTier.easy),
      ('Elderroot Wyrm', 18, 7, DifficultyTier.medium),
      ('Tempest Roc', 27, 8, DifficultyTier.medium),
      ('Abyssal Bellkeeper', 36, 8, DifficultyTier.hard),
      ('Cindermaw Behemoth', 45, 9, DifficultyTier.hard),
      ('Gilded War Colossus', 54, 9, DifficultyTier.expert),
      ('The Sevenfold Wraith', 63, 10, DifficultyTier.expert),
      ('The Hollow Star', 72, 12, DifficultyTier.expert),
    ];

    expect(arc.chapters, hasLength(expected.length));
    for (var index = 0; index < expected.length; index++) {
      final chapter = arc.chapters[index];
      final boss = chapter.boss;
      final puzzle = arc.catalog.byId(boss.puzzleId);
      expect((
        boss.name,
        puzzle.order,
        boss.size,
        boss.targetDifficulty,
      ), expected[index]);
      expect(puzzle.order, chapter.endOrder);
      expect(puzzle.size, boss.size);
      expect(puzzle.tier, boss.targetDifficulty);
      expect(ContentId.isValid(boss.id, kind: 'boss'), isTrue);
      expect(boss.spectacleLevel, index + 1);
      expect(chapter.endOrder - chapter.startOrder + 1, 9);
      expect(chapter.encounters, hasLength(2));
      expect(
        chapter.encounters
            .map((encounter) => arc.catalog.byId(encounter.puzzleId).order)
            .toList(),
        [chapter.startOrder + 2, chapter.startOrder + 5],
      );
      expect(
        chapter.encounters.every(
          (encounter) =>
              !encounter.isBoss &&
              encounter.puzzleId != boss.puzzleId &&
              chapter.contains(arc.catalog.byId(encounter.puzzleId).order),
        ),
        isTrue,
      );
    }
    expect(
      arc.chapters
          .expand((chapter) => chapter.encounters)
          .map((enemy) => enemy.id),
      hasLength(16),
    );
    expect(
      [
        for (final puzzle in arc.catalog.puzzles)
          if (arc.encounterForPuzzle(puzzle) != null) puzzle.order,
      ],
      [for (var order = 3; order <= 72; order += 3) order],
    );
  });

  test(
    'each boss gates the next chapter and the final boss unlocks finale',
    () async {
      SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
      final controller = AppController();
      await controller.initialize();
      final arc = controller.originArc!;
      const solver = ExactSolver();

      for (var index = 0; index < arc.chapters.length; index++) {
        final chapter = arc.chapters[index];
        final bossPuzzle = arc.catalog.byId(chapter.boss.puzzleId);
        for (final puzzle in arc.catalog.puzzles.take(bossPuzzle.order - 1)) {
          controller.records[puzzle.id] = const CompletionRecord(
            status: CompletionStatus.cleanSolved,
          );
        }

        expect(controller.frontierPuzzleFor(arc), bossPuzzle);
        final nextPuzzle =
            index + 1 < arc.chapters.length
                ? arc.catalog.puzzles[bossPuzzle.order]
                : null;
        if (nextPuzzle != null) {
          expect(controller.canOpenPuzzle(nextPuzzle), isFalse);
        } else {
          expect(controller.isFinaleUnlocked(arc.id), isFalse);
        }

        expect(controller.openPuzzle(bossPuzzle), isTrue);
        PuzzleCompletionOutcome? outcome;
        for (final cell
            in solver.solve(bossPuzzle, limit: 1).solutions.single) {
          outcome = controller.setCell(bossPuzzle, cell, ManualCellState.crown);
        }

        expect(outcome?.advancedJourney, isTrue);
        if (nextPuzzle != null) {
          expect(outcome?.enteredChapter, arc.chapters[index + 1]);
          expect(controller.canOpenPuzzle(nextPuzzle), isTrue);
        } else {
          expect(outcome?.isJourneyComplete, isTrue);
          expect(controller.isFinaleUnlocked(arc.id), isTrue);
        }
      }

      await controller.flushPersistence();
      controller.dispose();
      final restored = AppController();
      await restored.initialize();
      addTearDown(restored.dispose);
      final finalBoss = restored.originArc!.catalog.puzzles.last;
      expect(finalBoss.size, 12);
      expect(
        restored.recordFor(finalBoss.id).status,
        CompletionStatus.cleanSolved,
      );
      expect(restored.isFinaleUnlocked(ContentIds.originArc), isTrue);
    },
  );

  test('12x12 final boss board and in-progress state restore intact', () async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final first = AppController();
    await first.initialize();
    final finalBoss = first.originArc!.catalog.puzzles.last;
    expect(finalBoss.size, 12);
    await first.unlockEntireMap(ContentIds.originArc);
    expect(first.openPuzzle(finalBoss), isTrue);
    first.boardFor(finalBoss)
      ..elapsedSeconds = 37
      ..hintCount = 1
      ..assisted = true;
    first.setCell(finalBoss, const Cell(11, 11), ManualCellState.cross);
    await first.flushPersistence();
    first.dispose();

    final restored = AppController();
    await restored.initialize();
    addTearDown(restored.dispose);
    final restoredBoss = restored.originArc!.catalog.puzzles.last;
    final board = restored.boardFor(restoredBoss);
    expect(board.size, 12);
    expect(board.cells, hasLength(144));
    expect(board.at(const Cell(11, 11)), ManualCellState.cross);
    expect(board.elapsedSeconds, 37);
    expect(board.hintCount, 1);
    expect(board.assisted, isTrue);
    expect(restored.lastPuzzleId, restoredBoss.id);
    expect(
      restored.recordFor(restoredBoss.id).status,
      CompletionStatus.inProgress,
    );
  });

  test(
    'catalog upgrade preserves save state for unchanged puzzle IDs',
    () async {
      SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
      final first = AppController();
      await first.initialize();
      final puzzle = first.originArc!.catalog.puzzles.first;
      first.openPuzzle(puzzle);
      first.setCell(puzzle, const Cell(0, 0), ManualCellState.cross);
      await first.flushPersistence();
      first.dispose();

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        SaveIds.originCatalogFingerprint,
        'regalia:arc/origin:previous-catalog',
      );
      final restored = AppController();
      await restored.initialize();
      addTearDown(restored.dispose);
      final restoredPuzzle = restored.originArc!.catalog.puzzles.first;
      expect(restoredPuzzle.id, puzzle.id);
      expect(
        restored.boardFor(restoredPuzzle).at(const Cell(0, 0)),
        ManualCellState.cross,
      );
      expect(
        restored.recordFor(restoredPuzzle.id).status,
        CompletionStatus.inProgress,
      );
    },
  );

  test(
    'map unlock finale toggle defaults off and persists when enabled',
    () async {
      SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
      final disabled = AppController();
      await disabled.initialize();
      await disabled.unlockEntireMap(ContentIds.originArc);
      expect(disabled.fullMapUnlocked, isTrue);
      expect(disabled.isFinaleUnlocked(ContentIds.originArc), isFalse);
      await disabled.flushPersistence();
      disabled.dispose();

      final enabled = AppController(unlockFinaleWithGameBoard: true);
      await enabled.initialize();
      expect(enabled.fullMapUnlocked, isTrue);
      expect(enabled.isFinaleUnlocked(ContentIds.originArc), isFalse);
      await enabled.unlockEntireMap(ContentIds.originArc);
      expect(enabled.fullMapUnlocked, isTrue);
      expect(enabled.isFinaleUnlocked(ContentIds.originArc), isTrue);
      await enabled.flushPersistence();
      enabled.dispose();

      final restored = AppController();
      await restored.initialize();
      addTearDown(restored.dispose);
      expect(restored.isFinaleUnlocked(ContentIds.originArc), isTrue);
    },
  );

  test(
    'the 12x12 finale validates uniquely and completes by the core rules',
    () async {
      final arc = await _loadOriginArc();
      final puzzle = arc.catalog.puzzles.last;
      const solver = ExactSolver();
      const rules = RuleEngine();
      final exact = solver.solve(puzzle, limit: 2);
      expect(exact.solutionCount, 1);
      final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
      for (final cell in exact.solutions.single) {
        board.set(cell, ManualCellState.crown, recordUndo: false);
      }
      expect(rules.isComplete(puzzle, board), isTrue);
      expect(rules.check(puzzle, board).isComplete, isTrue);
    },
  );

  testWidgets('the 12x12 board renders and accepts edge tap and drag input', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final puzzle =
        PuzzleCatalog.fromJsonString(
          File('assets/puzzles/catalog.json').readAsStringSync(),
        ).puzzles.last;
    final board = BoardState(puzzleId: puzzle.id, size: puzzle.size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 360,
              child: RegaliaBoard(
                puzzle: puzzle,
                board: board,
                onCellPressed: board.cycle,
                onCellDragged: (cell, state) => board.set(cell, state),
                onExclusionDragStarted: board.beginBatch,
                onExclusionDragEnded: board.endBatch,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('cell-0-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('cell-11-11')), findsOneWidget);
    final boardRect = tester.getRect(find.byType(RegaliaBoard));
    Offset center(Cell cell) => Offset(
      boardRect.left + (cell.column + .5) * boardRect.width / puzzle.size,
      boardRect.top + (cell.row + .5) * boardRect.height / puzzle.size,
    );
    await tester.tapAt(center(const Cell(11, 11)));
    expect(board.at(const Cell(11, 11)), ManualCellState.cross);

    final gesture = await tester.startGesture(center(const Cell(0, 0)));
    await gesture.moveTo(center(const Cell(11, 0)));
    await gesture.up();
    await tester.pump();
    expect(board.at(const Cell(0, 0)), ManualCellState.cross);
    expect(board.at(const Cell(11, 0)), ManualCellState.cross);
  });
}

Future<StoryArc> _loadOriginArc() async {
  final registry = await ContentRepository(
    readAsset: (path) => File(path).readAsString(),
  ).load(
    manifestAsset: 'assets/content/manifest.json',
    policy: const ContentEntitlementPolicy.web(),
  );
  return registry.arc(ContentIds.originArc)!;
}
