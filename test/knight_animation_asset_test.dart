import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('knight animation atlas is transparent and contains 32 poses', () {
    final atlas = image.decodePng(
      File('assets/art/knight_animations.png').readAsBytesSync(),
    );
    expect(atlas, isNotNull);
    expect(atlas!.width, 1774);
    expect(atlas.height, 887);
    expect(atlas.numChannels, 4);

    var transparentPixels = 0;
    var opaquePixels = 0;
    var opaqueChromaPixels = 0;
    for (final pixel in atlas) {
      if (pixel.a == 0) transparentPixels++;
      if (pixel.a >= 240) {
        opaquePixels++;
        if (pixel.r < 48 && pixel.g > 220 && pixel.b < 48) {
          opaqueChromaPixels++;
        }
      }
    }
    expect(transparentPixels, greaterThan(1_000_000));
    expect(opaquePixels, greaterThan(200_000));
    expect(opaqueChromaPixels, 0);

    const xBoundaries = <int>[0, 240, 490, 685, 900, 1110, 1310, 1520, 1774];
    const yBoundaries = <int>[0, 220, 415, 605, 887];
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 8; column++) {
        var visiblePixels = 0;
        for (var y = yBoundaries[row]; y < yBoundaries[row + 1]; y++) {
          for (var x = xBoundaries[column]; x < xBoundaries[column + 1]; x++) {
            if (atlas.getPixel(x, y).a >= 32) visiblePixels++;
          }
        }
        expect(
          visiblePixels,
          greaterThan(900),
          reason: 'row $row, column $column must contain a readable pose',
        );
      }
    }
  });
}
