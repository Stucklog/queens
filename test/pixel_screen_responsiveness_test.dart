import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/screens/challenge_screen.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/screens/rules_screen.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:regalia/screens/tutorial_screen.dart';
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
