import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:regalia/app/combat_style.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/cinematic_scene_models.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/models.dart';

void main() {
  const atlasArc = 'regalia:arc/atlas-of-borrowed-winds';
  const atlasPackage = 'assets/content/arcs/atlas-of-borrowed-winds/';

  ContentRepository repository({List<String>? reads}) => ContentRepository(
    readAsset: (path) async {
      reads?.add(path);
      return File(path).readAsString();
    },
  );

  test(
    'web exposes the Atlas preview without reading its paid package',
    () async {
      final reads = <String>[];
      final registry = await repository(reads: reads).load(
        manifestAsset: 'assets/content/manifest.json',
        policy: const ContentEntitlementPolicy.web(),
      );
      final availability = registry.availabilityFor(atlasArc);

      expect(availability.status, ContentAvailabilityStatus.notInEdition);
      expect(availability.arc, isNull);
      expect(availability.storefront, isNotNull);
      expect(availability.storefront!.title, 'The Atlas of Borrowed Winds');
      expect(availability.storefront!.prologuePreview.frames, hasLength(3));
      final previewText = availability.storefront!.prologuePreview.frames
          .expand((frame) => frame.narrative.paragraphs)
          .join(' ');
      expect(previewText, contains('family’s debt'));
      expect(previewText, contains('caravan is trapped in a sandstorm'));
      expect(previewText, contains('bound to the book'));
      expect(previewText, contains('someone else may lose that water'));
      expect(previewText, contains('town of Anbar has lost its water'));
      expect(
        availability.storefront!.prologuePreview.frames.map(
          (frame) => frame.characterLayers.length,
        ),
        orderedEquals([2, 2, 3]),
      );
      expect(reads.where((path) => path.startsWith(atlasPackage)), isEmpty);
    },
  );

  test(
    'paid Atlas package is a complete eight-chapter production arc',
    () async {
      final registry = await repository().load(
        manifestAsset: 'assets/content/manifest.json',
        policy: const ContentEntitlementPolicy.paidPlatform(),
      );
      final availability = registry.availabilityFor(atlasArc);
      expect(
        availability.status,
        ContentAvailabilityStatus.available,
        reason: '${availability.error}',
      );
      final arc = availability.arc!;

      expect(arc.title, 'The Atlas of Borrowed Winds');
      expect(arc.contentVersion, 4);
      expect(arc.chapters, hasLength(8));
      expect(arc.catalog.puzzles, hasLength(72));
      expect(arc.scenes, hasLength(10));
      expect(arc.openingScene.frames, hasLength(3));
      expect(arc.finaleScene.frames, hasLength(2));
      expect(
        arc.scenes
            .where((scene) => scene.role == StorySceneRole.chapter)
            .every((scene) => scene.frames.length == 1),
        isTrue,
      );

      expect(
        arc.chapters.map((chapter) => chapter.size),
        orderedEquals([6, 7, 7, 8, 8, 9, 9, 10]),
      );
      expect(
        arc.chapters.map((chapter) => chapter.difficulty.name),
        orderedEquals([
          'easy',
          'easy',
          'medium',
          'medium',
          'hard',
          'hard',
          'expert',
          'expert',
        ]),
      );
      expect(
        arc.chapters.map((chapter) => chapter.boss.size),
        orderedEquals([7, 7, 8, 8, 9, 9, 10, 12]),
      );
      expect(
        arc.chapters.map((chapter) => chapter.boss.finisherStyle.track),
        orderedEquals([
          CombatFinisherTrack.crownSlash,
          CombatFinisherTrack.tidalAegis,
          CombatFinisherTrack.twinSigil,
          CombatFinisherTrack.moonlitSever,
          CombatFinisherTrack.brassJudgment,
          CombatFinisherTrack.cinderfall,
          CombatFinisherTrack.skybreak,
          CombatFinisherTrack.regaliaNova,
        ]),
      );
      expect(
        arc.chapters.expand((chapter) => chapter.encounters),
        hasLength(16),
      );
      final opponentAssets =
          arc.combatEncounters
              .map((encounter) => encounter.spriteAsset)
              .toSet();
      expect(opponentAssets, hasLength(24));
      expect(
        opponentAssets.every(
          (asset) => asset.startsWith(
            'assets/art/arcs/atlas-of-borrowed-winds/combat/opponents/',
          ),
        ),
        isTrue,
      );
    },
  );

  test(
    'Atlas themes, routes, and finale casts vary entirely through data',
    () async {
      final arc =
          (await repository().load(
            manifestAsset: 'assets/content/manifest.json',
            policy: const ContentEntitlementPolicy.paidPlatform(),
          )).arc(atlasArc)!;

      expect(arc.chapters.first.palette.theme.brightness, Brightness.light);
      expect(
        arc.chapters.first.palette.theme.background,
        const Color(0xfff2d6a2),
      );
      expect(arc.chapters[3].palette.theme.brightness, Brightness.dark);
      expect(arc.chapters[4].palette.theme.background, const Color(0xff211815));
      expect(arc.chapters[6].palette.theme.brightness, Brightness.dark);
      expect(arc.chapters.last.palette.theme.brightness, Brightness.light);

      final layouts =
          arc.chapters
              .map(
                (chapter) => (
                  chapter.mapLayout.columns,
                  chapter.mapLayout.pattern,
                  chapter.mapLayout.direction,
                ),
              )
              .toSet();
      expect(layouts.length, greaterThanOrEqualTo(6));
      expect(arc.chapters[1].mapLayout.pattern, JourneyRoutePattern.rows);
      expect(
        arc.chapters[2].mapLayout.direction,
        JourneyRouteDirection.rightToLeft,
      );

      final finale = arc.finaleScene.frames;
      expect(
        finale.map((frame) => frame.characterLayers.length),
        orderedEquals([0, 3]),
      );
      expect(finale[1].characterLayers.map((layer) => layer.id).toSet(), {
        'nahla',
        'samir',
        'ilyun',
      });
      expect(
        finale
            .expand((frame) => frame.characterLayers)
            .every((layer) => layer.source is CinematicAssetCharacterSource),
        isTrue,
      );
      expect(finale.first.background.asset, endsWith('finale_storm.jpg'));
      expect(finale.last.background.asset, endsWith('finale_dawn.jpg'));
    },
  );

  test('Atlas cinematic accents retain readable text contrast', () async {
    final registry = await repository().load(
      manifestAsset: 'assets/content/manifest.json',
      policy: const ContentEntitlementPolicy.paidPlatform(),
    );
    final availability = registry.availabilityFor(atlasArc);
    final storefrontTheme = availability.storefront!.theme;
    expect(
      _contrastRatio(
        Color(storefrontTheme.backgroundColor),
        Color(storefrontTheme.secondaryColor),
      ),
      greaterThanOrEqualTo(4.5),
      reason: 'storefront prologue page indicator',
    );

    for (final chapter in availability.arc!.chapters) {
      expect(
        _contrastRatio(
          chapter.palette.theme.background,
          chapter.palette.secondary,
        ),
        greaterThanOrEqualTo(4.5),
        reason: chapter.title,
      );
      final bestiaryAccent = RegaliaTheme.readableAccent(
        preferred: chapter.palette.secondary,
        background: RegaliaTheme.midnightSurface,
      );
      expect(
        _contrastRatio(RegaliaTheme.midnightSurface, bestiaryAccent),
        greaterThanOrEqualTo(4.5),
        reason: '${chapter.title} on the shared Bestiary surface',
      );
    }
  });

  test('Atlas puzzle layouts are distinct from the Origin catalog', () async {
    final atlas =
        (await repository().load(
          manifestAsset: 'assets/content/manifest.json',
          policy: const ContentEntitlementPolicy.paidPlatform(),
        )).arc(atlasArc)!;
    final origin = PuzzleCatalog.fromJsonString(
      await File('assets/puzzles/catalog.json').readAsString(),
    );
    const generator = PuzzleGenerator();
    final originFingerprints =
        origin.puzzles.map(generator.canonicalFingerprint).toSet();
    final atlasFingerprints =
        atlas.catalog.puzzles.map(generator.canonicalFingerprint).toSet();

    expect(
      atlasFingerprints.intersection(originFingerprints),
      isEmpty,
      reason: 'paid story arcs must not replay Origin boards under new IDs',
    );
  });

  test('Atlas opponents never reuse Origin sprite art', () async {
    final registry = await repository().load(
      manifestAsset: 'assets/content/manifest.json',
      policy: const ContentEntitlementPolicy.paidPlatform(),
    );
    final atlas = registry.arc(atlasArc)!;
    final origin = registry.arc('regalia:arc/origin')!;

    final atlasAssets =
        atlas.combatEncounters
            .map((encounter) => encounter.spriteAsset)
            .toSet();
    final originAssets =
        origin.combatEncounters
            .map((encounter) => encounter.spriteAsset)
            .toSet();
    expect(atlasAssets.intersection(originAssets), isEmpty);
  });

  test('story guidance protects clarity without standardizing arc voice', () {
    final guide = File('docs/CONTENT_AUTHORING.md').readAsStringSync();

    expect(guide, contains('Clarity is a floor, not the voice of the game.'));
    expect(guide, contains('do not turn the brief into a universal checklist'));
    expect(guide, contains('earnest, measured rescue tale'));
    expect(
      RegExp(
        r'warm, quick, and\s+wry about royal\s+bureaucracy',
      ).hasMatch(guide),
      isTrue,
    );
    expect(
      RegExp(r'Future arcs may lean comic, horrific, romantic').hasMatch(guide),
      isTrue,
    );
  });

  test(
    'Atlas production art exists at authored high-resolution dimensions',
    () async {
      final registry = await repository().load(
        manifestAsset: 'assets/content/manifest.json',
        policy: const ContentEntitlementPolicy.paidPlatform(),
      );
      final arc = registry.arc(atlasArc)!;
      final storefront = registry.availabilityFor(atlasArc).storefront!;
      final paths = <String>{
        storefront.tileArtAsset,
        if (storefront.tileForegroundAsset case final asset?) asset,
        ...storefront.prologuePreview.assetPaths,
        ...arc.chapters.map((chapter) => chapter.artAsset),
        ...arc.scenes.expand((scene) => scene.assetPaths),
      };

      expect(paths, hasLength(18));
      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final decoded = image.decodeImage(file.readAsBytesSync());
        expect(decoded, isNotNull, reason: path);
        if (path.endsWith('.png')) {
          expect(decoded!.width, 1024, reason: path);
          expect(decoded.height, 1536, reason: path);
          expect(decoded.numChannels, 4, reason: path);
        } else if (path.contains('/backgrounds/chapter_') ||
            path.endsWith('/tile.jpg')) {
          expect(decoded!.width, 1024, reason: path);
          expect(decoded.height, 1024, reason: path);
        } else {
          expect(decoded!.width, 1024, reason: path);
          expect(decoded.height, 1536, reason: path);
        }
      }
    },
  );
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + .05) / (darker + .05);
}
