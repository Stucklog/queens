import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/models.dart';
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
    expect(
      find.byType(PixelLandscape),
      findsNWidgets(controller.availableStoryArcs.length),
    );
    expect(
      find.byKey(const ValueKey('home-story-main-character')),
      findsNWidgets(controller.availableStoryArcs.length),
    );
    expect(find.byKey(const ValueKey('open-master-settings')), findsOneWidget);
    final homeScroll = find.descendant(
      of: find.byKey(const ValueKey('home-content-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('open-just-puzzle-home')),
      240,
      scrollable: homeScroll,
    );
    expect(find.text('Just Puzzle!'), findsOneWidget);

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
    expect(find.text('The Stolen Dawn'), findsOneWidget);

    await tester.ensureVisible(find.text('See what happened'));
    await tester.tap(find.text('See what happened'));
    await tester.pumpAndSettle();
    expect(find.text('The Falling Crown'), findsOneWidget);

    await tester.ensureVisible(find.text('Follow the crown'));
    await tester.tap(find.text('Follow the crown'));
    await tester.pumpAndSettle();
    expect(find.text('The Knight’s Choice'), findsOneWidget);

    await tester.ensureVisible(find.text('Begin the journey'));
    await tester.tap(find.text('Begin the journey'));
    await tester.pumpAndSettle();
    expect(find.text('Enter Asterfall'), findsOneWidget);

    await tester.ensureVisible(find.text('Enter Asterfall'));
    await tester.tap(find.text('Enter Asterfall'));
    await _pumpFrames(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
  });

  testWidgets('story and puzzle-only entries navigate independently', (
    tester,
  ) async {
    final controller = await _controller(tester, openingSeen: true);
    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();

    final puzzleOnly = find.byKey(const ValueKey('open-just-puzzle-home'));
    await tester.scrollUntilVisible(
      puzzleOnly,
      240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home-content-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(puzzleOnly);
    await _pumpFrames(tester);
    expect(find.byType(ChallengeScreen), findsOneWidget);
    expect(find.byType(JourneyScreen), findsNothing);

    await tester.tap(find.byType(PixelBackButton));
    await _pumpFrames(tester);
    final origin = find.byKey(
      const ValueKey('story-arc-tile-regalia:arc/origin'),
    );
    await tester.scrollUntilVisible(
      origin,
      -240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home-content-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.descendant(
        of: find.byKey(const ValueKey('home-content-list')),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, 120),
    );
    await tester.pump();
    await tester.tap(origin);
    await _pumpFrames(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
  });

  testWidgets('first prologue Back returns Home without changing story state', (
    tester,
  ) async {
    final controller = await _controller(tester);
    final recordsBefore = Map<String, CompletionRecord>.of(controller.records);
    final scenesBefore = Set<String>.of(controller.seenStoryBeatIds);
    final unlocksBefore = Set<String>.of(controller.unlockedContentIds);

    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    final origin = find.byKey(
      const ValueKey('story-arc-tile-regalia:arc/origin'),
    );
    await tester.tap(origin);
    await _pumpFrames(tester);

    expect(find.byType(StorySceneScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('story-prologue-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('story-prologue-back')));
    await _pumpFrames(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(JourneyScreen), findsNothing);
    expect(controller.records, recordsBefore);
    expect(controller.seenStoryBeatIds, scenesBefore);
    expect(controller.unlockedContentIds, unlocksBefore);

    await tester.tap(origin);
    await _pumpFrames(tester);
    expect(find.text('PROLOGUE · 1 of 3'), findsOneWidget);
    expect(find.text('The Stolen Dawn'), findsOneWidget);
  });

  testWidgets(
    'web previews the real Atlas arc without reading full story data',
    (tester) async {
      final reads = <String>[];
      final launches = <Uri>[];
      var throwOnLaunch = false;
      final controller = await _webControllerWithRealManifest(tester, reads);
      await tester.pumpWidget(
        RegaliaApp(
          controller: controller,
          externalUrlLauncher: (uri) async {
            launches.add(uri);
            if (throwOnLaunch) throw StateError('store unavailable');
            return true;
          },
        ),
      );
      await tester.pump();

      const arcId = 'regalia:arc/atlas-of-borrowed-winds';
      const openingId = 'regalia:scene/atlas-of-borrowed-winds/opening';
      expect(find.text('The Atlas of Borrowed Winds'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-arc-tile-$arcId')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('locked-story-$arcId')), findsOneWidget);
      expect(
        reads,
        isNot(contains('assets/content/arcs/atlas-of-borrowed-winds/arc.json')),
      );

      await tester.tap(find.byKey(const ValueKey('story-arc-tile-$arcId')));
      await _pumpFrames(tester);
      expect(find.text('A Trapped Caravan'), findsOneWidget);

      for (final transition in const [
        ('Open the atlas', 'The Bound Jinn'),
        ('Make the rescue', 'The Cost of Rescue'),
      ]) {
        await tester.ensureVisible(find.text(transition.$1));
        await tester.tap(find.text(transition.$1));
        await _pumpFrames(tester);
        expect(find.text(transition.$2), findsOneWidget);
      }

      await tester.ensureVisible(find.text('Begin the atlas journey'));
      await tester.tap(find.text('Begin the atlas journey'));
      await _pumpFrames(tester);
      expect(
        find.byKey(const ValueKey('apps-only-story-dialog')),
        findsOneWidget,
      );
      expect(controller.hasSeenStoryBeat(openingId), isFalse);
      expect(
        reads.where(
          (path) =>
              path.startsWith('assets/content/arcs/atlas-of-borrowed-winds/'),
        ),
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('open-app-store')));
      await tester.pump();
      expect(launches, [Uri.parse('https://apps.apple.com/')]);

      throwOnLaunch = true;
      await tester.tap(find.byKey(const ValueKey('open-play-store')));
      await tester.pump();
      expect(launches.last, Uri.parse('https://play.google.com/store/apps'));
      expect(find.text('Could not open Google Play.'), findsOneWidget);
    },
  );

  testWidgets(
    'web shows a locked manifest tile, previews it, then links to the apps',
    (tester) async {
      final reads = <String>[];
      final controller = await _webControllerWithLockedArc(tester, reads);
      await tester.pumpWidget(RegaliaApp(controller: controller));
      await tester.pump();

      expect(find.text('The Moon Court'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('story-arc-tile-regalia:arc/moon-court')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('locked-story-regalia:arc/moon-court')),
        findsOneWidget,
      );
      expect(reads, isNot(contains('must-not-load.json')));

      await tester.tap(
        find.byKey(const ValueKey('story-arc-tile-regalia:arc/moon-court')),
      );
      await _pumpFrames(tester);
      expect(find.byType(StorySceneScreen), findsOneWidget);
      expect(find.text('A Moonless Welcome'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _pumpFrames(tester);
      expect(find.text('Behind the Silver Gate'), findsOneWidget);
      await tester.ensureVisible(find.text('View the apps'));
      await tester.tap(find.text('View the apps'));
      await _pumpFrames(tester);

      expect(
        find.byKey(const ValueKey('apps-only-story-dialog')),
        findsOneWidget,
      );
      expect(find.text('Continue in the app'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-app-store')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-play-store')), findsOneWidget);
      expect(
        controller.hasSeenStoryBeat(
          'regalia:scene/moon-court/storefront-prologue',
        ),
        isFalse,
      );
      expect(reads, isNot(contains('must-not-load.json')));
    },
  );
}

Future<AppController> _webControllerWithRealManifest(
  WidgetTester tester,
  List<String> reads,
) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
    SaveIds.originSeenScenes: [
      ContentIds.originOpeningScene,
      'regalia:scene/origin/clovermead',
    ],
  });
  final controller = AppController(
    contentPolicy: const ContentEntitlementPolicy.web(),
    contentAssetReader: (path) async {
      reads.add(path);
      return File(path).readAsString();
    },
  );
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
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

Future<AppController> _webControllerWithLockedArc(
  WidgetTester tester,
  List<String> reads,
) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
    SaveIds.originSeenScenes: [
      ContentIds.originOpeningScene,
      'regalia:scene/origin/clovermead',
    ],
  });
  final manifestSource = await tester.runAsync(
    () => File('assets/content/manifest.json').readAsString(),
  );
  final manifest = jsonDecode(manifestSource!) as Map<String, Object?>;
  final arcs = (manifest['arcs']! as List<Object?>).toList();
  arcs.removeWhere(
    (entry) =>
        (entry! as Map<String, Object?>)['arcId'] != ContentIds.originArc,
  );
  arcs.add({
    'arcId': 'regalia:arc/moon-court',
    'metadataAsset': 'must-not-load.json',
    'entitlementId': 'regalia:entitlement/paid/moon-court',
    'channels': ['paidPlatform'],
    'lockedPreviewChannels': ['web'],
    'storefront': {
      'title': 'The Moon Court',
      'tileSubtitle': 'Enter the silver court',
      'lockedTileSubtitle': 'Preview the prologue',
      'tileArtAsset': 'assets/art/backgrounds/story_opening.webp',
      'theme': {
        'backgroundColor': '#21152f',
        'surfaceColor': '#39234c',
        'primaryColor': '#8567a8',
        'secondaryColor': '#e5bd6b',
      },
      'prologuePreview': {
        'id': 'regalia:scene/moon-court/storefront-prologue',
        'role': 'opening',
        'pages': [
          {
            'title': 'A Moonless Welcome',
            'paragraphs': [
              'The silver court closes its gates as a second crown appears above the city.',
            ],
            'semanticLabel': 'A silver city beneath a moonless sky.',
            'actionLabel': 'Continue',
          },
          {
            'title': 'Behind the Silver Gate',
            'paragraphs': [
              'The deeper story continues in the complete app alongside every other arc.',
            ],
            'semanticLabel': 'Two figures wait behind a silver gate.',
            'actionLabel': 'View the apps',
          },
        ],
        'artAsset': 'assets/art/backgrounds/story_opening.webp',
      },
    },
  });
  manifest['arcs'] = arcs;

  final controller = AppController(
    contentManifestAsset: 'test-manifest.json',
    contentPolicy: const ContentEntitlementPolicy.web(),
    contentAssetReader: (path) async {
      reads.add(path);
      if (path == 'test-manifest.json') return jsonEncode(manifest);
      final file = File(path);
      if (await file.exists()) return file.readAsString();
      throw StateError('$path not found');
    },
  );
  await tester.runAsync(controller.initialize);
  addTearDown(controller.dispose);
  return controller;
}
