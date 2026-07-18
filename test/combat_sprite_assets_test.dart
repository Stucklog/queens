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
  });

  test('every declared opponent has a complete six-reaction atlas', () {
    final metadata =
        jsonDecode(
              File('assets/content/arcs/origin/arc.json').readAsStringSync(),
            )
            as Map<String, Object?>;
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

    expect(assets, hasLength(24));
    expect(assets.toSet(), hasLength(24));
    for (final asset in assets) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      final atlas = _decode(asset);
      expect(atlas.width, 768, reason: asset);
      expect(atlas.height, 1152, reason: asset);
      _expectCleanPixelArtAlpha(atlas, reason: asset);
      _expectAnimatedAtlas(atlas, columns: 4, rows: 6, reason: asset);
      _expectTransparentCellGutters(
        atlas,
        columns: 4,
        rows: 6,
        gutter: 8,
        reason: asset,
      );
    }
  });
}

void _expectCleanPixelArtAlpha(image_lib.Image atlas, {String? reason}) {
  var partialAlpha = 0;
  var chromaPixels = 0;
  for (final pixel in atlas) {
    final alpha = pixel.a.toInt();
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
