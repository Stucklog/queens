@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
  });

  testWidgets('early Asterfall Vale route in midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 0);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(390, 844),
      file: 'goldens/journey_clovermead_midnight.png',
    );
  });

  testWidgets('Brasswake Arsenal panorama in portrait midnight theme', (
    tester,
  ) async {
    final controller = await _controllerAt(tester, completed: 45);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(430, 840),
      file: 'goldens/journey_underkeep_midnight.png',
    );
  });

  testWidgets('Empyrean Citadel route in narrow midnight theme', (
    tester,
  ) async {
    final controller = await _controllerAt(tester, completed: 63);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(390, 844),
      file: 'goldens/journey_crownspire_midnight.png',
    );
  });

  testWidgets('completed finale tile in narrow midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 72);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(390, 844),
      file: 'goldens/journey_finale_narrow_midnight.png',
    );
  });

  testWidgets('completed finale tile in wide midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 72);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(1180, 800),
      file: 'goldens/journey_finale_wide_midnight.png',
    );
  });

  testWidgets('opening story scene in midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 0);
    await _goldenStory(
      tester,
      controller: controller,
      scene: StorySceneScreen.opening(controller: controller),
      file: 'goldens/story_opening_midnight.png',
    );
  });

  testWidgets('finale story scene in midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 72);
    await _goldenStory(
      tester,
      controller: controller,
      scene: StorySceneScreen.finale(controller: controller),
      file: 'goldens/story_finale_midnight.png',
    );
  });

  testWidgets('chapter story scene in midnight theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 27);
    final chapter = controller.originArc!.chapters[3];
    await _goldenStory(
      tester,
      controller: controller,
      scene: StorySceneScreen.chapter(controller: controller, chapter: chapter),
      file: 'goldens/story_chapter_midnight.png',
      expectKnight: false,
    );
  });
}

Future<AppController> _controllerAt(
  WidgetTester tester, {
  required int completed,
}) async {
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  final reachedOrder = completed >= 72 ? 72 : completed + 1;
  final chapter = controller.originArc!.chapterForOrder(reachedOrder);
  await controller.markStoryBeatSeen(controller.originArc!.openingScene.id);
  await controller.markStoryBeatSeen(chapter.storyBeatId);
  for (final puzzle in controller.catalog!.puzzles.take(completed)) {
    controller.records[puzzle.id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
  }
  return controller;
}

Future<void> _goldenMap(
  WidgetTester tester, {
  required AppController controller,
  required Size size,
  required String file,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      home: RepaintBoundary(
        key: const ValueKey('journey-golden'),
        child: JourneyScreen(controller: controller),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await expectLater(
    find.byKey(const ValueKey('journey-golden')),
    matchesGoldenFile(file),
  );
}

Future<void> _goldenStory(
  WidgetTester tester, {
  required AppController controller,
  required Widget scene,
  required String file,
  bool expectKnight = true,
}) async {
  tester.view.physicalSize = const Size(430, 840);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      home: RepaintBoundary(key: const ValueKey('story-golden'), child: scene),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  expect(
    find.byType(PixelStoryKnightSprite),
    expectKnight ? findsOneWidget : findsNothing,
  );
  expect(
    find.byKey(const ValueKey('story-knight-artwork')),
    expectKnight ? findsOneWidget : findsNothing,
  );
  expect(find.byType(PixelKnightSprite), findsNothing);
  await expectLater(
    find.byKey(const ValueKey('story-golden')),
    matchesGoldenFile(file),
  );
}
