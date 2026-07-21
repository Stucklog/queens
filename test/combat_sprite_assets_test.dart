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

  test('every story arc owns a distinct complete opponent roster', () {
    final allAssets = <String>{};
    final allImageSignatures = <int>{};
    for (final metadataPath in [
      'assets/content/arcs/origin/arc.json',
      'assets/content/arcs/atlas-of-borrowed-winds/arc.json',
    ]) {
      final metadata =
          jsonDecode(File(metadataPath).readAsStringSync())
              as Map<String, Object?>;
      final arcId = metadata['id']! as String;
      final assets = <String>[];
      for (final chapterValue in metadata['chapters']! as List<Object?>) {
        final chapter = chapterValue! as Map<String, Object?>;
        final boss = chapter['boss']! as Map<String, Object?>;
        assets.add(boss['spriteAsset']! as String);
        for (final encounterValue in chapter['encounters']! as List<Object?>) {
          final encounter = encounterValue! as Map<String, Object?>;
          assets.add(encounter['spriteAsset']! as String);
        }
      }

      expect(assets, hasLength(24), reason: arcId);
      expect(assets.toSet(), hasLength(24), reason: arcId);
      expect(allAssets.intersection(assets.toSet()), isEmpty, reason: arcId);
      allAssets.addAll(assets);
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
        final atlas = _decode(asset);
        expect(atlas.width, 768, reason: asset);
        expect(atlas.height, 1152, reason: asset);
        final imageSignature = _expectCleanPixelArtAlpha(atlas, reason: asset);
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
    expect(allAssets, hasLength(48));
  });
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

image_lib.Image _decode(String path) {
  final decoded = image_lib.decodePng(File(path).readAsBytesSync());
  expect(decoded, isNotNull, reason: path);
  return decoded!;
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
