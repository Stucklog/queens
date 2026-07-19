import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/human_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Academy lessons unlock in order and persist outside journey records',
    () async {
      SharedPreferences.setMockInitialValues({
        SaveIds.tutorialComplete: true,
        'regalia.journeySchemaVersion': AppController.journeySchemaVersion,
      });
      final controller = AppController();
      await controller.initialize();

      expect(controller.academyAvailable, isTrue);
      expect(controller.academyLessons, hasLength(6));
      final first = controller.academyLessons.first;
      final second = controller.academyLessons[1];
      expect(controller.isAcademyLessonUnlocked(first), isTrue);
      expect(controller.isAcademyLessonUnlocked(second), isFalse);
      expect(controller.openAcademyPractice(second), isFalse);
      expect(controller.boards, isNot(contains(second.practicePuzzle.id)));

      final journeyFrontier = controller.frontierPuzzle!.id;
      expect(controller.openAcademyPractice(first), isTrue);
      final solution =
          const ExactSolver()
              .solve(first.practicePuzzle, limit: 1)
              .solutions
              .single;
      PuzzleCompletionOutcome? outcome;
      for (final cell in solution) {
        outcome = controller.setCell(
          first.practicePuzzle,
          cell,
          ManualCellState.crown,
        );
      }

      expect(outcome, isNotNull);
      expect(outcome!.advancedJourney, isFalse);
      expect(controller.isAcademyLessonComplete(first), isTrue);
      expect(controller.isAcademyLessonUnlocked(second), isTrue);
      expect(
        controller.recordFor(first.practicePuzzle.id).status,
        CompletionStatus.newPuzzle,
      );
      expect(controller.frontierPuzzle!.id, journeyFrontier);
      expect(controller.records, isEmpty);

      await controller.flushPersistence();
      controller.dispose();

      final restored = AppController();
      await restored.initialize();
      addTearDown(restored.dispose);
      final restoredFirst = restored.academyLessons.first;
      expect(restored.isAcademyLessonComplete(restoredFirst), isTrue);
      expect(
        restored.isAcademyLessonUnlocked(restored.academyLessons[1]),
        isTrue,
      );
      expect(restored.frontierPuzzle!.id, journeyFrontier);

      expect(restored.openAcademyPractice(restoredFirst), isTrue);
      expect(
        restored.boardFor(restoredFirst.practicePuzzle).cells,
        everyElement(ManualCellState.empty),
      );
      expect(restored.isAcademyLessonComplete(restoredFirst), isTrue);
      expect(restored.records, isEmpty);
    },
  );

  test('invalid saved Academy IDs and boards are ignored', () async {
    SharedPreferences.setMockInitialValues({
      SaveIds.tutorialComplete: true,
      'regalia.journeySchemaVersion': AppController.journeySchemaVersion,
      SaveIds.academyCompletedLessons: ['regalia:lesson/academy/not-installed'],
      SaveIds.academyBoards: '{"bad":"shape"}',
    });
    final controller = AppController();
    await controller.initialize();
    addTearDown(controller.dispose);

    expect(controller.academyCompletedCount, 0);
    expect(
      controller.isAcademyLessonUnlocked(controller.academyLessons.first),
      isTrue,
    );
  });

  test(
    'every practice puzzle exercises its declared deduction technique',
    () async {
      SharedPreferences.setMockInitialValues({
        SaveIds.tutorialComplete: true,
        'regalia.journeySchemaVersion': AppController.journeySchemaVersion,
      });
      final controller = AppController();
      await controller.initialize();
      addTearDown(controller.dispose);

      for (final lesson in controller.academyLessons) {
        final techniques =
            const HumanSolver()
                .analyze(lesson.practicePuzzle)
                .trace
                .map((deduction) => deduction.technique)
                .toSet();
        expect(
          techniques,
          contains(lesson.technique),
          reason:
              '${lesson.title} must practice ${lesson.technique.name}, not just describe it',
        );
      }
    },
  );
}
