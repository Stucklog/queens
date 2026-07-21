import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'paid flavor bundles every Atlas gameplay and finale asset',
    () async {
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
      expect(catalog['puzzles'], hasLength(72));

      final paidArt = <String>{};
      _collectAssetPaths(metadata, paidArt);
      paidArt.removeWhere(
        (path) =>
            path.startsWith('assets/storefront/') ||
            path.startsWith('assets/art/combat/opponents/'),
      );
      expect(paidArt, hasLength(14));
      for (final path in paidArt) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    },
    skip: appFlavor != 'paid',
  );
}

void _collectAssetPaths(Object? value, Set<String> paths) {
  switch (value) {
    case final String path when path.startsWith('assets/'):
      paths.add(path);
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
