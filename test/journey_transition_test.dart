import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/widgets/support_developer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('chapter boundary opens the new location with reduced motion', (
    tester,
  ) async {
    final controller = await _seededController(tester, completed: 8);
    await _pumpReducedJourney(tester, controller);

    await _solveFrontier(tester, controller);
    expect(find.text('Advance'), findsOneWidget);
    expect(find.text('Replay'), findsNothing);
    await tester.tap(find.text('Advance'));
    await tester.pumpAndSettle();

    expect(controller.frontierPuzzle?.order, 10);
    expect(find.text('Myrrhveil Wilds'), findsWidgets);
    expect(find.text('Enter Myrrhveil'), findsOneWidget);
    expect(find.textContaining('tap to skip'), findsNothing);
  });

  testWidgets('puzzle 72 opens the reunion and then the replay map', (
    tester,
  ) async {
    final controller = await _seededController(tester, completed: 71);
    await _pumpReducedJourney(tester, controller);

    await _solveFrontier(tester, controller);
    expect(find.text('Return to journey'), findsOneWidget);
    expect(find.text('Replay'), findsNothing);
    await tester.tap(find.text('Return to journey'));
    await tester.pumpAndSettle();

    expect(find.text('Dawn Returns'), findsOneWidget);
    expect(controller.isJourneyComplete, isTrue);
    await tester.ensureVisible(find.text('See the dawn'));
    await tester.tap(find.text('See the dawn'));
    await tester.pumpAndSettle();
    expect(find.text('The Knight’s Road'), findsOneWidget);
    await tester.ensureVisible(find.text('Finish the story'));
    await tester.tap(find.text('Finish the story'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('final-landmark')), findsOneWidget);
    expect(controller.catalog!.puzzles.every(controller.canOpenPuzzle), isTrue);
  });

  testWidgets(
    'the final boss alone unlocks a viewable finale through the map',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      final controller = _TimerlessController();
      await tester.runAsync(controller.initialize);
      final arc = controller.originArc!;
      await controller.markStoryBeatSeen(arc.openingScene.id);
      for (final chapter in arc.chapters) {
        await controller.markStoryBeatSeen(chapter.storyBeatId);
      }
      await controller.unlockEntireMap(arc.id);

      expect(controller.journeyProgressFor(arc).completedCount, 0);
      expect(controller.isFinaleUnlocked(arc.id), isFalse);
      await _pumpReducedJourney(tester, controller);

      final finalBoss = arc.catalog.byId(arc.chapters.last.boss.puzzleId);
      final bossNode = find.byKey(ValueKey('puzzle-node-${finalBoss.order}'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();
      await tester.tap(bossNode);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await _solveOpenPuzzle(tester, controller, finalBoss);

      expect(find.text('Return to journey'), findsOneWidget);
      expect(controller.journeyProgressFor(arc).completedCount, 1);
      expect(controller.isFinaleUnlocked(arc.id), isTrue);
      await tester.tap(find.text('Return to journey'));
      await tester.pumpAndSettle();

      final finale = find.byKey(const ValueKey('final-landmark'));
      await tester.ensureVisible(finale);
      await tester.tap(finale);
      await tester.pumpAndSettle();
      expect(find.text(arc.finaleScene.title), findsOneWidget);

      await tester.runAsync(controller.flushPersistence);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();

      final restored = _TimerlessController();
      await tester.runAsync(restored.initialize);
      addTearDown(restored.dispose);
      final restoredArc = restored.originArc!;
      expect(restored.journeyProgressFor(restoredArc).completedCount, 1);
      expect(restored.isFinaleUnlocked(restoredArc.id), isTrue);

      await _pumpReducedJourney(tester, restored);
      final restoredFinale = find.byKey(const ValueKey('final-landmark'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pump();
      await tester.tap(restoredFinale);
      await tester.pumpAndSettle();
      expect(find.text(restoredArc.finaleScene.title), findsOneWidget);
    },
  );

  testWidgets(
    'older puzzle completion offers replay without moving the knight',
    (tester) async {
      final controller = await _seededController(tester, completed: 1);
      await _pumpReducedJourney(tester, controller);
      final first = controller.catalog!.puzzles.first;
      final firstNode = find.byKey(const ValueKey('puzzle-node-1'));
      await tester.ensureVisible(firstNode);
      await tester.tap(firstNode);
      await tester.pumpAndSettle();
      await _solveOpenPuzzle(tester, controller, first);

      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Return to journey'), findsOneWidget);
      await tester.tap(find.text('Return to journey'));
      await tester.pumpAndSettle();
      expect(controller.frontierPuzzle?.order, 2);
      expect(find.textContaining('tap to skip'), findsNothing);
    },
  );

  testWidgets('web offers support once after the puzzle before a boss', (
    tester,
  ) async {
    final controller = await _seededController(
      tester,
      completed: 7,
      contentPolicy: const ContentEntitlementPolicy.web(),
    );
    Uri? launchedUri;
    await _pumpReducedJourney(
      tester,
      controller,
      externalUrlLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    await _solveFrontier(tester, controller);
    expect(controller.frontierPuzzle?.order, 9);
    await tester.tap(find.text('Advance'));
    await tester.pumpAndSettle();

    expect(find.text('Support the developer?'), findsOneWidget);
    expect(
      controller.supportPromptedChapterIds,
      contains(controller.originArc!.chapters.first.id),
    );
    await tester.tap(find.byKey(const ValueKey('support-prompt-open-coffee')));
    await tester.pumpAndSettle();
    expect(launchedUri, buyMeACoffeeUri);

    final eighth = controller.catalog!.puzzles[7];
    final node = find.byKey(const ValueKey('puzzle-node-8'));
    await tester.ensureVisible(node);
    await tester.tap(node);
    await tester.pumpAndSettle();
    await _solveOpenPuzzle(tester, controller, eighth);
    await tester.tap(find.text('Return to journey'));
    await tester.pumpAndSettle();

    expect(find.text('Support the developer?'), findsNothing);
    expect(controller.supportPromptedChapterIds, hasLength(1));
  });

  testWidgets('map-unlocked pre-boss completion still returns for web prompt', (
    tester,
  ) async {
    final controller = await _seededController(
      tester,
      completed: 0,
      contentPolicy: const ContentEntitlementPolicy.web(),
    );
    await controller.unlockEntireMap(controller.originArc!.id);
    await _pumpReducedJourney(tester, controller);

    final preBoss = controller.catalog!.puzzles[7];
    final node = find.byKey(const ValueKey('puzzle-node-8'));
    await tester.ensureVisible(node);
    await tester.tap(node);
    await tester.pumpAndSettle();
    await _solveOpenPuzzle(tester, controller, preBoss);

    expect(find.text('Return to journey'), findsOneWidget);
    await tester.tap(find.text('Return to journey'));
    await tester.pumpAndSettle();

    expect(find.text('Support the developer?'), findsOneWidget);
    expect(controller.frontierPuzzle?.order, 1);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap to skip'), findsNothing);
  });
}

Future<AppController> _seededController(
  WidgetTester tester, {
  required int completed,
  ContentEntitlementPolicy? contentPolicy,
}) async {
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = _TimerlessController(contentPolicy: contentPolicy);
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  final reachedOrder = completed >= 72 ? 72 : completed + 1;
  final chapter = controller.originArc!.chapterForOrder(reachedOrder);
  await controller.markStoryBeatSeen(controller.originArc!.openingScene.id);
  await controller.markStoryBeatSeen(chapter.storyBeatId);
  for (final puzzle in controller.catalog!.puzzles.take(completed)) {
    controller.records[puzzle.id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
  }
  return controller;
}

Future<void> _pumpReducedJourney(
  WidgetTester tester,
  AppController controller, {
  ExternalUrlLauncher? externalUrlLauncher,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: JourneyScreen(
        controller: controller,
        externalUrlLauncher: externalUrlLauncher,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _solveFrontier(
  WidgetTester tester,
  AppController controller,
) async {
  final puzzle = controller.frontierPuzzle!;
  final node = find.byKey(ValueKey('puzzle-node-${puzzle.order}'));
  await tester.ensureVisible(node);
  await tester.tap(node);
  await tester.pumpAndSettle();
  await _solveOpenPuzzle(tester, controller, puzzle);
}

Future<void> _solveOpenPuzzle(
  WidgetTester tester,
  AppController controller,
  PuzzleDefinition puzzle,
) async {
  final solution = const ExactSolver().solve(puzzle, limit: 1).solutions.single;
  for (final cell in solution.take(solution.length - 1)) {
    controller.setCell(puzzle, cell, ManualCellState.crown);
  }
  await tester.pump();
  final last = solution.last;
  final lastCell = find.byKey(ValueKey('cell-${last.row}-${last.column}'));
  await tester.ensureVisible(lastCell);
  await tester.tap(lastCell);
  await tester.pump();
  await tester.tap(lastCell);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _TimerlessController extends AppController {
  _TimerlessController({super.contentPolicy});

  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
