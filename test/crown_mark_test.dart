import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/widgets/crown_mark.dart';

void main() {
  testWidgets('brand and board crowns stay bilaterally symmetrical', (
    tester,
  ) async {
    const marks = <CrownMark>[
      CrownMark(size: 24),
      CrownMark(size: 64),
      CrownMark(size: 88),
      CrownMark(size: 30, color: Color(0xff1f6f5b)),
      CrownMark(size: 30, color: Color(0xffb3261e)),
    ];

    for (final mark in marks) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: RepaintBoundary(key: key, child: mark)),
        ),
      );
      await tester.pump();

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final raster = await tester.runAsync(() async {
        final rendered = await boundary.toImage(pixelRatio: 1);
        final bytes = await rendered.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = (
          pixels: bytes!.buffer.asUint8List(),
          width: rendered.width,
          height: rendered.height,
        );
        rendered.dispose();
        return result;
      });
      expect(raster, isNotNull);
      _expectHorizontalSymmetry(
        raster!.pixels,
        raster.width,
        raster.height,
        reason: '${mark.style.name} crown at ${mark.size}px',
      );
    }
  });
}

void _expectHorizontalSymmetry(
  Uint8List pixels,
  int width,
  int height, {
  required String reason,
}) {
  final maximumDelta = <int>[0, 0, 0, 0];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width ~/ 2; x++) {
      final left = (y * width + x) * 4;
      final right = (y * width + width - 1 - x) * 4;
      for (var channel = 0; channel < 4; channel++) {
        final delta = (pixels[left + channel] - pixels[right + channel]).abs();
        if (delta > maximumDelta[channel]) maximumDelta[channel] = delta;
      }
    }
  }
  expect(
    maximumDelta.take(3),
    everyElement(lessThanOrEqualTo(16)),
    reason: '$reason has asymmetric raster color: $maximumDelta.',
  );
  expect(
    maximumDelta[3],
    lessThanOrEqualTo(28),
    reason: '$reason has an asymmetric silhouette: $maximumDelta.',
  );
}
