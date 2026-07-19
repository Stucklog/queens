import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/screens/challenge_screen.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/rules_screen.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:regalia/screens/tutorial_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:regalia/widgets/pixel_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _narrow = Size(390, 844);
const _wide = Size(1180, 800);

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
  });

  testWidgets('tutorial pages remain responsive at 150% text scaling', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        TutorialScreen(
          key: ValueKey('tutorial-${size.width}'),
          controller: controller,
        ),
        reason: 'tutorial intro at ${size.width}x${size.height}',
      );

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Three kinds of royalty'), findsOneWidget);
      _expectNoLayoutException(
        tester,
        reason: 'tutorial rules at ${size.width}x${size.height}',
      );

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Try the board'), findsOneWidget);
      _expectNoLayoutException(
        tester,
        reason: 'tutorial board at ${size.width}x${size.height}',
      );
    }
  });

  testWidgets('rules and settings use pixel controls without overflow', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        const RulesScreen(),
        reason: 'rules at ${size.width}x${size.height}',
      );
      expect(find.byType(PixelBackButton), findsOneWidget);
      expect(find.byType(PixelIconButton), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mark your thinking'),
        300,
        scrollable: find.byType(Scrollable),
      );
      _expectNoLayoutException(
        tester,
        reason: 'scrolled rules at ${size.width}x${size.height}',
      );

      await _pumpScreen(
        tester,
        SettingsScreen(controller: controller),
        reason: 'settings at ${size.width}x${size.height}',
      );
      expect(find.byType(PixelBackButton), findsOneWidget);
      expect(find.byType(PixelIconButton), findsOneWidget);
      expect(find.byType(PixelToggleTile), findsNWidgets(3));
      await tester.scrollUntilVisible(
        find.text('Private by design'),
        300,
        scrollable: find.byType(Scrollable),
      );
      _expectNoLayoutException(
        tester,
        reason: 'scrolled settings at ${size.width}x${size.height}',
      );
    }
  });

  testWidgets('game uses responsive puzzle and control layouts', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    final puzzle = controller.catalog!.puzzles.first;
    expect(controller.openPuzzle(puzzle), isTrue);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        GameScreen(controller: controller, puzzle: puzzle),
        reason: 'game at ${size.width}x${size.height}',
      );
      expect(find.byType(PixelBackButton), findsOneWidget);
      expect(find.byType(PixelIconButton), findsAtLeastNWidgets(5));
      expect(find.text('Check progress'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
    }

    await controller.unlockEntireMap(ContentIds.originArc);
    final encounter = controller.originArc!.chapters.first.encounters.first;
    final encounterPuzzle = controller.originArc!.catalog.byId(
      encounter.puzzleId,
    );
    expect(controller.openPuzzle(encounterPuzzle), isTrue);
    _setViewSize(tester, _narrow);
    await _pumpScreen(
      tester,
      GameScreen(controller: controller, puzzle: encounterPuzzle),
      reason: 'encounter game at ${_narrow.width}x${_narrow.height}',
    );
    expect(find.byKey(const ValueKey('puzzle-enemy-sprite')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('puzzle-knight-sprite'))).size,
      const Size(90, 79),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('puzzle-enemy-sprite'))).size,
      const Size(111, 114),
    );
  });

  testWidgets('challenge setup remains responsive at both breakpoints', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        ChallengeScreen(controller: controller),
        reason: 'challenge setup at ${size.width}x${size.height}',
      );
      expect(find.byType(PixelBackButton), findsOneWidget);
      expect(find.byType(PixelIconButton), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('challenge-mode-mixed')),
        300,
        scrollable: find.byType(Scrollable),
      );
      _expectNoLayoutException(
        tester,
        reason: 'scrolled challenge setup at ${size.width}x${size.height}',
      );
    }
  });

  testWidgets('expanded story pages stay readable at both breakpoints', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        StorySceneScreen.chapter(
          controller: controller,
          chapter: controller.originArc!.chapters.last,
        ),
        reason: 'chapter story at ${size.width}x${size.height}',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Empyrean Citadel'), findsOneWidget);
      expect(find.byType(PixelStoryKnightSprite), findsNothing);
      expect(find.byType(PixelKnightSprite), findsNothing);
      final chapterArtSize = tester.getSize(find.byType(PixelStoryScene));
      expect(chapterArtSize.width, closeTo(chapterArtSize.height, .01));
      _expectNoLayoutException(
        tester,
        reason: 'chapter story text at ${size.width}x${size.height}',
      );

      await _pumpScreen(
        tester,
        StorySceneScreen.opening(controller: controller),
        reason: 'opening story at ${size.width}x${size.height}',
      );
      expect(find.byType(PixelStoryKnightSprite), findsOneWidget);
      expect(find.text('PROLOGUE · 1 of 3'), findsOneWidget);
      await tester.ensureVisible(find.text('See what happened'));
      await tester.tap(find.text('See what happened'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('PROLOGUE · 2 of 3'), findsOneWidget);
      _expectNoLayoutException(
        tester,
        reason: 'second prologue page at ${size.width}x${size.height}',
      );
    }
  });

  testWidgets('final chapter and finale tiles fit supported map sizes', (
    tester,
  ) async {
    final controller = await _initializedController(tester);
    final arc = controller.originArc!;
    await controller.markStoryBeatSeen(arc.openingScene.id);
    await controller.markStoryBeatSeen(arc.chapters.first.sceneId);
    await controller.unlockEntireMap(arc.id);
    controller.unlockedContentIds.add(arc.unlockIds.finale);
    _resetViewAfterTest(tester);

    for (final size in const [_narrow, _wide]) {
      _setViewSize(tester, size);
      await _pumpScreen(
        tester,
        JourneyScreen(
          key: ValueKey('journey-${size.width}'),
          controller: controller,
        ),
        reason: 'journey map at ${size.width}x${size.height}',
      );
      await tester.pump(const Duration(milliseconds: 500));

      final chapterTile = find.byKey(
        ValueKey('landmark-${arc.chapters.last.id}'),
      );
      await tester.ensureVisible(chapterTile);
      await tester.pump();
      final chapterRect = tester.getRect(chapterTile);
      expect(chapterRect.left, greaterThanOrEqualTo(0));
      expect(chapterRect.right, lessThanOrEqualTo(size.width));
      _expectNoLayoutException(
        tester,
        reason: 'final chapter tile at ${size.width}x${size.height}',
      );

      final finaleTile = find.byKey(const ValueKey('final-landmark'));
      await tester.ensureVisible(finaleTile);
      await tester.pump();
      final finaleRect = tester.getRect(finaleTile);
      expect(finaleRect.left, greaterThanOrEqualTo(0));
      expect(finaleRect.right, lessThanOrEqualTo(size.width));
      _expectNoLayoutException(
        tester,
        reason: 'finale tile at ${size.width}x${size.height}',
      );
    }
  });
}

Future<_TimerlessController> _initializedController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = _TimerlessController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required String reason,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
      home: screen,
    ),
  );
  await tester.pump();
  _expectNoLayoutException(tester, reason: reason);
}

void _setViewSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

void _resetViewAfterTest(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectNoLayoutException(WidgetTester tester, {required String reason}) {
  expect(tester.takeException(), isNull, reason: reason);
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
