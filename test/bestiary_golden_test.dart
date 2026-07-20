@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/bestiary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
  });

  testWidgets('revealed and hidden foes read clearly on a narrow screen', (
    tester,
  ) async {
    final controller = await _controllerWithDiscoveries(tester);
    addTearDown(controller.dispose);
    await _pumpBestiary(
      tester,
      controller: controller,
      size: const Size(390, 844),
      goldenKey: 'bestiary-narrow-golden',
    );

    await expectLater(
      find.byKey(const ValueKey('bestiary-narrow-golden')),
      matchesGoldenFile('goldens/bestiary_narrow_midnight.png'),
    );
  });

  testWidgets('arc chapters form two readable columns on a wide screen', (
    tester,
  ) async {
    final controller = await _controllerWithDiscoveries(tester);
    addTearDown(controller.dispose);
    await _pumpBestiary(
      tester,
      controller: controller,
      size: const Size(600, 844),
      goldenKey: 'bestiary-wide-golden',
    );

    await expectLater(
      find.byKey(const ValueKey('bestiary-wide-golden')),
      matchesGoldenFile('goldens/bestiary_wide_midnight.png'),
    );
  });

  testWidgets('foe study keeps all six replay controls visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controllerWithDiscoveries(tester);
    addTearDown(controller.dispose);
    final chapter = controller.originArc!.chapters.first;
    final encounter = chapter.encounters.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.forChapter(chapter),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: RepaintBoundary(
            key: const ValueKey('bestiary-detail-golden'),
            child: BestiaryFoeScreen(encounter: encounter, chapter: chapter),
          ),
        ),
      ),
    );
    await _precache(tester, [encounter.spriteAsset]);

    await expectLater(
      find.byKey(const ValueKey('bestiary-detail-golden')),
      matchesGoldenFile('goldens/bestiary_detail_narrow_midnight.png'),
    );
  });
}

Future<AppController> _controllerWithDiscoveries(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  final arc = controller.originArc!;
  controller.records[arc
      .chapters
      .first
      .encounters
      .first
      .puzzleId] = const CompletionRecord(status: CompletionStatus.cleanSolved);
  controller.records[arc.chapters.first.boss.puzzleId] = const CompletionRecord(
    status: CompletionStatus.assistedSolved,
  );
  controller.records[arc
      .chapters[1]
      .encounters
      .last
      .puzzleId] = const CompletionRecord(status: CompletionStatus.cleanSolved);
  return controller;
}

Future<void> _pumpBestiary(
  WidgetTester tester, {
  required AppController controller,
  required Size size,
  required String goldenKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final arc = controller.originArc!;
  final revealedAssets = [
    arc.chapters.first.encounters.first.spriteAsset,
    arc.chapters.first.boss.spriteAsset,
    arc.chapters[1].encounters.last.spriteAsset,
  ];

  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: RepaintBoundary(
          key: ValueKey(goldenKey),
          child: BestiaryScreen(controller: controller),
        ),
      ),
    ),
  );
  await _precache(tester, revealedAssets);
}

Future<void> _precache(WidgetTester tester, Iterable<String> assets) async {
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(
    () => Future.wait([
      for (final asset in assets) precacheImage(AssetImage(asset), context),
    ]),
  );
  await tester.pump();
}
