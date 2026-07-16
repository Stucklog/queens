@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaSans')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader('RegaliaDisplay')..addFont(
      rootBundle.load('assets/fonts/RobotoCondensed-Bold.ttf'),
    )).load();
    var directory = File(Platform.resolvedExecutable).parent;
    late File materialIcons;
    do {
      materialIcons = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      directory = directory.parent;
    } while (!materialIcons.existsSync() &&
        directory.parent.path != directory.path);
    final iconBytes = await materialIcons.readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)))).load();
  });

  testWidgets('early Clovermead route in light theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 0);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(390, 844),
      mode: ThemeMode.light,
      file: 'goldens/journey_clovermead_light.png',
    );
  });

  testWidgets('Goblin Underkeep panorama in portrait dark theme', (
    tester,
  ) async {
    final controller = await _controllerAt(tester, completed: 80);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(430, 840),
      mode: ThemeMode.dark,
      file: 'goldens/journey_underkeep_dark.png',
    );
  });

  testWidgets('Crownspire route in narrow dark theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 100);
    await _goldenMap(
      tester,
      controller: controller,
      size: const Size(390, 844),
      mode: ThemeMode.dark,
      file: 'goldens/journey_crownspire_dark.png',
    );
  });

  testWidgets('opening story scene in light theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 0);
    await _goldenStory(
      tester,
      controller: controller,
      scene: StorySceneScreen.opening(controller: controller),
      mode: ThemeMode.light,
      file: 'goldens/story_opening_light.png',
    );
  });

  testWidgets('finale story scene in dark theme', (tester) async {
    final controller = await _controllerAt(tester, completed: 120);
    await _goldenStory(
      tester,
      controller: controller,
      scene: StorySceneScreen.finale(controller: controller),
      mode: ThemeMode.dark,
      file: 'goldens/story_finale_dark.png',
    );
  });
}

Future<AppController> _controllerAt(
  WidgetTester tester, {
  required int completed,
}) async {
  final reachedOrder = completed >= 120 ? 120 : completed + 1;
  final chapter = chapterForOrder(reachedOrder);
  SharedPreferences.setMockInitialValues({
    'regalia.tutorialComplete': true,
    'regalia.journeySchemaVersion': 1,
    'regalia.seenStoryBeats': <String>[
      StoryBeatIds.opening,
      chapter.storyBeatId,
    ],
  });
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
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
  required ThemeMode mode,
  required String file,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.light(),
      darkTheme: RegaliaTheme.dark(),
      themeMode: mode,
      home: RepaintBoundary(
        key: const ValueKey('journey-golden'),
        child: JourneyScreen(controller: controller),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byKey(const ValueKey('journey-golden')),
    matchesGoldenFile(file),
  );
}

Future<void> _goldenStory(
  WidgetTester tester, {
  required AppController controller,
  required Widget scene,
  required ThemeMode mode,
  required String file,
}) async {
  tester.view.physicalSize = const Size(430, 840);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.light(),
      darkTheme: RegaliaTheme.dark(),
      themeMode: mode,
      home: RepaintBoundary(key: const ValueKey('story-golden'), child: scene),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byKey(const ValueKey('story-golden')),
    matchesGoldenFile(file),
  );
}
