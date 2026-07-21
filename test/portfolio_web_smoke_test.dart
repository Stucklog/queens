import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web bundle exposes the complete portfolio and final package', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('assets/content/manifest.json'))
            as Map<String, Object?>;
    final descriptors =
        (manifest['arcs']! as List<Object?>).cast<Map<String, Object?>>();

    expect(descriptors, hasLength(11));
    for (final descriptor in descriptors) {
      expect(
        (descriptor['channels']! as List<Object?>).cast<String>(),
        containsAll(<String>['web', 'paidPlatform']),
        reason: descriptor['arcId']! as String,
      );
    }

    const finalArcId = 'regalia:arc/steal-the-seventh-tide';
    final finalDescriptor = descriptors.singleWhere(
      (descriptor) => descriptor['arcId'] == finalArcId,
    );
    final storefront = finalDescriptor['storefront']! as Map<String, Object?>;
    final preview = storefront['prologuePreview']! as Map<String, Object?>;
    expect(preview['frames'], hasLength(3));

    final metadata =
        jsonDecode(
              await rootBundle.loadString(
                finalDescriptor['metadataAsset']! as String,
              ),
            )
            as Map<String, Object?>;
    expect(metadata['id'], finalArcId);
    expect(metadata['chapters'], hasLength(8));
    final scenes =
        (metadata['scenes']! as List<Object?>).cast<Map<String, Object?>>();
    final finale = scenes.singleWhere((scene) => scene['role'] == 'finale');
    expect(finale['frames'], hasLength(2));

    final catalog =
        jsonDecode(
              await rootBundle.loadString(
                metadata['puzzleCatalogAsset']! as String,
              ),
            )
            as Map<String, Object?>;
    expect(catalog['puzzles'], hasLength(72));
  });
}
