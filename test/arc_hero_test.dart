import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';

const _customHeroArcIds = <String>[
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

void main() {
  test('expansion heroes parse as owned role-specific assets', () async {
    final registry = await _loadRegistry();

    for (final arcId in _customHeroArcIds) {
      final arc = registry.arc(arcId);
      expect(arc, isNotNull, reason: arcId);
      if (arc == null) continue;
      final hero = arc.hero;
      expect(hero, isNotNull, reason: arcId);
      if (hero == null) continue;

      final arcName = ContentId.parse(arcId, expectedKind: 'arc').localName;
      final heroSlug = hero.id.split('/').last;
      final assetPrefix = 'assets/art/arcs/$arcName/characters/$heroSlug';
      expect(hero.id, '$arcName/$heroSlug', reason: arcId);
      expect(hero.storySpriteAsset, '${assetPrefix}_story_idle.png');
      expect(hero.combatSpriteAsset, '${assetPrefix}_combat.png');
      expect(hero.finisherSpriteAsset, '${assetPrefix}_finishers.png');
      expect(
        arc.scenes.expand((scene) => scene.assetPaths),
        contains(hero.storySpriteAsset),
        reason: '$arcId must render its declared story hero',
      );
    }
  });

  test('arc hero parser rejects incomplete and ABI-incompatible records', () {
    final valid = <String, Object?>{
      'id': 'sun-sail-covenant/nera-venn',
      'name': 'Nera Venn',
      'semanticLabel': 'Nera Venn, covenant courier',
      'storySpriteAsset':
          'assets/art/arcs/sun-sail-covenant/characters/'
          'nera-venn_story_idle.png',
      'combatSpriteAsset':
          'assets/art/arcs/sun-sail-covenant/characters/'
          'nera-venn_combat.png',
      'finisherSpriteAsset':
          'assets/art/arcs/sun-sail-covenant/characters/'
          'nera-venn_finishers.png',
    };
    final hero = ArcHero.fromJson(valid);
    expect(hero.name, 'Nera Venn');

    final invalidRecords = <String, Map<String, Object?>>{
      'missing name': Map<String, Object?>.from(valid)..remove('name'),
      'wrong semantic label type': Map<String, Object?>.from(valid)
        ..['semanticLabel'] = 42,
      'blank name': Map<String, Object?>.from(valid)..['name'] = '   ',
      'empty local hero id': Map<String, Object?>.from(valid)
        ..['id'] = 'sun-sail-covenant/',
      'extra hero id segment': Map<String, Object?>.from(valid)
        ..['id'] = 'sun-sail-covenant/nera-venn/alternate',
      'traversing story path': Map<String, Object?>.from(valid)
        ..['storySpriteAsset'] =
            'assets/art/arcs/sun-sail-covenant/characters/../'
            'nera-venn_story_idle.png',
      'story path with combat ABI': Map<String, Object?>.from(valid)
        ..['storySpriteAsset'] =
            'assets/art/arcs/sun-sail-covenant/characters/'
            'nera-venn_combat.png',
      'combat path with finisher ABI': Map<String, Object?>.from(valid)
        ..['combatSpriteAsset'] =
            'assets/art/arcs/sun-sail-covenant/characters/'
            'nera-venn_finishers.png',
      'wrong finisher extension': Map<String, Object?>.from(valid)
        ..['finisherSpriteAsset'] =
            'assets/art/arcs/sun-sail-covenant/characters/'
            'nera-venn_finishers.webp',
    };

    for (final MapEntry(key: reason, value: record) in invalidRecords.entries) {
      expect(
        () => ArcHero.fromJson(record),
        throwsFormatException,
        reason: reason,
      );
    }
  });

  test(
    'story arc validation rejects a hero asset owned by another arc',
    () async {
      const metadataPath = 'assets/content/arcs/sun-sail-covenant/arc.json';
      final metadata =
          jsonDecode(await File(metadataPath).readAsString())
              as Map<String, Object?>;
      final hero = metadata['hero']! as Map<String, Object?>;
      hero['combatSpriteAsset'] =
          'assets/art/arcs/oathstorm-fleet/characters/nera-venn_combat.png';

      final registry = await _loadRegistry(
        overriddenPath: metadataPath,
        overriddenContents: jsonEncode(metadata),
      );
      final availability = registry.availabilityFor(
        'regalia:arc/sun-sail-covenant',
      );
      expect(availability.status, ContentAvailabilityStatus.invalidPackage);
      expect(availability.error, isA<FormatException>());
      expect(
        registry.availabilityFor(ContentIds.originArc).status,
        ContentAvailabilityStatus.available,
      );
    },
  );
}

Future<ContentRegistry> _loadRegistry({
  String? overriddenPath,
  String? overriddenContents,
}) => ContentRepository(
  readAsset: (path) {
    if (path == overriddenPath) return Future.value(overriddenContents!);
    return File(path).readAsString();
  },
).load(
  manifestAsset: 'assets/content/manifest.json',
  policy: const ContentEntitlementPolicy.paidPlatform(),
);
