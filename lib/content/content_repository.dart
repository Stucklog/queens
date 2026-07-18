import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app/journey.dart';
import '../core/models.dart';
import 'content_ids.dart';
import 'content_models.dart';
import 'entitlements.dart';

typedef ContentAssetReader = Future<String> Function(String assetPath);

class ContentRepository {
  const ContentRepository({required this.readAsset});

  final ContentAssetReader readAsset;

  Future<ContentRegistry> load({
    required String manifestAsset,
    required ContentEntitlementPolicy policy,
  }) async {
    final manifest = jsonDecode(await readAsset(manifestAsset));
    if (manifest is! Map<String, Object?> ||
        (manifest['schemaVersion'] as num?)?.toInt() != 1) {
      throw const FormatException('Unsupported content manifest');
    }
    final features =
        (manifest['features'] as List<Object?>? ?? const []).cast<String>();
    for (final feature in features) {
      ContentId.parse(feature, expectedKind: 'feature');
    }
    final descriptors =
        (manifest['arcs'] as List<Object?>? ?? const [])
            .map(
              (entry) =>
                  ArcPackageDescriptor.fromJson(entry! as Map<String, Object?>),
            )
            .toList();
    final availability = <String, ArcAvailability>{};
    for (final descriptor in descriptors) {
      if (availability.containsKey(descriptor.arcId)) {
        throw FormatException('Duplicate arc package ${descriptor.arcId}');
      }
      if (!policy.includesArc(descriptor.arcId, descriptor.channels)) {
        availability[descriptor.arcId] = const ArcAvailability(
          status: ContentAvailabilityStatus.notInEdition,
        );
        continue;
      }
      if (!policy.isEntitled(descriptor.entitlementId)) {
        availability[descriptor.arcId] = const ArcAvailability(
          status: ContentAvailabilityStatus.notEntitled,
        );
        continue;
      }
      try {
        final arc = await _loadArc(descriptor);
        availability[descriptor.arcId] = ArcAvailability(
          status: ContentAvailabilityStatus.available,
          arc: arc,
        );
      } on Object catch (error) {
        debugPrint(
          'Content package ${descriptor.arcId} is unavailable: $error',
        );
        final missing =
            error.toString().contains('Unable to load asset') ||
            error.toString().contains('not found');
        availability[descriptor.arcId] = ArcAvailability(
          status:
              missing
                  ? ContentAvailabilityStatus.missingPackage
                  : ContentAvailabilityStatus.invalidPackage,
          error: error,
        );
      }
    }
    return ContentRegistry(
      arcs: availability,
      justPuzzleAvailable:
          features.contains(ContentIds.justPuzzleFeature) &&
          policy.isEntitled(ContentIds.justPuzzleEntitlement),
    );
  }

  Future<StoryArc> _loadArc(ArcPackageDescriptor descriptor) async {
    final metadata = jsonDecode(await readAsset(descriptor.metadataAsset));
    if (metadata is! Map<String, Object?> ||
        (metadata['schemaVersion'] as num?)?.toInt() != 1) {
      throw FormatException('Unsupported arc package ${descriptor.arcId}');
    }
    if (metadata['id'] != descriptor.arcId) {
      throw FormatException('${descriptor.metadataAsset} has the wrong arc ID');
    }
    final catalogAsset = metadata['puzzleCatalogAsset']! as String;
    final catalog = PuzzleCatalog.fromJsonString(await readAsset(catalogAsset));
    return StoryArc(
      id: metadata['id']! as String,
      contentVersion: (metadata['contentVersion']! as num).toInt(),
      title: metadata['title']! as String,
      mapId: metadata['mapId']! as String,
      unlockIds: ArcUnlockIds.fromJson(
        metadata['unlocks']! as Map<String, Object?>,
      ),
      chapters:
          (metadata['chapters']! as List<Object?>)
              .map(
                (chapter) =>
                    JourneyChapter.fromJson(chapter! as Map<String, Object?>),
              )
              .toList(),
      scenes:
          (metadata['scenes']! as List<Object?>)
              .map(
                (scene) =>
                    StorySceneContent.fromJson(scene! as Map<String, Object?>),
              )
              .toList(),
      catalog: catalog,
    );
  }
}
