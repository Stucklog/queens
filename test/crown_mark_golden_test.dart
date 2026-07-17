@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/crown_mark.dart';
import 'package:regalia/widgets/pixel_ui.dart';

void main() {
  testWidgets('midnight crown identity remains balanced at production sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RegaliaTheme.midnight(),
        home: RepaintBoundary(
          key: const ValueKey('crown-atlas'),
          child: Column(
            children: [
              _row(
                background: const Color(0xff080d20),
                children: const [
                  CrownMark(size: 24),
                  CrownMark(size: 28),
                  CrownMark(size: 64),
                  CrownMark(size: 88),
                ],
              ),
              _row(
                background: const Color(0xff151d3b),
                children: const [
                  CrownMark(size: 30),
                  CrownMark(size: 30, color: Color(0xffd6af53)),
                  CrownMark(size: 30, color: Color(0xffff766f)),
                  CrownMark(size: 72),
                ],
              ),
              _row(
                background: const Color(0xff20294b),
                children: const [
                  PixelIcon(
                    PixelGlyph.crown,
                    color: Color(0xffd6af53),
                    size: 16,
                  ),
                  PixelIcon(
                    PixelGlyph.crown,
                    color: Color(0xffd6af53),
                    size: 32,
                  ),
                  CrownMark(size: 24, color: Color(0xff6fc6ca)),
                  CrownMark(size: 30, color: Color(0xffff766f)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('crown-atlas')),
      matchesGoldenFile('goldens/crown_identity_atlas_midnight.png'),
    );
  });
}

Widget _row({required Color background, required List<Widget> children}) =>
    Expanded(
      child: ColoredBox(
        color: background,
        child: Row(
          children: [
            for (final child in children) Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );
