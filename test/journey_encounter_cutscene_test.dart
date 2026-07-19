import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/widgets/encounter_cutscene.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'journey encounter releases the puzzle at the four-second deadline',
    (tester) async {
      final controller = await _journeyController(tester);
      final arc = controller.originArc!;
      final encounter = arc.chapters.first.encounters.first;
      final puzzle = arc.catalog.byId(encounter.puzzleId);
      final board = controller.boardFor(puzzle);

      await _pumpJourney(tester, controller);
      final node = find.byKey(ValueKey('puzzle-node-${puzzle.order}'));
      await tester.ensureVisible(node);
      await tester.tap(node);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        controller.recordFor(puzzle.id).status,
        CompletionStatus.inProgress,
      );

      expect(find.byType(EncounterCutscene), findsOneWidget);
      expect(find.text(encounter.name), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(controller.timerStarts, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(board.at(const Cell(0, 0)), ManualCellState.empty);

      await tester.pump(
        EncounterCutsceneTiming.standard.total -
            const Duration(milliseconds: 2),
      );
      expect(find.byType(EncounterCutscene), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(controller.timerStarts, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(EncounterCutscene), findsNothing);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(controller.timerStarts, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(board.at(const Cell(0, 0)), ManualCellState.crown);

      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(EncounterCutscene), findsNothing);
      expect(controller.timerStarts, 1);
    },
  );

  testWidgets('ordinary journey puzzle bypasses the encounter introduction', (
    tester,
  ) async {
    final controller = await _journeyController(tester);
    final puzzle = controller.originArc!.catalog.puzzles.first;
    expect(controller.originArc!.encounterForPuzzle(puzzle), isNull);

    await _pumpJourney(tester, controller);
    final node = find.byKey(ValueKey('puzzle-node-${puzzle.order}'));
    await tester.ensureVisible(node);
    await tester.tap(node);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(controller.recordFor(puzzle.id).status, CompletionStatus.inProgress);

    expect(find.byType(EncounterCutscene), findsNothing);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(controller.timerStarts, 1);
  });
}

Future<_TrackingTimerController> _journeyController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
  final controller = _TrackingTimerController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  final arc = controller.originArc!;
  await controller.markStoryBeatSeen(StoryBeatIds.opening);
  await controller.markStoryBeatSeen(arc.chapters.first.storyBeatId);
  await controller.unlockEntireMap(ContentIds.originArc);
  return controller;
}

Future<void> _pumpJourney(
  WidgetTester tester,
  _TrackingTimerController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      home: JourneyScreen(controller: controller),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _TrackingTimerController extends AppController {
  int timerStarts = 0;

  @override
  void startTimer(String puzzleId) {
    timerStarts++;
  }

  @override
  void stopTimer() {}
}
