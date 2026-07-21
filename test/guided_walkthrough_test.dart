import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/screens/guided_walkthrough_screen.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'walkthrough progresses from rules to deductions and exclusions',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SaveIds.tutorialComplete: true,
        'regalia.journeySchemaVersion': 1,
      });
      final controller = AppController();
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);
      final puzzle = controller.catalog!.puzzles.first;

      await tester.pumpWidget(
        MaterialApp(
          home: GuidedWalkthroughScreen(
            controller: controller,
            puzzle: puzzle,
            replay: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Four rules make every crown certain'), findsOneWidget);
      var board = tester.widget<RegaliaBoard>(
        find.byKey(const ValueKey('guided-walkthrough-board')),
      );
      expect(board.cues, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('guided-walkthrough-continue')),
      );
      await tester.pump();
      board = tester.widget<RegaliaBoard>(
        find.byKey(const ValueKey('guided-walkthrough-board')),
      );
      expect(board.cues, isNotEmpty);

      final crown =
          const ExactSolver().solve(puzzle, limit: 1).solutions.single.first;
      final crownCell = find.byKey(
        ValueKey('cell-${crown.row}-${crown.column}'),
      );
      await tester.ensureVisible(crownCell);
      await tester.tap(crownCell);
      await tester.tap(crownCell);
      await tester.pump();

      expect(find.text('The board protects each crown'), findsOneWidget);
      board = tester.widget<RegaliaBoard>(
        find.byKey(const ValueKey('guided-walkthrough-board')),
      );
      expect(board.automaticExclusions, isNotEmpty);

      await tester.tap(
        find.byKey(const ValueKey('guided-walkthrough-continue')),
      );
      await tester.pump();
      expect(find.text('The board protects each crown'), findsNothing);
      board = tester.widget<RegaliaBoard>(
        find.byKey(const ValueKey('guided-walkthrough-board')),
      );
      expect(board.cues, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
