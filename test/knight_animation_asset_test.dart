import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('knight animation atlas matches the regular combat sprite contract', () {
    final atlas = image.decodePng(
      File('assets/art/knight_animations.png').readAsBytesSync(),
    );
    expect(atlas, isNotNull);
    expect(atlas!.width, 768);
    expect(atlas.height, 1344);
    expect(atlas.numChannels, 4);

    var transparentPixels = 0;
    var opaquePixels = 0;
    var partialAlphaPixels = 0;
    var chromaPixels = 0;
    for (final pixel in atlas) {
      if (pixel.a == 0) transparentPixels++;
      if (pixel.a != 0 && pixel.a != 255) partialAlphaPixels++;
      if (pixel.a == 255) {
        opaquePixels++;
        final looksGreen = pixel.r < 50 && pixel.g > 230 && pixel.b < 50;
        final looksMagenta = pixel.r > 230 && pixel.g < 50 && pixel.b > 230;
        if (looksGreen || looksMagenta) chromaPixels++;
      }
    }
    expect(transparentPixels, greaterThan(350_000));
    expect(opaquePixels, greaterThan(100_000));
    expect(partialAlphaPixels, 0);
    expect(chromaPixels, 0);

    final signatures = <String>{};
    for (var row = 0; row < 7; row++) {
      final rowSignatures = <String>{};
      for (var column = 0; column < 4; column++) {
        final cell = image.copyCrop(
          atlas,
          x: column * 192,
          y: row * 192,
          width: 192,
          height: 192,
        );
        var visiblePixels = 0;
        for (final pixel in cell) {
          if (pixel.a == 255) visiblePixels++;
        }
        for (var edge = 0; edge < 8; edge++) {
          for (var offset = 0; offset < 192; offset++) {
            expect(
              cell.getPixel(edge, offset).a,
              0,
              reason: 'row $row, column $column touches the left gutter',
            );
            expect(
              cell.getPixel(191 - edge, offset).a,
              0,
              reason: 'row $row, column $column touches the right gutter',
            );
            expect(
              cell.getPixel(offset, edge).a,
              0,
              reason: 'row $row, column $column touches the top gutter',
            );
            expect(
              cell.getPixel(offset, 191 - edge).a,
              0,
              reason: 'row $row, column $column touches the bottom gutter',
            );
          }
        }
        expect(
          visiblePixels,
          greaterThan(1_000),
          reason: 'row $row, column $column must contain a readable pose',
        );
        final signature = base64Encode(image.encodePng(cell));
        rowSignatures.add(signature);
        signatures.add(signature);
      }
      expect(rowSignatures, hasLength(4), reason: 'row $row must animate');
    }
    expect(signatures, hasLength(28));
  });
}
