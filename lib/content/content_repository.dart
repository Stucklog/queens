import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app/arc_theme.dart';
import '../app/journey.dart';
import '../core/models.dart';
import 'content_ids.dart';
import 'content_models.dart';
import 'entitlements.dart';

typedef ContentAssetReader = Future<String> Function(String assetPath);
typedef ContentAssetExists = Future<bool> Function(String assetPath);

class ContentRepository {
  const ContentRepository({required this.readAsset, this.assetExists});

  final ContentAssetReader readAsset;
  final ContentAssetExists? assetExists;

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
    final arcIds = <String>{};
    for (final descriptor in descriptors) {
      if (!arcIds.add(descriptor.arcId)) {
        throw FormatException('Duplicate arc package ${descriptor.arcId}');
      }
    }
    final availability = Map<String, ArcAvailability>.fromEntries(
      await Future.wait(
        descriptors.map(
          (descriptor) async => MapEntry(
            descriptor.arcId,
            await _availabilityFor(descriptor, policy),
          ),
        ),
      ),
    );
    final storefrontLinks = switch (manifest['storeLinks']) {
      final Map<String, Object?> links => StorefrontLinks.fromJson(links),
      _ => null,
    };
    return ContentRegistry(
      arcs: availability,
      justPuzzleAvailable:
          features.contains(ContentIds.justPuzzleFeature) &&
          policy.isEntitled(ContentIds.justPuzzleEntitlement),
      storefrontLinks: storefrontLinks,
    );
  }

  Future<ArcAvailability> _availabilityFor(
    ArcPackageDescriptor descriptor,
    ContentEntitlementPolicy policy,
  ) async {
    if (!policy.includesArc(descriptor.channels)) {
      return ArcAvailability(
        status: ContentAvailabilityStatus.notInEdition,
        descriptor: descriptor,
      );
    }
    if (!policy.isEntitled(descriptor.entitlementId)) {
      return ArcAvailability(
        status: ContentAvailabilityStatus.notEntitled,
        descriptor: descriptor,
      );
    }
    if (assetExists case final exists?) {
      if (!await exists(descriptor.metadataAsset)) {
        return ArcAvailability(
          status: ContentAvailabilityStatus.missingPackage,
          descriptor: descriptor,
          error: StateError(
            'Content asset not found: ${descriptor.metadataAsset}',
          ),
        );
      }
    }
    try {
      final arc = await _loadArc(descriptor);
      return ArcAvailability(
        status: ContentAvailabilityStatus.available,
        descriptor: descriptor,
        arc: arc,
      );
    } on Object catch (error) {
      debugPrint('Content package ${descriptor.arcId} is unavailable: $error');
      final missing =
          error.toString().contains('Unable to load asset') ||
          error.toString().contains('not found');
      return ArcAvailability(
        status:
            missing
                ? ContentAvailabilityStatus.missingPackage
                : ContentAvailabilityStatus.invalidPackage,
        descriptor: descriptor,
        error: error,
      );
    }
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
    final arcTheme = ArcThemeColors.fromJson(metadata['theme']);
    final packagedScenes =
        (metadata['scenes']! as List<Object?>)
            .map(
              (scene) =>
                  StorySceneContent.fromJson(scene! as Map<String, Object?>),
            )
            .toList();
    final packagedOpenings = packagedScenes
        .where((scene) => scene.role == StorySceneRole.opening)
        .toList(growable: false);
    if (packagedOpenings.length > 1 ||
        (packagedOpenings.isNotEmpty &&
            packagedOpenings.single.id !=
                descriptor.storefront.prologuePreview.id)) {
      throw FormatException(
        '${descriptor.metadataAsset} has an opening that conflicts with its '
        'storefront prologue',
      );
    }
    final scenes = <StorySceneContent>[
      if (packagedOpenings.isEmpty) descriptor.storefront.prologuePreview,
      ...packagedScenes,
    ];
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
                (chapter) => JourneyChapter.fromJson(
                  chapter! as Map<String, Object?>,
                  arcTheme: arcTheme,
                ),
              )
              .toList(),
      scenes: scenes,
      catalog: catalog,
    );
  }
}
