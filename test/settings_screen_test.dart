import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('map unlock requires irreversible-action confirmation', (
    tester,
  ) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SettingsScreen(controller: controller),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('unlock-entire-map')),
      300,
      scrollable: _settingsScroll(),
    );
    await tester.tap(find.byKey(const ValueKey('unlock-entire-map')));
    await tester.pump();

    expect(find.text('Unlock the entire map?'), findsOneWidget);
    expect(find.textContaining('can’t be reversed'), findsOneWidget);
    expect(controller.fullMapUnlocked, isFalse);

    await tester.tap(find.byKey(const ValueKey('confirm-unlock-map')));
    await tester.pump();
    await tester.runAsync(controller.flushPersistence);
    await tester.pump();

    expect(controller.fullMapUnlocked, isTrue);
    expect(find.text('Entire map unlocked'), findsOneWidget);
  });

  testWidgets('complete reset requires destructive-action confirmation', (
    tester,
  ) async {
    final controller = await _controller(tester);
    controller.updateSettings(controller.settings.copyWith(showTimer: false));
    await controller.unlockEntireMap();
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SettingsScreen(controller: controller),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('reset-entire-game')),
      300,
      scrollable: _settingsScroll(),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-entire-game')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reset-entire-game')));
    await tester.pump();

    expect(find.text('Completely reset the game?'), findsOneWidget);
    expect(find.textContaining('can’t be undone'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-reset-game')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.gameGeneration, 1);
    expect(controller.fullMapUnlocked, isFalse);
    expect(controller.settings.showTimer, isTrue);
  });

  testWidgets('complete reset reloads an existing app at the tutorial', (
    tester,
  ) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.runAsync(controller.resetGame);
    await tester.pump();

    expect(find.text('Welcome to Queen’s Regalia'), findsOneWidget);
  });
}

Finder _settingsScroll() =>
    find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;

Future<AppController> _controller(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
    'regalia.seenStoryBeats': ['opening', 'chapter.clovermead'],
  });
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
}
