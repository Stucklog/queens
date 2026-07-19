import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/boss_finisher_cutscene.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/encounter_cutscene.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('boss finisher presentations escalate move, effects, and deadline', () {
    final presentations = [
      for (var level = 1; level <= 8; level++)
        BossFinisherPresentation.forSpectacle(level),
    ];

    expect(
      presentations.map((presentation) => presentation.finisher).toSet(),
      hasLength(8),
    );
    expect(presentations.last.finisher, KnightAnimation.regaliaNova);
    expect(presentations.last.specialMoveName, 'Regalia Nova');
    for (var index = 0; index < presentations.length; index++) {
      final presentation = presentations[index];
      expect(presentation.spectacleLevel, index + 1);
      expect(presentation.effectLevel, index + 1);
      expect(
        presentation.timing.hold,
        greaterThan(
          presentation.finisher.presentationDuration +
              presentation.finisher.postRoll,
        ),
      );
      if (index == 0) continue;
      expect(
        presentation.timing.total,
        greaterThan(presentations[index - 1].timing.total),
      );
      expect(
        presentation.timing.reducedMotion,
        greaterThan(presentations[index - 1].timing.reducedMotion),
      );
    }
  });

  testWidgets('finisher waits for reveal then animates both combatants once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const timing = EncounterCutsceneTiming(
      entrance: Duration(milliseconds: 100),
      hold: Duration(milliseconds: 900),
      exit: Duration(milliseconds: 100),
      reducedMotion: Duration(milliseconds: 50),
    );
    const presentation = BossFinisherPresentation(
      spectacleLevel: 1,
      finisher: KnightAnimation.crownSlash,
      specialMoveName: 'Crown Slash',
      timing: timing,
      effectLevel: 1,
    );
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BossFinisherCutscene(
          boss: _testBoss,
          presentation: presentation,
          background: const ColoredBox(color: Color(0xff20385f)),
          onFinished: () => completions++,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('boss-finisher-cutscene')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('encounter-cutscene-enemy-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('encounter-cutscene-knight-panel')),
      findsOneWidget,
    );
    expect(find.text('CROWN SLASH'), findsOneWidget);
    expect(find.text(_testBoss.name), findsOneWidget);
    expect(find.text('K.O.'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Boss finisher. Crown Slash. ${_testBoss.name} is defeated.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.bounce,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .stimulus,
      KnightAnimation.bounce,
    );
    expect(
      tester
          .widget<CombatSpecialEffects>(
            find.byKey(const ValueKey('boss-finisher-special-effects')),
          )
          .active,
      isFalse,
    );

    await tester.pump(timing.entrance);

    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.crownSlash,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .stimulus,
      KnightAnimation.crownSlash,
    );
    expect(
      tester
          .widget<CombatSpecialEffects>(
            find.byKey(const ValueKey('boss-finisher-special-effects')),
          )
          .active,
      isTrue,
    );

    await tester.pump(timing.hold + timing.exit);
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('reduced motion shows the resolved blow on its short deadline', (
    tester,
  ) async {
    final presentation = BossFinisherPresentation.forSpectacle(8);
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: BossFinisherCutscene(
            boss: _testBoss,
            presentation: presentation,
            background: const ColoredBox(color: Color(0xff20385f)),
            onFinished: () => completions++,
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.regaliaNova,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .stimulus,
      KnightAnimation.regaliaNova,
    );
    expect(
      tester
          .widget<CombatSpecialEffects>(
            find.byKey(const ValueKey('boss-finisher-special-effects')),
          )
          .active,
      isTrue,
    );

    await tester.pump(
      presentation.timing.reducedMotion - const Duration(milliseconds: 1),
    );
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
  });

  testWidgets('solving a boss gates completion behind its finisher cutscene', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.unlockEntireMap(ContentIds.originArc);
    final arc = controller.originArc!;
    final boss = arc.chapters.first.boss;
    final puzzle = arc.catalog.byId(boss.puzzleId);
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(controller.openPuzzle(puzzle), isTrue);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('boss-finisher-cutscene')), findsNothing);

    final finalCell = find.byKey(
      ValueKey('cell-${solution.last.row}-${solution.last.column}'),
    );
    await tester.ensureVisible(finalCell);
    await tester.tap(finalCell);
    await tester.pump();
    await tester.tap(finalCell);
    await tester.pump();

    final presentation = BossFinisherPresentation.forSpectacle(
      boss.spectacleLevel,
    );
    expect(
      find.byKey(const ValueKey('boss-finisher-cutscene')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .encounter,
      same(boss),
    );
    expect(
      controller.recordFor(puzzle.id).status,
      isNot(CompletionStatus.newPuzzle),
      reason: 'the solve is recorded before presentation starts',
    );

    await tester.pump(
      presentation.timing.total - const Duration(milliseconds: 1),
    );
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('boss-finisher-cutscene')), findsNothing);
    expect(find.byKey(const ValueKey('completion-knight')), findsOneWidget);
  });

  testWidgets('ordinary puzzle completion never mounts a boss finisher', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.unlockEntireMap(ContentIds.originArc);
    final arc = controller.originArc!;
    final puzzle = arc.catalog.puzzles.firstWhere(
      (candidate) => arc.encounterForPuzzle(candidate) == null,
    );
    final solution =
        const ExactSolver().solve(puzzle, limit: 1).solutions.single;
    for (final cell in solution.take(solution.length - 1)) {
      controller.setCell(puzzle, cell, ManualCellState.crown);
    }
    expect(controller.openPuzzle(puzzle), isTrue);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, puzzle: puzzle)),
    );
    await tester.pump();
    final finalCell = find.byKey(
      ValueKey('cell-${solution.last.row}-${solution.last.column}'),
    );
    await tester.ensureVisible(finalCell);
    await tester.tap(finalCell);
    await tester.pump();
    await tester.tap(finalCell);
    await tester.pump();

    expect(find.byKey(const ValueKey('boss-finisher-cutscene')), findsNothing);
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('puzzle-knight-sprite')),
          )
          .animation,
      KnightAnimation.special,
    );
  });
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}

const _testBoss = ChapterBoss(
  id: 'regalia:boss/test/clockwork-warden',
  name: 'Clockwork Warden',
  puzzleId: 'regalia:puzzle/test/boss/clockwork-warden',
  spriteFamily: EnemySpriteFamily.clockwork,
  spriteAsset: 'assets/art/combat/opponents/gear-goblin.png',
  spectacleLevel: 1,
  size: 5,
  targetDifficulty: DifficultyTier.easy,
  unlockTargetId: 'regalia:chapter/test/two',
);
