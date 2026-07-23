import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'default native bundle contains every story package and its art',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString('assets/content/manifest.json'),
              )
              as Map<String, Object?>;
      final descriptors =
          (manifest['arcs']! as List<Object?>).cast<Map<String, Object?>>();

      expect(descriptors, hasLength(11));
      for (final descriptor in descriptors) {
        final arcId = descriptor['arcId']! as String;
        final channels =
            (descriptor['channels']! as List<Object?>).cast<String>();
        if (arcId == 'regalia:arc/origin') {
          expect(
            channels,
            containsAll(<String>['web', 'paidPlatform']),
            reason: arcId,
          );
          expect(descriptor['lockedPreviewChannels'], isNull);
        } else {
          expect(
            channels,
            orderedEquals(<String>['paidPlatform']),
            reason: arcId,
          );
          expect(
            descriptor['lockedPreviewChannels'],
            orderedEquals(<String>['web']),
            reason: arcId,
          );
        }

        final metadataPath = descriptor['metadataAsset']! as String;
        final metadata =
            jsonDecode(await rootBundle.loadString(metadataPath))
                as Map<String, Object?>;
        final catalogPath = metadata['puzzleCatalogAsset']! as String;
        final catalog =
            jsonDecode(await rootBundle.loadString(catalogPath))
                as Map<String, Object?>;
        expect(metadata['id'], arcId, reason: metadataPath);
        expect(metadata['chapters'], hasLength(8), reason: arcId);
        expect(catalog['puzzles'], hasLength(72), reason: arcId);

        final assetPaths = <String>{};
        _collectAssetPaths(descriptor['storefront'], assetPaths);
        _collectAssetPaths(metadata, assetPaths);
        for (final path in assetPaths) {
          final data = await rootBundle.load(path);
          expect(data.lengthInBytes, greaterThan(0), reason: '$arcId: $path');
        }
      }
    },
  );
}

void _collectAssetPaths(Object? value, Set<String> paths) {
  switch (value) {
    case final String text when text.startsWith('assets/'):
      paths.add(text);
    case final List<Object?> values:
      for (final value in values) {
        _collectAssetPaths(value, paths);
      }
    case final Map<String, Object?> values:
      for (final value in values.values) {
        _collectAssetPaths(value, paths);
      }
  }
}
