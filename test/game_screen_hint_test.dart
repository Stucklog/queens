import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/core/human_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/regalia_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hint text and cell cue share the six-second lifecycle', (
    tester,
  ) async {
    const target = Cell(1, 2);
    final session = await _pumpGameWithHints(tester, [
      Deduction(
        technique: DeductionTechnique.singleRemaining,
        explanation: 'Place a crown in the highlighted cell.',
        placement: target,
        sources: {target},
      ),
    ]);

    await _pressHint(tester);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.duration, GameScreen.hintDisplayDuration);
    expect(GameScreen.hintDisplayDuration, const Duration(seconds: 6));
    expect(_activeCues(tester), {target: BoardCue.hintPlacement});
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cell-1-2'))),
      matchesSemantics(
        label: 'Row 2, column C, region ${session.puzzle.regionAt(target) + 1}',
        value: 'empty, hint says place a crown here',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('puzzle-feedback-message')),
      ),
      matchesSemantics(
        label:
            'A gentle nudge. Highlighted row 2, column C. Place a crown in the highlighted cell.',
        isLiveRegion: true,
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    expect(
      find.byKey(const ValueKey('puzzle-feedback-message')),
      findsOneWidget,
    );
    expect(_activeCues(tester), isNotEmpty);

    await tester.pump(const Duration(milliseconds: 1300));
    // The display timer has elapsed, but the snackbar is still animating out;
    // the visual cell cue must remain until the text has actually gone.
    expect(
      find.byKey(const ValueKey('puzzle-feedback-message')),
      findsOneWidget,
    );
    expect(_activeCues(tester), isNotEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const ValueKey('puzzle-feedback-message')), findsNothing);
    expect(_activeCues(tester), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a repeated hint cannot be cleared by the first hint closing', (
    tester,
  ) async {
    const firstTarget = Cell(1, 2);
    const secondTarget = Cell(2, 3);
    final session = await _pumpGameWithHints(tester, [
      Deduction(
        technique: DeductionTechnique.singleRemaining,
        explanation: 'First scripted hint.',
        placement: firstTarget,
        sources: {firstTarget},
      ),
      Deduction(
        technique: DeductionTechnique.directExclusion,
        explanation: 'Second scripted hint.',
        eliminated: {secondTarget},
        sources: {Cell(3, 3)},
      ),
    ]);

    await _pressHint(tester);
    expect(_activeCues(tester), {firstTarget: BoardCue.hintPlacement});
    await tester.pump(const Duration(milliseconds: 2700));

    await _pressHint(tester);
    expect(_activeCues(tester), {
      const Cell(3, 3): BoardCue.hintSource,
      secondTarget: BoardCue.hintElimination,
    });
    expect(
      tester.getSemantics(find.byKey(const ValueKey('cell-2-3'))),
      matchesSemantics(
        label:
            'Row 3, column D, region ${session.puzzle.regionAt(secondTarget) + 1}',
        value: 'empty, hint says exclude this cell',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    // The first hint's original six-second window has now elapsed. Its
    // completion callback must not clear the newer hint's message or cues.
    await tester.pump(const Duration(milliseconds: 3200));
    expect(
      find.byKey(const ValueKey('puzzle-feedback-message')),
      findsOneWidget,
    );
    expect(_activeCues(tester), {
      const Cell(3, 3): BoardCue.hintSource,
      secondTarget: BoardCue.hintElimination,
    });

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Map<Cell, BoardCue> _activeCues(WidgetTester tester) =>
    tester.widget<RegaliaBoard>(find.byType(RegaliaBoard)).cues;

Future<void> _pressHint(WidgetTester tester) async {
  final hint = find.text('Hint');
  expect(hint, findsOneWidget);
  await tester.tap(hint);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<({AppController controller, PuzzleDefinition puzzle})>
_pumpGameWithHints(WidgetTester tester, List<Deduction> hints) async {
  tester.view.physicalSize = const Size(1100, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
  final controller = _TimerlessController(_ScriptedHumanSolver(hints));
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  final puzzle = controller.catalog!.puzzles.first;
  expect(controller.openPuzzle(puzzle), isTrue);
  await tester.pumpWidget(
    MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
  );
  await tester.pump();
  return (controller: controller, puzzle: puzzle);
}

class _ScriptedHumanSolver extends HumanSolver {
  _ScriptedHumanSolver(this._hints);

  final List<Deduction> _hints;
  int _index = 0;

  @override
  Deduction? nextDeduction(PuzzleDefinition puzzle, BoardState board) {
    final index = _index < _hints.length ? _index : _hints.length - 1;
    _index++;
    return _hints[index];
  }
}

class _TimerlessController extends AppController {
  _TimerlessController(HumanSolver humanSolver)
    : super(humanSolver: humanSolver);

  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
