import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/challenge_screen.dart';
import 'package:regalia/screens/home_screen.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:regalia/widgets/pixel_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home presents arc art, hero, puzzle-only, and master settings', (
    tester,
  ) async {
    final controller = await _controller(tester, openingSeen: true);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Queen’s Regalia: Origin Story'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('story-arc-tile-regalia:arc/origin')),
      findsOneWidget,
    );
    expect(find.byType(PixelLandscape), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-story-main-character')),
      findsOneWidget,
    );
    expect(find.text('Just Puzzle!'), findsOneWidget);
    expect(find.text('Master settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Master settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('selecting an unseen story opens its origin and then its map', (
    tester,
  ) async {
    final controller = await _controller(tester);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('story-arc-tile-regalia:arc/origin')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StorySceneScreen), findsOneWidget);
    expect(find.text('The Night of Crownfall'), findsOneWidget);

    await tester.tap(find.text('Take up the Regalia'));
    await tester.pumpAndSettle();
    expect(find.text('Press onward'), findsOneWidget);

    await tester.tap(find.text('Press onward'));
    await _pumpFrames(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
  });

  testWidgets('story and puzzle-only entries navigate independently', (
    tester,
  ) async {
    final controller = await _controller(tester, openingSeen: true);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('open-just-puzzle-home')));
    await _pumpFrames(tester);
    expect(find.byType(ChallengeScreen), findsOneWidget);
    expect(find.byType(JourneyScreen), findsNothing);

    await tester.tap(find.byType(PixelBackButton));
    await _pumpFrames(tester);
    await tester.tap(
      find.byKey(const ValueKey('story-arc-tile-regalia:arc/origin')),
    );
    await _pumpFrames(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppController> _controller(
  WidgetTester tester, {
  bool openingSeen = false,
}) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
    if (openingSeen)
      SaveIds.originSeenScenes: [
        ContentIds.originOpeningScene,
        'regalia:scene/origin/clovermead',
      ],
  });
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
}
