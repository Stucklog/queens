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
        presentation.timing.finalMove,
        greaterThan(presentation.finisher.presentationDuration),
      );
      expect(
        presentation.timing.bossDefeat,
        greaterThan(presentation.finisher.presentationDuration),
      );
      expect(
        presentation.timing.victory,
        greaterThan(KnightAnimation.special.presentationDuration),
      );
      expect(
        presentation.timing.phaseAt(Duration.zero),
        BossFinisherPhase.finalMove,
      );
      expect(
        presentation.timing.phaseAt(presentation.timing.finalMove),
        BossFinisherPhase.panToBoss,
      );
      expect(
        presentation.timing.phaseAt(presentation.timing.bossDefeatStart),
        BossFinisherPhase.bossDefeat,
      );
      expect(
        presentation.timing.phaseAt(presentation.timing.panToKnightStart),
        BossFinisherPhase.panToKnight,
      );
      expect(
        presentation.timing.phaseAt(presentation.timing.victoryStart),
        BossFinisherPhase.victory,
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

  testWidgets('finisher uses full-screen move, defeat, and victory shots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const timing = BossFinisherTiming(
      finalMove: Duration(milliseconds: 200),
      panToBoss: Duration(milliseconds: 100),
      bossDefeat: Duration(milliseconds: 200),
      panToKnight: Duration(milliseconds: 100),
      victory: Duration(milliseconds: 200),
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
      find.byKey(const ValueKey('boss-finisher-phase-final-move')),
      findsOneWidget,
    );
    expect(find.byType(EncounterCutscene), findsNothing);
    expect(
      find.byKey(const ValueKey('encounter-cutscene-enemy-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('encounter-cutscene-knight-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('encounter-cutscene-versus')),
      findsNothing,
    );
    expect(find.text('CROWN SLASH'), findsOneWidget);
    expect(find.text(_testBoss.name), findsOneWidget);
    expect(find.text('K.O.'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Boss finisher. Crown Slash. ${_testBoss.name} is defeated. '
        'The crown-bearer is victorious.',
      ),
      findsOneWidget,
    );
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
      KnightAnimation.bounce,
    );
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .frame,
      0,
    );
    expect(
      tester
          .widget<CombatSpecialEffects>(
            find.byKey(const ValueKey('boss-finisher-special-effects')),
          )
          .active,
      isTrue,
    );
    expect(
      tester
          .widget<Positioned>(
            find.byKey(const ValueKey('boss-finisher-knight-shot')),
          )
          .left,
      0,
    );

    await tester.pump(timing.finalMove + timing.panToBoss ~/ 2);

    expect(
      find.byKey(const ValueKey('boss-finisher-phase-pan-to-boss')),
      findsOneWidget,
    );
    final knightPanLeft =
        tester
            .widget<Positioned>(
              find.byKey(const ValueKey('boss-finisher-knight-shot')),
            )
            .left!;
    final bossPanLeft =
        tester
            .widget<Positioned>(
              find.byKey(const ValueKey('boss-finisher-boss-shot')),
            )
            .left!;
    expect(knightPanLeft, inExclusiveRange(-250, -150));
    expect(bossPanLeft, inExclusiveRange(150, 250));
    expect(bossPanLeft - knightPanLeft, closeTo(400, 0.1));
    expect(
      find.byKey(const ValueKey('boss-finisher-special-effects')),
      findsNothing,
    );

    await tester.pump(timing.panToBoss ~/ 2);
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-boss-defeat')),
      findsOneWidget,
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
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .frame,
      0,
    );

    await tester.pump(timing.bossDefeat ~/ 2);
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .frame,
      2,
    );
    expect(find.text('THE FINAL BLOW LANDS'), findsOneWidget);
    expect(find.text('DEFEATED'), findsNothing);

    await tester.pump(timing.bossDefeat ~/ 2);
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-pan-to-knight')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.crownSlash,
    );
    expect(find.text('DEFEATED'), findsOneWidget);

    await tester.pump(timing.panToKnight);
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-victory')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PixelKnightSprite>(
            find.byKey(const ValueKey('boss-finisher-knight-sprite')),
          )
          .animation,
      KnightAnimation.special,
    );
    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.text('CROWN-BEARER'), findsOneWidget);
    expect(completions, 0);

    await tester.pump(timing.victory + timing.exit);
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('special-move art never sits beneath the opaque caption', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: BossFinisherCutscene(
              boss: _testBoss,
              background: const ColoredBox(color: Color(0xff20385f)),
              onFinished: () {},
            ),
          ),
        ),
      );

      final art = tester.getRect(
        find.byKey(const ValueKey('boss-finisher-knight-art-viewport')),
      );
      final caption = tester.getRect(
        find.byKey(const ValueKey('boss-finisher-knight-caption')),
      );
      expect(
        art.bottom,
        lessThanOrEqualTo(caption.top),
        reason: 'special-move art and caption at ${size.width}x${size.height}',
      );
      expect(art.left, greaterThanOrEqualTo(0));
      expect(art.right, lessThanOrEqualTo(size.width));
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('regular enemies receive encounter-specific victory framing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BossFinisherCutscene(
          boss: _testEnemy,
          background: const ColoredBox(color: Color(0xff20385f)),
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('ENCOUNTER SPECIAL'), findsOneWidget);
    expect(find.text('ENEMY · FINAL STAND'), findsOneWidget);
    expect(find.text('BOSS · FINAL STAND'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Encounter victory. Crown Slash. ${_testEnemy.name} is defeated. '
        'The crown-bearer is victorious.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
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
      KnightAnimation.special,
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
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .frame,
      3,
    );
    expect(
      find.byKey(const ValueKey('boss-finisher-phase-victory')),
      findsOneWidget,
    );
    expect(find.text('VICTORY'), findsOneWidget);
    expect(find.byType(EncounterCutscene), findsNothing);
    expect(
      find.byKey(const ValueKey('boss-finisher-special-effects')),
      findsNothing,
    );

    await tester.pump(
      presentation.timing.reducedMotion - const Duration(milliseconds: 1),
    );
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
  });

  testWidgets('custom boss art restarts when the defeat shot begins', (
    tester,
  ) async {
    const timing = BossFinisherTiming(
      finalMove: Duration(milliseconds: 100),
      panToBoss: Duration(milliseconds: 50),
      bossDefeat: Duration(milliseconds: 100),
      panToKnight: Duration(milliseconds: 50),
      victory: Duration(milliseconds: 100),
      exit: Duration(milliseconds: 50),
      reducedMotion: Duration(milliseconds: 50),
    );
    const presentation = BossFinisherPresentation(
      spectacleLevel: 1,
      finisher: KnightAnimation.crownSlash,
      specialMoveName: 'Crown Slash',
      timing: timing,
      effectLevel: 1,
    );
    var mounts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BossFinisherCutscene(
          boss: _testBoss,
          presentation: presentation,
          background: const ColoredBox(color: Color(0xff20385f)),
          bossArt: _MountProbe(onMount: () => mounts++),
          onFinished: () {},
        ),
      ),
    );

    expect(mounts, 1);
    expect(
      find.byKey(const ValueKey('boss-finisher-custom-boss-waiting')),
      findsOneWidget,
    );

    await tester.pump(timing.finalMove + timing.panToBoss);
    expect(mounts, 2);
    expect(
      find.byKey(const ValueKey('boss-finisher-custom-boss-defeat')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets('solving a regular encounter plays the full victory cutscene', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    await controller.unlockEntireMap(ContentIds.originArc);
    final arc = controller.originArc!;
    final encounter = arc.chapters.first.encounters.first;
    final puzzle = arc.catalog.byId(encounter.puzzleId);
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

    final presentation = BossFinisherPresentation.forSpectacle(
      encounter.spectacleLevel,
    );
    expect(
      find.byKey(const ValueKey('boss-finisher-cutscene')),
      findsOneWidget,
    );
    expect(find.text('ENCOUNTER SPECIAL'), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-knight')), findsNothing);
    expect(
      tester
          .widget<PixelEnemySprite>(
            find.byKey(const ValueKey('boss-finisher-boss-sprite')),
          )
          .encounter,
      same(encounter),
    );

    await tester.pump(presentation.timing.total);
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

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 80);
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

const _testEnemy = ChapterEnemy(
  id: 'regalia:enemy/origin/test-enemy',
  name: 'Clockwork Warden',
  puzzleId: 'regalia:puzzle/origin/easy-003',
  spriteFamily: EnemySpriteFamily.clockwork,
  spriteAsset: 'assets/art/combat/opponents/gear-goblin.png',
);
