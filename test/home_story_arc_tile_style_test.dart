import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _originArcId = 'regalia:arc/origin';
const _atlasArcId = 'regalia:arc/atlas-of-borrowed-winds';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('story tiles outline light and dark manifest text for contrast', (
    tester,
  ) async {
    final controller = await _webControllerWithRealManifest(tester);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();

    _expectOutlinedText(
      tester,
      find.byKey(const ValueKey('story-arc-title-$_originArcId')),
      foreground: Colors.white,
      outline: Colors.black,
      descendant: true,
    );
    _expectOutlinedText(
      tester,
      find.byKey(const ValueKey('story-arc-subtitle-$_originArcId')),
      foreground: Colors.white,
      outline: Colors.black,
    );
    _expectOutlinedText(
      tester,
      find.byKey(const ValueKey('story-arc-title-$_atlasArcId')),
      foreground: Colors.black,
      outline: Colors.white,
      descendant: true,
    );
    _expectOutlinedText(
      tester,
      find.byKey(const ValueKey('story-arc-subtitle-$_atlasArcId')),
      foreground: Colors.black,
      outline: Colors.white,
    );
  });
}

void _expectOutlinedText(
  WidgetTester tester,
  Finder keyedFinder, {
  required Color foreground,
  required Color outline,
  bool descendant = false,
}) {
  final textFinder =
      descendant
          ? find.descendant(of: keyedFinder, matching: find.byType(Text))
          : keyedFinder;
  final text = tester.widget<Text>(textFinder);
  expect(text.style?.color, foreground);
  expect(text.style?.shadows, hasLength(8));
  expect(text.style!.shadows!.map((shadow) => shadow.color).toSet(), {outline});
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
