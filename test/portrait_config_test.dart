import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('mobile and web platforms declare portrait orientation', () {
    final android =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final web = File('web/manifest.json').readAsStringSync();

    expect(android, contains('android:screenOrientation="portrait"'));
    expect(ios, contains('UIInterfaceOrientationPortrait'));
    expect(ios, isNot(contains('UIInterfaceOrientationLandscape')));
    expect(web, contains('"orientation": "portrait-primary"'));
  });

  test('desktop runners open with portrait geometry', () {
    expect(
      File('windows/runner/main.cpp').readAsStringSync(),
      contains('Win32Window::Size size(430, 760)'),
    );
    final linux = File('linux/runner/my_application.cc').readAsStringSync();
    expect(linux, contains('gtk_window_set_default_size(window, 430, 760)'));
    expect(linux, contains('GDK_HINT_ASPECT'));
    final macos =
        File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
    expect(macos, contains('NSSize(width: 430, height: 760)'));
    expect(macos, contains('contentAspectRatio'));
  });

  testWidgets('a landscape host renders the app in a portrait shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'regalia.tutorialComplete': true,
      'regalia.journeySchemaVersion': 1,
      'regalia.seenStoryBeats': <String>[
        StoryBeatIds.opening,
        journeyChapters.first.storyBeatId,
      ],
    });
    final controller = AppController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);

    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 500));

    final size = tester.getSize(find.byType(HomeScreen));
    expect(size.width, closeTo(434, .1));
    expect(size.height, 700);
    expect(size.width, lessThan(size.height));
    expect(tester.takeException(), isNull);
  });
}
