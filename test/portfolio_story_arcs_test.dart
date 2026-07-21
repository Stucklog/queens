import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/generator.dart';
import 'package:regalia/core/models.dart';

const _portfolioArcIds = <String>[
  'regalia:arc/sun-sail-covenant',
  'regalia:arc/where-the-rain-trees-walk',
  'regalia:arc/oathstorm-fleet',
  'regalia:arc/crimson-ledger',
  'regalia:arc/atlas-of-borrowed-winds',
  'regalia:arc/treaty-written-in-thorns',
  'regalia:arc/inn-at-the-end-of-yesterday',
  'regalia:arc/ninth-library',
  'regalia:arc/shepherds-of-the-thunderwild',
  'regalia:arc/steal-the-seventh-tide',
];

const _chapterDifficulties = <DifficultyTier>[
  DifficultyTier.easy,
  DifficultyTier.easy,
  DifficultyTier.medium,
  DifficultyTier.medium,
  DifficultyTier.hard,
  DifficultyTier.hard,
  DifficultyTier.expert,
  DifficultyTier.expert,
];

const _chapterSizes = <int>[6, 7, 7, 8, 8, 9, 9, 10];
const _bossSizes = <int>[7, 7, 8, 8, 9, 9, 10, 12];

void main() {
  late ContentRegistry registry;

  setUpAll(() async {
    registry = await ContentRepository(
      readAsset: (path) => File(path).readAsString(),
      assetExists: (path) async => File(path).existsSync(),
    ).load(
      manifestAsset: 'assets/content/manifest.json',
      policy: const ContentEntitlementPolicy.web(),
    );
  });

  test('web release makes every portfolio story arc playable', () {
    expect(_portfolioArcIds, hasLength(10));
    expect(_portfolioArcIds.toSet(), hasLength(_portfolioArcIds.length));
    expect(
      registry.arcEntries
          .map((entry) => entry.descriptor?.arcId)
          .where(_portfolioArcIds.contains),
      orderedEquals(_portfolioArcIds),
    );

    for (final arcId in _portfolioArcIds) {
      final availability = registry.availabilityFor(arcId);
      expect(
        availability.status,
        ContentAvailabilityStatus.available,
        reason: '$arcId: ${availability.error}',
      );
      expect(availability.arc, isNotNull, reason: arcId);
      expect(availability.storefront, isNotNull, reason: arcId);
    }
  });

  test('every portfolio arc has the complete eight-chapter cadence', () {
    for (final arcId in _portfolioArcIds) {
      final arc = registry.arc(arcId);
      expect(arc, isNotNull, reason: arcId);
      if (arc == null) continue;

      expect(arc.chapters, hasLength(8), reason: arcId);
      expect(arc.catalog.puzzles, hasLength(72), reason: arcId);
      expect(
        arc.chapters.map((chapter) => chapter.difficulty),
        orderedEquals(_chapterDifficulties),
        reason: arcId,
      );
      expect(
        arc.chapters.map((chapter) => chapter.size),
        orderedEquals(_chapterSizes),
        reason: arcId,
      );
      expect(
        arc.chapters.map((chapter) => chapter.boss.size),
        orderedEquals(_bossSizes),
        reason: arcId,
      );

      for (var index = 0; index < arc.chapters.length; index++) {
        final chapter = arc.chapters[index];
        final expectedStart = index * 9 + 1;
        final expectedOrders = List.generate(
          9,
          (offset) => expectedStart + offset,
        );
        expect(chapter.startOrder, expectedStart, reason: chapter.id);
        expect(chapter.endOrder, expectedStart + 8, reason: chapter.id);
        expect(
          arc.catalog.puzzles
              .where((puzzle) => chapter.contains(puzzle.order))
              .map((puzzle) => puzzle.order),
          orderedEquals(expectedOrders),
          reason: chapter.id,
        );
      }

      expect(
        arc.chapters.last.boss.unlockTargetId,
        arc.unlockIds.finale,
        reason: '$arcId final boss',
      );
    }
  });

  test(
    'every portfolio arc has a compact opening and complete story scenes',
    () {
      for (final arcId in _portfolioArcIds) {
        final arc = registry.arc(arcId);
        expect(arc, isNotNull, reason: arcId);
        if (arc == null) continue;

        expect(
          arc.openingScene.frames.length,
          inInclusiveRange(1, 3),
          reason: '$arcId opening',
        );
        final chapterScenes = arc.scenes
            .where((scene) => scene.role == StorySceneRole.chapter)
            .toList(growable: false);
        expect(chapterScenes, hasLength(8), reason: arcId);
        expect(
          chapterScenes.every((scene) => scene.frames.length == 1),
          isTrue,
          reason: '$arcId chapter scenes',
        );
        expect(
          chapterScenes.map((scene) => scene.id).toSet(),
          arc.chapters.map((chapter) => chapter.sceneId).toSet(),
          reason: '$arcId chapter scene ownership',
        );
        final finaleScenes = arc.scenes
            .where((scene) => scene.role == StorySceneRole.finale)
            .toList(growable: false);
        expect(finaleScenes, hasLength(1), reason: arcId);
        expect(
          finaleScenes.single.frames.length,
          greaterThanOrEqualTo(2),
          reason: '$arcId finale',
        );
      }
    },
  );

  test('every referenced portfolio art and storefront asset exists', () {
    for (final arcId in _portfolioArcIds) {
      final availability = registry.availabilityFor(arcId);
      final storefront = availability.storefront;
      final arc = availability.arc;
      expect(storefront, isNotNull, reason: '$arcId storefront');
      expect(arc, isNotNull, reason: '$arcId package');
      if (storefront == null || arc == null) continue;

      final storefrontAssets = <String>{
        storefront.tileArtAsset,
        if (storefront.tileForegroundAsset case final asset?) asset,
        ...storefront.prologuePreview.assetPaths,
      };
      for (final path in storefrontAssets) {
        expect(File(path).existsSync(), isTrue, reason: '$arcId: $path');
      }

      final referencedArt = <String>{
        ...arc.chapters.map((chapter) => chapter.artAsset),
        ...arc.scenes.expand((scene) => scene.assetPaths),
        ...arc.combatEncounters.map((encounter) => encounter.spriteAsset),
      };
      for (final path in referencedArt) {
        expect(File(path).existsSync(), isTrue, reason: '$arcId: $path');
      }
    }
  });

  test('portfolio themes keep overlays and structural outlines readable', () {
    for (final arcId in _portfolioArcIds) {
      final arc = registry.arc(arcId);
      expect(arc, isNotNull, reason: arcId);
      if (arc == null) continue;
      final colors = arc.chapters.first.palette.theme;
      final theme = RegaliaTheme.forChapter(arc.chapters.first);
      final snackBackground = theme.snackBarTheme.backgroundColor!;
      final snackForeground = theme.snackBarTheme.contentTextStyle!.color!;
      final tooltipDecoration =
          theme.tooltipTheme.decoration! as ShapeDecoration;
      final tooltipForeground = theme.tooltipTheme.textStyle!.color!;

      expect(
        colors.ink.computeLuminance(),
        lessThan(.15),
        reason: '$arcId scrim and shadow ink must remain dark',
      );
      expect(
        _contrastRatio(snackBackground, snackForeground),
        greaterThanOrEqualTo(4.5),
        reason: '$arcId snackbar text',
      );
      expect(
        _contrastRatio(tooltipDecoration.color!, tooltipForeground),
        greaterThanOrEqualTo(4.5),
        reason: '$arcId tooltip text',
      );

      if (arcId == 'regalia:arc/atlas-of-borrowed-winds') continue;
      for (final surface in <Color>[
        colors.background,
        colors.surface,
        colors.surfaceLow,
        colors.surfaceContainerHigh,
        colors.surfaceHigh,
      ]) {
        expect(
          _contrastRatio(colors.outlineVariant, surface),
          greaterThanOrEqualTo(3),
          reason: '$arcId structural outline on $surface',
        );
      }
    }
  });

  test('puzzle fingerprints and boss sprite paths are globally unique', () {
    final origin = registry.arc(ContentIds.originArc);
    expect(origin, isNotNull, reason: ContentIds.originArc);
    final portfolioArcs = <StoryArc>[];
    for (final arcId in _portfolioArcIds) {
      final arc = registry.arc(arcId);
      expect(arc, isNotNull, reason: arcId);
      if (arc != null) portfolioArcs.add(arc);
    }
    if (origin == null) return;
    final allArcs = <StoryArc>[origin, ...portfolioArcs];

    const generator = PuzzleGenerator();
    final fingerprintOwners = <String, String>{};
    for (final arc in allArcs) {
      for (final puzzle in arc.catalog.puzzles) {
        final fingerprint = generator.canonicalFingerprint(puzzle);
        final previousOwner = fingerprintOwners[fingerprint];
        expect(
          previousOwner,
          isNull,
          reason: '${puzzle.id} repeats the canonical layout of $previousOwner',
        );
        fingerprintOwners.putIfAbsent(fingerprint, () => puzzle.id);
      }
    }
    expect(
      fingerprintOwners,
      hasLength(
        allArcs.fold<int>(
          0,
          (total, arc) => total + arc.catalog.puzzles.length,
        ),
      ),
    );

    final bossSpriteOwners = <String, String>{};
    for (final arc in allArcs) {
      final arcBossSprites = arc.chapters
          .map((chapter) => chapter.boss.spriteAsset)
          .toList(growable: false);
      expect(
        arcBossSprites.toSet(),
        hasLength(arcBossSprites.length),
        reason: '${arc.id} repeats boss sprite art',
      );
      for (final chapter in arc.chapters) {
        final sprite = chapter.boss.spriteAsset;
        final previousOwner = bossSpriteOwners[sprite];
        expect(
          previousOwner,
          isNull,
          reason: '${chapter.boss.id} reuses $sprite from $previousOwner',
        );
        bossSpriteOwners.putIfAbsent(sprite, () => chapter.boss.id);
      }
    }
    expect(bossSpriteOwners, hasLength(allArcs.length * 8));
  });
}

double _contrastRatio(Color first, Color second) {
  final low = math.min(first.computeLuminance(), second.computeLuminance());
  final high = math.max(first.computeLuminance(), second.computeLuminance());
  return (high + .05) / (low + .05);
}
