import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/academy_screen.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/pixel_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Academy teaches, practices, unlocks, and returns independently',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SaveIds.tutorialComplete: true,
        'regalia.journeySchemaVersion': AppController.journeySchemaVersion,
      });
      final controller = AppController();
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);
      controller.updateSettings(
        controller.settings.copyWith(reducedMotion: true, showTimer: false),
      );
      final journeyFrontier = controller.frontierPuzzle!.id;

      await tester.pumpWidget(RegaliaApp(controller: controller));
      await tester.pump();
      expect(find.byTooltip('Academy'), findsOneWidget);

      await tester.tap(find.byTooltip('Academy'));
      await _pumpFrames(tester);
      expect(find.byType(AcademyScreen), findsOneWidget);
      expect(find.text('The Deduction Hall'), findsOneWidget);
      expect(find.text('0 / 6 lessons mastered'), findsOneWidget);
      expect(find.text('Lesson 1 · Ready'), findsOneWidget);
      expect(find.text('Lesson 2 · Locked'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('academy-lesson-1')));
      await _pumpFrames(tester);
      expect(find.byType(AcademyLessonScreen), findsOneWidget);
      expect(find.text('The technique'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await tester.pump();
      expect(find.text('Board example'), findsOneWidget);
      expect(find.textContaining('The crown at B2 rules out'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      await tester.pump();
      expect(find.text('Practice technique'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('start-academy-practice')),
      );
      await tester.tap(find.byKey(const ValueKey('start-academy-practice')));
      await _pumpFrames(tester);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Academy practice · 6 × 6'), findsOneWidget);

      final lesson = controller.academyLessons.first;
      final solution =
          const ExactSolver()
              .solve(lesson.practicePuzzle, limit: 1)
              .solutions
              .single;
      for (final cell in solution.take(solution.length - 1)) {
        controller.setCell(lesson.practicePuzzle, cell, ManualCellState.crown);
      }
      await tester.pump();
      final last = solution.last;
      final lastCell = find.byKey(ValueKey('cell-${last.row}-${last.column}'));
      await tester.ensureVisible(lastCell);
      await tester.tap(lastCell);
      await tester.tap(lastCell);
      await _pumpFrames(tester);

      expect(find.text('A clean coronation'), findsOneWidget);
      expect(find.text('Return to Academy'), findsOneWidget);
      expect(controller.isAcademyLessonComplete(lesson), isTrue);
      expect(controller.frontierPuzzle!.id, journeyFrontier);
      expect(controller.records, isEmpty);

      await tester.tap(find.text('Return to Academy'));
      await _pumpFrames(tester);
      expect(find.byType(AcademyLessonScreen), findsOneWidget);
      expect(find.text('Replay practice'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
      await tester.pump();
      expect(find.text('Continue to lesson 2'), findsOneWidget);

      await tester.tap(find.byType(PixelBackButton));
      await _pumpFrames(tester);
      expect(find.text('1 / 6 lessons mastered'), findsOneWidget);
      expect(find.text('Lesson 2 · Ready'), findsOneWidget);
    },
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
