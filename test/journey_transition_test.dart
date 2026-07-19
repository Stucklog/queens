import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/journey_screen.dart';
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

    expect(find.text('The Hollow Star Falls'), findsOneWidget);
    expect(controller.isJourneyComplete, isTrue);
    await tester.ensureVisible(find.text('See the dawn return'));
    await tester.tap(find.text('See the dawn return'));
    await tester.pumpAndSettle();
    expect(find.text('The Crown Returns'), findsOneWidget);
    await tester.ensureVisible(find.text('Return the crown'));
    await tester.tap(find.text('Return the crown'));
    await tester.pumpAndSettle();
    expect(find.text('The First Morning'), findsOneWidget);
    await tester.ensureVisible(find.text('Finish the story'));
    await tester.tap(find.text('Finish the story'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('final-landmark')), findsOneWidget);
    expect(controller.catalog!.puzzles.every(controller.canOpenPuzzle), isTrue);
  });

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
}

Future<AppController> _seededController(
  WidgetTester tester, {
  required int completed,
}) async {
  final reachedOrder = completed >= 72 ? 72 : completed + 1;
  final chapter = chapterForOrder(reachedOrder);
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
    'regalia.seenStoryBeats': <String>[
      StoryBeatIds.opening,
      chapter.storyBeatId,
    ],
  });
  final controller = _TimerlessController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  for (final puzzle in controller.catalog!.puzzles.take(completed)) {
    controller.records[puzzle.id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
  }
  return controller;
}

Future<void> _pumpReducedJourney(
  WidgetTester tester,
  AppController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: JourneyScreen(controller: controller),
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
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
