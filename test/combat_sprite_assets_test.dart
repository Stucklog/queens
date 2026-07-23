import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test('knight finisher atlas contains eight distinct six-frame moves', () {
    final atlas = _decode('assets/art/combat/knight_finishers.png');
    expect(atlas.width, 1776);
    expect(atlas.height, 2368);
    _expectAnimatedAtlas(atlas, columns: 6, rows: 8);
    _expectTransparentCellGutters(
      atlas,
      columns: 6,
      rows: 8,
      gutter: 24,
      reason: 'knight finisher atlas',
    );
    _expectNoLongVerticalContentEdges(
      atlas,
      columns: 6,
      rows: 8,
      maxRun: 56,
      reason: 'knight finisher atlas',
    );
  });

  test(
    'declared custom hero atlases match the shared sprite ABIs',
    () {
      final manifest =
          jsonDecode(File('assets/content/manifest.json').readAsStringSync())
              as Map<String, Object?>;
      final descriptors = manifest['arcs']! as List<Object?>;
      final heroRecords = <(String, Map<String, Object?>)>[];
      for (final descriptorValue in descriptors) {
        final descriptor = descriptorValue! as Map<String, Object?>;
        final metadata =
            jsonDecode(
                  File(
                    descriptor['metadataAsset']! as String,
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        if (metadata['hero'] case final Map<String, Object?> hero) {
          heroRecords.add((metadata['id']! as String, hero));
        }
      }
      expect(heroRecords, hasLength(10));

      final allHeroAssets = <String>{};
      final allCombatSignatures = <int>{
        _pixelSignature(_decode('assets/art/knight_animations.png')),
      };
      final allFinisherSignatures = <int>{
        _pixelSignature(_decode('assets/art/combat/knight_finishers.png')),
      };
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final (arcId, hero) in heroRecords) {
        final storyAsset = hero['storySpriteAsset']! as String;
        final combatAsset = hero['combatSpriteAsset']! as String;
        final finisherAsset = hero['finisherSpriteAsset']! as String;
        final assets = {storyAsset, combatAsset, finisherAsset};
        expect(assets, hasLength(3), reason: arcId);
        expect(
          allHeroAssets.intersection(assets),
          isEmpty,
          reason: '$arcId reuses another hero atlas',
        );
        allHeroAssets.addAll(assets);

        final characterDirectory = storyAsset.substring(
          0,
          storyAsset.lastIndexOf('/') + 1,
        );
        expect(
          pubspec,
          contains('- $characterDirectory'),
          reason: '$arcId character assets must be bundled',
        );
        for (final asset in assets) {
          expect(File(asset).existsSync(), isTrue, reason: asset);
        }

        final story = _decode(storyAsset);
        expect(story.width, 768, reason: storyAsset);
        expect(story.height, 288, reason: storyAsset);
        _expectCleanPixelArtAlpha(story, reason: storyAsset);
        _expectAnimatedAtlas(story, columns: 4, rows: 1, reason: storyAsset);
        _expectTransparentCellGutters(
          story,
          columns: 4,
          rows: 1,
          gutter: 12,
          reason: storyAsset,
        );

        final combat = _decode(combatAsset);
        expect(combat.width, 1774, reason: combatAsset);
        expect(combat.height, 887, reason: combatAsset);
        expect(
          allCombatSignatures.add(
            _expectCleanPixelArtAlpha(combat, reason: combatAsset),
          ),
          isTrue,
          reason: '$combatAsset duplicates another or the legacy combat atlas',
        );
        _expectHeroCombatAtlas(combat, reason: combatAsset);

        final finishers = _decode(finisherAsset);
        expect(finishers.width, 1776, reason: finisherAsset);
        expect(finishers.height, 2368, reason: finisherAsset);
        expect(
          allFinisherSignatures.add(
            _expectCleanPixelArtAlpha(finishers, reason: finisherAsset),
          ),
          isTrue,
          reason:
              '$finisherAsset duplicates another or the legacy finisher atlas',
        );
        _expectAnimatedAtlas(
          finishers,
          columns: 6,
          rows: 8,
          reason: finisherAsset,
        );
        _expectTransparentCellGutters(
          finishers,
          columns: 6,
          rows: 8,
          gutter: 24,
          reason: finisherAsset,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'each custom arc owns a complete cast and ten production scenes',
    () {
      final manifest =
          jsonDecode(File('assets/content/manifest.json').readAsStringSync())
              as Map<String, Object?>;
      final descriptors = manifest['arcs']! as List<Object?>;
      final allCastAssets = <String>{};
      final allCastSignatures = <int>{};
      final allBackgroundAssets = <String>{};
      final allBackgroundSignatures = <int>{};

      for (final descriptorValue in descriptors) {
        final descriptor = descriptorValue! as Map<String, Object?>;
        final metadata =
            jsonDecode(
                  File(
                    descriptor['metadataAsset']! as String,
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final heroValue = metadata['hero'];
        if (heroValue is! Map<String, Object?>) continue;

        final arcId = metadata['id']! as String;
        final arcSlug = arcId.split('/').last;
        final castAssets = <String>{};
        final backgroundAssets = <String>{};

        void collectCharacters(Object? value) {
          if (value is! List<Object?>) return;
          for (final characterValue in value) {
            if (characterValue is! Map<String, Object?>) continue;
            final source = characterValue['source'];
            if (source is Map<String, Object?> && source['type'] == 'asset') {
              final asset = source['asset'];
              if (asset is String) castAssets.add(asset);
            }
          }
        }

        void collectBackground(Object? value) {
          if (value is Map<String, Object?>) {
            final asset = value['asset'];
            if (asset is String) backgroundAssets.add(asset);
          }
        }

        for (final sceneValue in metadata['scenes']! as List<Object?>) {
          final scene = sceneValue! as Map<String, Object?>;
          final defaults = scene['defaults']! as Map<String, Object?>;
          collectBackground(defaults['background']);
          collectCharacters(defaults['characters']);
          for (final frameValue in scene['frames']! as List<Object?>) {
            final frame = frameValue! as Map<String, Object?>;
            collectBackground(frame['background']);
            collectCharacters(frame['characters']);
          }
        }

        expect(
          castAssets.length,
          inInclusiveRange(2, 4),
          reason: '$arcId named cast',
        );
        expect(
          castAssets,
          contains(heroValue['storySpriteAsset']),
          reason: '$arcId playable hero must belong to its cast',
        );
        expect(
          allCastAssets.intersection(castAssets),
          isEmpty,
          reason: '$arcId reuses another arc cast strip',
        );
        allCastAssets.addAll(castAssets);

        for (final asset in castAssets) {
          expect(
            asset,
            startsWith('assets/art/arcs/$arcSlug/characters/'),
            reason: arcId,
          );
          expect(asset, endsWith('_story_idle.png'), reason: arcId);
          expect(File(asset).existsSync(), isTrue, reason: asset);
          final story = _decode(asset);
          expect(story.width, 768, reason: asset);
          expect(story.height, 288, reason: asset);
          final signature = _expectCleanPixelArtAlpha(story, reason: asset);
          expect(
            allCastSignatures.add(signature),
            isTrue,
            reason: '$asset duplicates another expansion cast strip',
          );
          _expectAnimatedAtlas(story, columns: 4, rows: 1, reason: asset);
          _expectTransparentCellGutters(
            story,
            columns: 4,
            rows: 1,
            gutter: 12,
            reason: asset,
          );
        }

        expect(backgroundAssets, hasLength(10), reason: '$arcId scene art');
        expect(
          allBackgroundAssets.intersection(backgroundAssets),
          isEmpty,
          reason: '$arcId reuses another arc scene asset',
        );
        allBackgroundAssets.addAll(backgroundAssets);
        var squareScenes = 0;
        var finaleScenes = 0;
        for (final asset in backgroundAssets) {
          expect(
            asset,
            startsWith('assets/art/arcs/$arcSlug/backgrounds/'),
            reason: arcId,
          );
          expect(File(asset).existsSync(), isTrue, reason: asset);
          expect(
            allBackgroundSignatures.add(_fileSignature(asset)),
            isTrue,
            reason: '$asset duplicates another expansion scene file',
          );
          final scene = _decodeAny(asset);
          if (scene.width == 1024 && scene.height == 1024) {
            squareScenes++;
          } else if (scene.width == 1024 && scene.height == 1536) {
            finaleScenes++;
          } else {
            fail(
              '$asset has unexpected dimensions ${scene.width}x${scene.height}',
            );
          }
        }
        expect(squareScenes, 8, reason: '$arcId chapter paintings');
        expect(finaleScenes, 2, reason: '$arcId finale paintings');
      }

      expect(allCastAssets, hasLength(30));
      expect(allBackgroundAssets, hasLength(100));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'every story arc owns a distinct complete opponent roster',
    () {
      final allAssets = <String>{};
      final allImageSignatures = <int>{};
      final manifest =
          jsonDecode(File('assets/content/manifest.json').readAsStringSync())
              as Map<String, Object?>;
      final descriptors = manifest['arcs']! as List<Object?>;
      expect(descriptors, isNotEmpty);

      for (final descriptorValue in descriptors) {
        final descriptor = descriptorValue! as Map<String, Object?>;
        final metadataPath = descriptor['metadataAsset']! as String;
        final metadata =
            jsonDecode(File(metadataPath).readAsStringSync())
                as Map<String, Object?>;
        final arcId = metadata['id']! as String;
        final assets = <String>[];
        final bossAssets = <String>[];
        for (final chapterValue in metadata['chapters']! as List<Object?>) {
          final chapter = chapterValue! as Map<String, Object?>;
          final boss = chapter['boss']! as Map<String, Object?>;
          final bossAsset = boss['spriteAsset']! as String;
          bossAssets.add(bossAsset);
          assets.add(bossAsset);
          for (final encounterValue
              in chapter['encounters'] as List<Object?>? ?? const []) {
            final encounter = encounterValue! as Map<String, Object?>;
            assets.add(encounter['spriteAsset']! as String);
          }
        }

        expect(
          bossAssets.length,
          greaterThanOrEqualTo(8),
          reason: '$arcId must provide at least eight chapter bosses',
        );
        expect(assets.toSet(), hasLength(assets.length), reason: arcId);
        expect(allAssets.intersection(assets.toSet()), isEmpty, reason: arcId);
        allAssets.addAll(assets);
        for (final asset in assets) {
          expect(File(asset).existsSync(), isTrue, reason: asset);
          final atlas = _decode(asset);
          expect(atlas.width, 768, reason: asset);
          expect(atlas.height, 1152, reason: asset);
          final imageSignature = _expectCleanPixelArtAlpha(
            atlas,
            reason: asset,
          );
          expect(
            allImageSignatures.add(imageSignature),
            isTrue,
            reason: '$asset duplicates another story arc opponent atlas',
          );
          _expectAnimatedAtlas(atlas, columns: 4, rows: 6, reason: asset);
          _expectTransparentCellGutters(
            atlas,
            columns: 4,
            rows: 6,
            gutter: 8,
            reason: asset,
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

int _expectCleanPixelArtAlpha(image_lib.Image atlas, {String? reason}) {
  var partialAlpha = 0;
  var chromaPixels = 0;
  var signature = 0x811c9dc5;
  for (final pixel in atlas) {
    final alpha = pixel.a.toInt();
    final rgba =
        (pixel.r.toInt() << 24) |
        (pixel.g.toInt() << 16) |
        (pixel.b.toInt() << 8) |
        alpha;
    signature = ((signature ^ rgba) * 0x01000193) & 0x7fffffff;
    if (alpha != 0 && alpha != 255) partialAlpha++;
    if (alpha == 0) continue;
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    final looksLikeMagentaKey = red > 230 && green < 50 && blue > 230;
    final looksLikeGreenKey = red < 50 && green > 230 && blue < 50;
    if (looksLikeMagentaKey || looksLikeGreenKey) chromaPixels++;
  }
  expect(
    partialAlpha,
    0,
    reason: '${reason ?? 'atlas'} contains soft-alpha fringe pixels',
  );
  expect(
    chromaPixels,
    0,
    reason: '${reason ?? 'atlas'} retains chroma-key pixels',
  );
  return signature;
}

int _pixelSignature(image_lib.Image image) {
  var signature = 0x811c9dc5;
  for (final pixel in image) {
    final rgba =
        (pixel.r.toInt() << 24) |
        (pixel.g.toInt() << 16) |
        (pixel.b.toInt() << 8) |
        pixel.a.toInt();
    signature = ((signature ^ rgba) * 0x01000193) & 0x7fffffff;
  }
  return signature;
}

image_lib.Image _decode(String path) {
  final decoded = image_lib.decodePng(File(path).readAsBytesSync());
  expect(decoded, isNotNull, reason: path);
  return decoded!;
}

image_lib.Image _decodeAny(String path) {
  final decoded = image_lib.decodeImage(File(path).readAsBytesSync());
  expect(decoded, isNotNull, reason: path);
  return decoded!;
}

int _fileSignature(String path) {
  var signature = 0x811c9dc5;
  for (final byte in File(path).readAsBytesSync()) {
    signature = ((signature ^ byte) * 0x01000193) & 0x7fffffff;
  }
  return signature;
}

void _expectAnimatedAtlas(
  image_lib.Image atlas, {
  required int columns,
  required int rows,
  String? reason,
}) {
  expect(atlas.width % columns, 0, reason: reason);
  expect(atlas.height % rows, 0, reason: reason);
  final cellWidth = atlas.width ~/ columns;
  final cellHeight = atlas.height ~/ rows;
  var transparentPixels = 0;

  for (var row = 0; row < rows; row++) {
    final signatures = <int>{};
    for (var column = 0; column < columns; column++) {
      var occupiedPixels = 0;
      var signature = 0x811c9dc5;
      for (var y = row * cellHeight; y < (row + 1) * cellHeight; y += 2) {
        for (var x = column * cellWidth; x < (column + 1) * cellWidth; x += 2) {
          final pixel = atlas.getPixel(x, y);
          if (pixel.a < 16) {
            transparentPixels++;
            continue;
          }
          occupiedPixels++;
          final rgba =
              (pixel.r.toInt() << 24) |
              (pixel.g.toInt() << 16) |
              (pixel.b.toInt() << 8) |
              pixel.a.toInt();
          signature = ((signature ^ rgba) * 0x01000193) & 0x7fffffff;
        }
      }
      expect(
        occupiedPixels,
        greaterThan(40),
        reason: '${reason ?? 'knight finisher'} row $row frame $column',
      );
      signatures.add(signature);
    }
    expect(
      signatures,
      hasLength(columns),
      reason: '${reason ?? 'knight finisher'} row $row repeats a frame',
    );
  }
  expect(transparentPixels, greaterThan(0), reason: reason);
}

void _expectTransparentCellGutters(
  image_lib.Image atlas, {
  required int columns,
  required int rows,
  required int gutter,
  String? reason,
}) {
  final cellWidth = atlas.width ~/ columns;
  final cellHeight = atlas.height ~/ rows;
  final offenders = <String>[];
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      var occupied = 0;
      for (var localY = 0; localY < cellHeight; localY++) {
        for (var localX = 0; localX < cellWidth; localX++) {
          if (localX >= gutter &&
              localX < cellWidth - gutter &&
              localY >= gutter &&
              localY < cellHeight - gutter) {
            continue;
          }
          final pixel = atlas.getPixel(
            column * cellWidth + localX,
            row * cellHeight + localY,
          );
          if (pixel.a >= 16) occupied++;
        }
      }
      if (occupied > 0) offenders.add('row $row frame $column ($occupied)');
    }
  }
  expect(
    offenders,
    isEmpty,
    reason:
        '${reason ?? 'atlas'} crosses a cell gutter: ${offenders.join(', ')}',
  );
}

void _expectHeroCombatAtlas(image_lib.Image atlas, {required String reason}) {
  const xBoundaries = <int>[0, 240, 490, 685, 900, 1110, 1310, 1520, 1774];
  const yBoundaries = <int>[0, 220, 415, 605, 887];
  final gutterOffenders = <String>[];
  for (var row = 0; row < 4; row++) {
    final activeColumns = row == 3 ? 4 : 8;
    final signatures = <int>{};
    for (var column = 0; column < 8; column++) {
      final left = xBoundaries[column];
      final right = xBoundaries[column + 1];
      final top = yBoundaries[row];
      final bottom = yBoundaries[row + 1];
      var occupiedPixels = 0;
      var gutterPixels = 0;
      var signature = 0x811c9dc5;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final pixel = atlas.getPixel(x, y);
          if (pixel.a == 0) continue;
          occupiedPixels++;
          final inGutter =
              x < left + 10 ||
              x >= right - 10 ||
              y < top + 10 ||
              y >= bottom - 10;
          if (inGutter) gutterPixels++;
          if (x.isEven && y.isEven) {
            final rgba =
                (pixel.r.toInt() << 24) |
                (pixel.g.toInt() << 16) |
                (pixel.b.toInt() << 8) |
                pixel.a.toInt();
            signature = ((signature ^ rgba) * 0x01000193) & 0x7fffffff;
          }
        }
      }
      if (column < activeColumns) {
        expect(
          occupiedPixels,
          greaterThan(160),
          reason: '$reason row $row frame $column',
        );
        signatures.add(signature);
        if (gutterPixels > 0) {
          gutterOffenders.add('row $row frame $column ($gutterPixels)');
        }
      } else {
        expect(
          occupiedPixels,
          0,
          reason: '$reason row $row frame $column must remain unused',
        );
      }
    }
    expect(
      signatures,
      hasLength(activeColumns),
      reason: '$reason row $row repeats a frame',
    );
  }
  expect(
    gutterOffenders,
    isEmpty,
    reason:
        '$reason crosses a combat cell gutter: ${gutterOffenders.join(', ')}',
  );
}

void _expectNoLongVerticalContentEdges(
  image_lib.Image atlas, {
  required int columns,
  required int rows,
  required int maxRun,
  String? reason,
}) {
  final cellWidth = atlas.width ~/ columns;
  final cellHeight = atlas.height ~/ rows;
  final offenders = <String>[];
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      var left = cellWidth;
      var right = -1;
      var top = cellHeight;
      var bottom = -1;
      for (var y = 0; y < cellHeight; y++) {
        for (var x = 0; x < cellWidth; x++) {
          final pixel = atlas.getPixel(
            column * cellWidth + x,
            row * cellHeight + y,
          );
          if (pixel.a < 16) continue;
          left = left < x ? left : x;
          right = right > x ? right : x;
          top = top < y ? top : y;
          bottom = bottom > y ? bottom : y;
        }
      }
      if (right < left || bottom < top) continue;
      final leftRun = _longestAlphaRun(
        atlas,
        x: column * cellWidth + left,
        top: row * cellHeight + top,
        bottom: row * cellHeight + bottom,
      );
      final rightRun = _longestAlphaRun(
        atlas,
        x: column * cellWidth + right,
        top: row * cellHeight + top,
        bottom: row * cellHeight + bottom,
      );
      if (leftRun > maxRun || rightRun > maxRun) {
        offenders.add(
          'row $row frame $column (left $leftRun, right $rightRun)',
        );
      }
    }
  }
  expect(
    offenders,
    isEmpty,
    reason:
        '${reason ?? 'atlas'} contains a likely pre-cropped vertical effect: '
        '${offenders.join(', ')}',
  );
}

int _longestAlphaRun(
  image_lib.Image atlas, {
  required int x,
  required int top,
  required int bottom,
}) {
  var longest = 0;
  var current = 0;
  for (var y = top; y <= bottom; y++) {
    if (atlas.getPixel(x, y).a >= 16) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 0;
    }
  }
  return longest;
}
