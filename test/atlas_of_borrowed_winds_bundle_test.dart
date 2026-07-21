import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/content_repository.dart';
import 'package:regalia/content/entitlements.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default app bundle includes the complete Atlas story', () async {
    final registry = await ContentRepository(
      readAsset: rootBundle.loadString,
    ).load(
      manifestAsset: 'assets/content/manifest.json',
      policy: ContentEntitlementPolicy.current(),
    );
    expect(
      registry.availabilityFor('regalia:arc/atlas-of-borrowed-winds').status,
      ContentAvailabilityStatus.available,
    );

    final metadata =
        jsonDecode(
              await rootBundle.loadString(
                'assets/content/arcs/atlas-of-borrowed-winds/arc.json',
              ),
            )
            as Map<String, Object?>;
    final catalog =
        jsonDecode(
              await rootBundle.loadString(
                'assets/content/arcs/atlas-of-borrowed-winds/catalog.json',
              ),
            )
            as Map<String, Object?>;

    expect(metadata['id'], 'regalia:arc/atlas-of-borrowed-winds');
    expect((metadata['chapters']! as List<Object?>).length, 8);
    expect((catalog['puzzles']! as List<Object?>).length, 72);

    final assetPaths = <String>{};
    _collectAssetPaths(metadata, assetPaths);
    for (final path in assetPaths.where(
      (path) => path.startsWith('assets/art/'),
    )) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });
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
