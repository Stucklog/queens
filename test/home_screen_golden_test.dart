@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
  });

  testWidgets('web story tiles remain readable at the narrow app width', (
    tester,
  ) async {
    await _expectHomeGolden(
      tester,
      size: const Size(390, 844),
      goldenKey: 'home-story-arcs-narrow-golden',
      file: 'goldens/home_story_arcs_narrow_midnight.png',
    );
  });

  testWidgets('web story tiles remain readable at the wide app width', (
    tester,
  ) async {
    await _expectHomeGolden(
      tester,
      size: const Size(600, 844),
      goldenKey: 'home-story-arcs-wide-golden',
      file: 'goldens/home_story_arcs_wide_midnight.png',
    );
  });
}

Future<void> _expectHomeGolden(
  WidgetTester tester, {
  required Size size,
  required String goldenKey,
  required String file,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = await _webControllerWithRealManifest(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: RepaintBoundary(
          key: ValueKey(goldenKey),
          child: HomeScreen(controller: controller),
        ),
      ),
    ),
  );
  await tester.pump();

  const originArcId = 'regalia:arc/origin';
  const atlasArcId = 'regalia:arc/atlas-of-borrowed-winds';
  expect(
    find.byKey(const ValueKey('story-arc-tile-$originArcId')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('story-arc-tile-$atlasArcId')),
    findsOneWidget,
  );

  await _precacheStoryTileAssets(tester, controller);
  await tester.pump();

  await expectLater(find.byKey(ValueKey(goldenKey)), matchesGoldenFile(file));
}

Future<void> _precacheStoryTileAssets(
  WidgetTester tester,
  AppController controller,
) async {
  final assets = <String>{
    for (final entry in controller.storyArcEntries)
      if (entry.descriptor case final descriptor?) ...[
        descriptor.storefront.tileArtAsset,
        if (descriptor.storefront.tileForegroundAsset case final foreground?)
          foreground,
      ],
  };
  final context = tester.element(find.byType(HomeScreen));
  await tester.runAsync(
    () => Future.wait([
      for (final asset in assets) precacheImage(AssetImage(asset), context),
    ]),
  );
}

Future<AppController> _webControllerWithRealManifest(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    SaveIds.originOnboardingPending: false,
    'regalia.journeySchemaVersion': 1,
    SaveIds.originSeenScenes: [
      ContentIds.originOpeningScene,
      'regalia:scene/origin/clovermead',
    ],
  });
  final controller = AppController(
    contentPolicy: const ContentEntitlementPolicy.web(),
    contentAssetReader: (path) => File(path).readAsString(),
  );
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
}
