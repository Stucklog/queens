import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:regalia/widgets/support_developer.dart';
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

    expect(find.byKey(const ValueKey('unlock-entire-map')), findsNothing);
    final arcSettings = find.byKey(
      const ValueKey('story-arc-settings-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      arcSettings,
      300,
      scrollable: _settingsScroll(),
    );
    await tester.tap(arcSettings);
    await tester.pumpAndSettle();

    final unlockMap = find.byKey(
      const ValueKey('unlock-entire-map-regalia:arc/origin'),
    );
    await tester.tap(unlockMap);
    await tester.pump();

    expect(
      find.text('Unlock Queen’s Regalia: Origin Story map?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Other story arcs are not affected'),
      findsOneWidget,
    );
    expect(controller.fullMapUnlocked, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('confirm-unlock-map-regalia:arc/origin')),
    );
    await tester.pump();
    await tester.runAsync(controller.flushPersistence);
    await tester.pump();

    expect(controller.fullMapUnlocked, isTrue);
    expect(find.text('This arc’s map is unlocked'), findsOneWidget);
  });

  testWidgets('map unlock keeps the finale gated by the final boss', (
    tester,
  ) async {
    final controller = await _controller(tester);
    final arc = controller.originArc!;
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: StoryArcSettingsScreen(controller: controller, arc: arc),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('unlock-entire-map-regalia:arc/origin')),
    );
    await tester.pump();
    expect(
      find.textContaining('The finale remains locked until the final boss'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-unlock-map-regalia:arc/origin')),
    );
    await tester.pump();
    await tester.runAsync(controller.flushPersistence);
    await tester.pump();

    final finalBoss = arc.catalog.byId(arc.chapters.last.boss.puzzleId);
    expect(controller.isMapUnlocked(arc.id), isTrue);
    expect(controller.canOpenPuzzle(finalBoss), isTrue);
    expect(controller.isFinaleUnlocked(arc.id), isFalse);
    expect(find.textContaining('Defeat the final boss'), findsOneWidget);
  });

  testWidgets('complete reset requires two destructive-action warnings', (
    tester,
  ) async {
    final controller = await _controller(tester);
    controller.updateSettings(controller.settings.copyWith(showTimer: false));
    await controller.unlockEntireMap(ContentIds.originArc);
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

    expect(find.text('Reset all game data?'), findsOneWidget);
    expect(find.textContaining('one final warning'), findsOneWidget);
    expect(controller.gameGeneration, 0);

    await tester.tap(find.byKey(const ValueKey('confirm-reset-game-first')));
    await tester.pump();

    expect(find.text('Final warning: erase everything?'), findsOneWidget);
    expect(find.textContaining('can’t be undone'), findsOneWidget);
    expect(controller.gameGeneration, 0);

    await tester.tap(find.byKey(const ValueKey('confirm-reset-game-final')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.gameGeneration, 1);
    expect(controller.fullMapUnlocked, isFalse);
    expect(controller.settings.showTimer, isTrue);
  });

  testWidgets('story arc reset preserves master and puzzle-only data', (
    tester,
  ) async {
    final controller = await _controller(tester);
    controller.updateSettings(controller.settings.copyWith(showTimer: false));
    final puzzle = controller.catalog!.puzzles.first;
    controller.openPuzzle(puzzle);
    controller.cycle(puzzle, const Cell(0, 0));
    await controller.unlockEntireMap(ContentIds.originArc);
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SettingsScreen(controller: controller),
      ),
    );

    final arcSettings = find.byKey(
      const ValueKey('story-arc-settings-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      arcSettings,
      300,
      scrollable: _settingsScroll(),
    );
    await tester.tap(arcSettings);
    await tester.pumpAndSettle();

    final resetArc = find.byKey(
      const ValueKey('reset-story-arc-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      resetArc,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(resetArc);
    await tester.pump();

    expect(find.text('Reset Queen’s Regalia: Origin Story?'), findsOneWidget);
    expect(
      find.textContaining('all other story arcs are preserved'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-reset-arc-regalia:arc/origin')),
    );
    await tester.pump();
    await tester.runAsync(controller.flushPersistence);

    expect(controller.boards, isEmpty);
    expect(controller.records, isEmpty);
    expect(controller.seenStoryBeatIds, isEmpty);
    expect(controller.fullMapUnlocked, isFalse);
    expect(controller.settings.showTimer, isFalse);
    expect(controller.tutorialComplete, isTrue);
    expect(controller.challengeSession, isNull);
  });

  testWidgets('complete reset reloads an existing app at the tutorial', (
    tester,
  ) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.byTooltip('Master settings'), findsOneWidget);

    await tester.runAsync(controller.resetGame);
    await tester.pump();

    expect(find.text('Welcome to Queen’s Regalia'), findsOneWidget);
  });

  testWidgets('master and story arc settings expose the support link', (
    tester,
  ) async {
    final controller = await _controller(tester);
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SettingsScreen(
          controller: controller,
          externalUrlLauncher: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );

    final masterSupport = find.byKey(const ValueKey('master-settings-support'));
    await tester.scrollUntilVisible(
      masterSupport,
      300,
      scrollable: _settingsScroll(),
    );
    final masterSupportButton = find.descendant(
      of: masterSupport,
      matching: find.byKey(const ValueKey('open-buy-me-a-coffee')),
    );
    await tester.scrollUntilVisible(
      masterSupportButton,
      100,
      scrollable: _settingsScroll(),
    );
    await tester.ensureVisible(masterSupportButton);
    await tester.pump();
    await tester.tap(masterSupportButton);
    await tester.pump();
    expect(launched, [buyMeACoffeeUri]);

    final arcSettings = find.byKey(
      const ValueKey('story-arc-settings-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      arcSettings,
      -300,
      scrollable: _settingsScroll(),
    );
    await tester.tap(arcSettings);
    await tester.pumpAndSettle();

    final arcSupport = find.byKey(
      const ValueKey('story-arc-settings-support-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      arcSupport,
      300,
      scrollable: find.byType(Scrollable),
    );
    final arcSupportButton = find.descendant(
      of: arcSupport,
      matching: find.byKey(const ValueKey('open-buy-me-a-coffee')),
    );
    await tester.scrollUntilVisible(
      arcSupportButton,
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.ensureVisible(arcSupportButton);
    await tester.pump();
    await tester.tap(arcSupportButton);
    await tester.pump();
    expect(launched, [buyMeACoffeeUri, buyMeACoffeeUri]);
  });

  testWidgets('support launch failure is nonfatal and explained', (
    tester,
  ) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SettingsScreen(
          controller: controller,
          externalUrlLauncher: (_) async => false,
        ),
      ),
    );
    final support = find.byKey(const ValueKey('master-settings-support'));
    await tester.scrollUntilVisible(
      support,
      300,
      scrollable: _settingsScroll(),
    );
    final supportButton = find.descendant(
      of: support,
      matching: find.byKey(const ValueKey('open-buy-me-a-coffee')),
    );
    await tester.scrollUntilVisible(
      supportButton,
      100,
      scrollable: _settingsScroll(),
    );
    await tester.ensureVisible(supportButton);
    await tester.pump();
    await tester.tap(supportButton);
    await tester.pump();

    expect(find.text('Could not open the support page.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
