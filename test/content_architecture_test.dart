import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/challenge.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/challenge_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const futureArc = 'regalia:arc/moon-court';
  const futureEntitlement = 'regalia:entitlement/paid/moon-court';

  Map<String, Object?> storefrontFor(String arcId, String title) {
    final arcName = ContentId.parse(arcId, expectedKind: 'arc').localName;
    return {
      'title': title,
      'tileSubtitle': 'Begin the story',
      'lockedTileSubtitle': 'Preview the prologue',
      'tileArtAsset': 'assets/art/backgrounds/story_opening.webp',
      'theme': {
        'backgroundColor': '#10182a',
        'surfaceColor': '#202d46',
        'primaryColor': '#634f91',
        'secondaryColor': '#d7a85b',
      },
      'prologuePreview': {
        'id': 'regalia:scene/$arcName/storefront-prologue',
        'role': 'opening',
        'pages': [
          {
            'title': '$title Prologue',
            'paragraphs': [
              'A lightweight opening page introduces the central conflict before the full story package is loaded by the installed edition.',
              'Its cast, artwork, and narrative remain available as a deliberately small storefront preview on the web edition.',
            ],
            'semanticLabel': 'A preview of $title.',
            'actionLabel': 'Continue',
          },
          {
            'title': 'The Journey Ahead',
            'paragraphs': [
              'The road beyond the prologue leads into chapters, encounters, and a finale stored inside the platform-specific package.',
              'Those deeper story records stay unread on the web while the complete paid application can continue the journey.',
            ],
            'semanticLabel': 'A road leading toward the next story.',
            'actionLabel': 'View the apps',
          },
        ],
        'artAsset': 'assets/art/backgrounds/story_opening.webp',
      },
    };
  }

  Future<Map<String, String>> assetsFor({
    required List<String> futureChannels,
    List<String> futureLockedPreviewChannels = const ['web'],
    String? futureMetadata,
  }) async {
    final assets = <String, String>{
      'origin.json':
          await File('assets/content/arcs/origin/arc.json').readAsString(),
      'catalog.json': await File('assets/puzzles/catalog.json').readAsString(),
    };
    if (futureMetadata != null) assets['future.json'] = futureMetadata;
    assets['manifest.json'] = jsonEncode({
      'schemaVersion': 1,
      'features': [ContentIds.justPuzzleFeature],
      'storeLinks': {
        'appStore': 'https://apps.apple.com/example',
        'playStore': 'https://play.google.com/store/apps/example',
      },
      'arcs': [
        {
          'arcId': ContentIds.originArc,
          'metadataAsset': 'origin.json',
          'entitlementId': ContentIds.originEntitlement,
          'channels': ['web', 'paidPlatform'],
          'storefront': storefrontFor(
            ContentIds.originArc,
            'Queen’s Regalia: Origin Story',
          ),
        },
        {
          'arcId': futureArc,
          'metadataAsset': 'future.json',
          'entitlementId': futureEntitlement,
          'channels': futureChannels,
          'lockedPreviewChannels': futureLockedPreviewChannels,
          'storefront': storefrontFor(futureArc, 'The Moon Court'),
        },
      ],
    });
    return assets;
  }

  ContentRepository repository(
    Map<String, String> assets, {
    List<String>? reads,
  }) => ContentRepository(
    readAsset: (path) async {
      reads?.add(path);
      if (path == 'assets/puzzles/catalog.json') {
        return assets['catalog.json']!;
      }
      if (!assets.containsKey(path)) throw StateError('$path not found');
      return assets[path]!;
    },
  );

  test('web is origin plus Just Puzzle and excludes paid arcs', () async {
    final assets = await assetsFor(futureChannels: ['paidPlatform']);
    final reads = <String>[];
    final registry = await repository(assets, reads: reads).load(
      manifestAsset: 'manifest.json',
      policy: const ContentEntitlementPolicy.web(),
    );

    expect(registry.arc(ContentIds.originArc), isNotNull);
    expect(registry.justPuzzleAvailable, isTrue);
    expect(
      registry.availabilityFor(futureArc).status,
      ContentAvailabilityStatus.notInEdition,
    );
    expect(reads, isNot(contains('future.json')));
    expect(
      registry.arcEntries.map((entry) => entry.descriptor!.arcId),
      orderedEquals([ContentIds.originArc, futureArc]),
    );
    expect(
      registry.availabilityFor(futureArc).storefront!.prologuePreview.pages,
      hasLength(2),
    );
    expect(
      registry.storefrontLinks!.appStore,
      Uri.parse('https://apps.apple.com/example'),
    );
    expect(
      registry
          .arc(ContentIds.originArc)!
          .catalog
          .puzzles
          .every((puzzle) => ContentId.isValid(puzzle.id, kind: 'puzzle')),
      isTrue,
    );
  });

  test(
    'manifest channels can make an additional arc available on web',
    () async {
      final originMetadata =
          await File('assets/content/arcs/origin/arc.json').readAsString();
      final originCatalog =
          await File('assets/puzzles/catalog.json').readAsString();
      final futureMetadata = originMetadata
          .replaceAll(ContentIds.originArc, futureArc)
          .replaceAll('/origin/', '/moon-court/')
          .replaceAll('"Queen’s Regalia: Origin Story"', '"The Moon Court"')
          .replaceAll('assets/puzzles/catalog.json', 'future-catalog.json');
      final assets = await assetsFor(
        futureChannels: ['web'],
        futureLockedPreviewChannels: const [],
        futureMetadata: futureMetadata,
      );
      assets['future-catalog.json'] = originCatalog.replaceAll(
        '/origin/',
        '/moon-court/',
      );

      final registry = await repository(assets).load(
        manifestAsset: 'manifest.json',
        policy: const ContentEntitlementPolicy.web(),
      );

      expect(registry.arc(ContentIds.originArc), isNotNull);
      expect(registry.arc(futureArc), isNotNull);
      expect(registry.availableArcs, hasLength(2));
    },
  );

  test(
    'origin cinematics carry readable paged narrative and final art',
    () async {
      final assets = await assetsFor(futureChannels: ['paidPlatform']);
      final registry = await repository(assets).load(
        manifestAsset: 'manifest.json',
        policy: const ContentEntitlementPolicy.web(),
      );
      final arc = registry.arc(ContentIds.originArc)!;

      expect(arc.openingScene.pages, hasLength(greaterThan(1)));
      expect(arc.finaleScene.pages, hasLength(greaterThan(1)));
      expect(
        arc.scenes
            .where((scene) => scene.role == StorySceneRole.chapter)
            .every((scene) => scene.pages.length == 1),
        isTrue,
      );
      expect(
        arc.scenes
            .expand((scene) => scene.pages)
            .every(
              (page) =>
                  page.paragraphs.length >= 2 &&
                  page.paragraphs.every((paragraph) => paragraph.length >= 80),
            ),
        isTrue,
      );
      expect(
        arc.chapters.last.artAsset,
        'assets/art/backgrounds/chapter_crownspire_final.png',
      );
      expect(
        arc.sceneById(arc.chapters.last.sceneId).artAsset,
        arc.chapters.last.artAsset,
      );
      expect(
        arc.chapters.every((chapter) => chapter.mapLayout.columns > 0),
        isTrue,
      );
    },
  );

  test(
    'paid edition attempts packaged arcs without per-arc entitlements',
    () async {
      final assets = await assetsFor(futureChannels: ['paidPlatform']);
      final registry = await repository(assets).load(
        manifestAsset: 'manifest.json',
        policy: const ContentEntitlementPolicy.paidPlatform(),
      );

      expect(
        registry.availabilityFor(futureArc).status,
        ContentAvailabilityStatus.missingPackage,
      );
      expect(registry.arc(ContentIds.originArc), isNotNull);
      expect(registry.justPuzzleAvailable, isTrue);
    },
  );

  test(
    'paid edition loads an additional valid arc without entitlements',
    () async {
      final originMetadata =
          await File('assets/content/arcs/origin/arc.json').readAsString();
      final originCatalog =
          await File('assets/puzzles/catalog.json').readAsString();
      final futureMetadata = originMetadata
          .replaceAll(ContentIds.originArc, futureArc)
          .replaceAll('/origin/', '/moon-court/')
          .replaceAll('"Queen’s Regalia: Origin Story"', '"The Moon Court"')
          .replaceAll('assets/puzzles/catalog.json', 'future-catalog.json');
      final assets = await assetsFor(
        futureChannels: ['paidPlatform'],
        futureMetadata: futureMetadata,
      );
      assets['future-catalog.json'] = originCatalog.replaceAll(
        '/origin/',
        '/moon-court/',
      );
      final registry = await repository(assets).load(
        manifestAsset: 'manifest.json',
        policy: const ContentEntitlementPolicy.paidPlatform(),
      );

      expect(registry.arc(ContentIds.originArc), isNotNull);
      expect(registry.arc(futureArc), isNotNull);
      expect(registry.availableArcs, hasLength(2));
      expect(
        registry.arc(futureArc)!.catalog.puzzles.first.id,
        'regalia:puzzle/moon-court/easy-001',
      );
    },
  );

  test('additional arc progress persists only in that arc namespace', () async {
    SharedPreferences.setMockInitialValues({
      SaveIds.tutorialComplete: true,
      'regalia.journeySchemaVersion': 1,
    });
    final originMetadata =
        await File('assets/content/arcs/origin/arc.json').readAsString();
    final originCatalog =
        await File('assets/puzzles/catalog.json').readAsString();
    final futureMetadata = originMetadata
        .replaceAll(ContentIds.originArc, futureArc)
        .replaceAll('/origin/', '/moon-court/')
        .replaceAll('"Queen’s Regalia: Origin Story"', '"The Moon Court"')
        .replaceAll('assets/puzzles/catalog.json', 'future-catalog.json');
    final assets = await assetsFor(
      futureChannels: ['paidPlatform'],
      futureMetadata: futureMetadata,
    );
    assets['future-catalog.json'] = originCatalog.replaceAll(
      '/origin/',
      '/moon-court/',
    );

    Future<String> read(String path) async {
      if (path == 'assets/puzzles/catalog.json') return assets['catalog.json']!;
      if (assets[path] case final value?) return value;
      throw StateError('$path not found');
    }

    AppController createController() => AppController(
      contentManifestAsset: 'manifest.json',
      contentAssetReader: read,
      contentPolicy: const ContentEntitlementPolicy.paidPlatform(
        grantedEntitlementIds: {futureEntitlement},
      ),
    );

    final controller = createController();
    await controller.initialize();
    final arc = controller.content!.arc(futureArc)!;
    final puzzle = arc.catalog.puzzles.first;
    expect(controller.canOpenPuzzle(puzzle), isTrue);
    expect(controller.openPuzzle(puzzle), isTrue);
    await controller.markStoryBeatSeen(arc.openingScene.id);
    await controller.unlockEntireMap(arc.id);
    await controller.flushPersistence();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(SaveIds.forArc(futureArc, 'boards')),
      contains(puzzle.id),
    );
    expect(
      preferences.getString(SaveIds.originBoards),
      isNot(contains(puzzle.id)),
    );
    controller.dispose();

    final restored = createController();
    await restored.initialize();
    addTearDown(restored.dispose);
    final restoredArc = restored.content!.arc(futureArc)!;
    expect(restored.recordFor(puzzle.id).status, CompletionStatus.inProgress);
    expect(restored.hasSeenStoryBeat(restoredArc.openingScene.id), isTrue);
    expect(restored.isMapUnlocked(futureArc), isTrue);
  });

  test(
    'missing entitled arc is isolated from origin and Just Puzzle',
    () async {
      final assets = await assetsFor(futureChannels: ['paidPlatform']);
      final registry = await repository(assets).load(
        manifestAsset: 'manifest.json',
        policy: const ContentEntitlementPolicy.paidPlatform(
          grantedEntitlementIds: {futureEntitlement},
        ),
      );

      expect(
        registry.availabilityFor(futureArc).status,
        ContentAvailabilityStatus.missingPackage,
      );
      expect(registry.arc(ContentIds.originArc), isNotNull);
      expect(registry.justPuzzleAvailable, isTrue);
    },
  );

  test('invalid entitled arc is isolated from valid packages', () async {
    final assets = await assetsFor(
      futureChannels: ['paidPlatform'],
      futureMetadata: '{"schemaVersion": 99}',
    );
    final registry = await repository(assets).load(
      manifestAsset: 'manifest.json',
      policy: const ContentEntitlementPolicy.paidPlatform(
        grantedEntitlementIds: {futureEntitlement},
      ),
    );

    expect(
      registry.availabilityFor(futureArc).status,
      ContentAvailabilityStatus.invalidPackage,
    );
    expect(registry.arc(ContentIds.originArc), isNotNull);
    expect(registry.justPuzzleAvailable, isTrue);
  });

  test('Just Puzzle starts when the origin package is missing', () async {
    SharedPreferences.setMockInitialValues({SaveIds.tutorialComplete: true});
    final catalog = PuzzleCatalog.fromJsonString(
      await File('assets/puzzles/catalog.json').readAsString(),
    );
    final manifest = jsonEncode({
      'schemaVersion': 1,
      'features': [ContentIds.justPuzzleFeature],
      'arcs': [
        {
          'arcId': ContentIds.originArc,
          'metadataAsset': 'missing-origin.json',
          'entitlementId': ContentIds.originEntitlement,
          'channels': ['web'],
          'storefront': storefrontFor(
            ContentIds.originArc,
            'Queen’s Regalia: Origin Story',
          ),
        },
      ],
    });
    late AppController controller;
    controller = AppController(
      contentPolicy: const ContentEntitlementPolicy.web(),
      contentAssetReader: (path) async {
        if (path == 'manifest.json') return manifest;
        throw StateError('$path not found');
      },
      contentManifestAsset: 'manifest.json',
      challengePuzzleFactory:
          (spec, _) async => challengeFixtureFromCatalog(catalog, spec),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    expect(controller.isReady, isTrue);
    expect(controller.hasOriginStory, isFalse);
    expect(controller.catalog, isNull);
    expect(controller.justPuzzleAvailable, isTrue);
    expect(
      controller.availabilityForArc(ContentIds.originArc).status,
      ContentAvailabilityStatus.missingPackage,
    );
    expect(
      await controller.startChallenge(ChallengeMode.easy, seed: 99),
      isTrue,
    );
    expect(controller.challengeSession, isNotNull);
  });

  test('all durable identifier kinds use the canonical namespace', () async {
    final assets = await assetsFor(futureChannels: ['paidPlatform']);
    final arc =
        (await repository(assets).load(
          manifestAsset: 'manifest.json',
          policy: const ContentEntitlementPolicy.web(),
        )).arc(ContentIds.originArc)!;

    expect(ContentId.isValid(arc.id, kind: 'arc'), isTrue);
    expect(ContentId.isValid(arc.mapId, kind: 'map'), isTrue);
    expect(ContentId.isValid(arc.unlockIds.fullMap, kind: 'unlock'), isTrue);
    expect(ContentId.isValid(arc.unlockIds.finale, kind: 'unlock'), isTrue);
    expect(SaveIds.forArc(arc.id, 'boards'), SaveIds.originBoards);
    expect(
      arc.chapters.every(
        (chapter) =>
            ContentId.isValid(chapter.id, kind: 'chapter') &&
            ContentId.isValid(chapter.mapId, kind: 'map') &&
            ContentId.isValid(chapter.boss.id, kind: 'boss') &&
            ContentId.isValid(chapter.boss.puzzleId, kind: 'puzzle'),
      ),
      isTrue,
    );
    expect(
      arc.scenes.every((scene) => ContentId.isValid(scene.id, kind: 'scene')),
      isTrue,
    );
    for (final saveId in const [
      SaveIds.settings,
      SaveIds.supportPromptedChapters,
      SaveIds.originBoards,
      SaveIds.justPuzzleSession,
    ]) {
      expect(ContentId.isValid(saveId, kind: 'save'), isTrue);
    }
  });
}
