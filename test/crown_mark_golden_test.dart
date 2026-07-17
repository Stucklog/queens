@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/widgets/crown_mark.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  testWidgets('crown identity atlas remains balanced at production sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const ValueKey('crown-atlas'),
          child: Column(
            children: [
              _row(
                background: const Color(0xfffff8e8),
                foreground: const Color(0xff2b1b24),
                brightness: Brightness.light,
                children: const [
                  CrownMark(size: 24),
                  CrownMark(size: 28),
                  CrownMark(size: 64),
                  CrownMark(size: 88),
                ],
              ),
              _row(
                background: const Color(0xff151d3b),
                foreground: const Color(0xfffff3dc),
                brightness: Brightness.dark,
                children: const [
                  CrownMark(size: 24),
                  CrownMark(size: 28),
                  CrownMark(size: 64),
                  CrownMark(size: 88),
                ],
              ),
              _row(
                background: const Color(0xffdce8e2),
                foreground: const Color(0xff173f35),
                brightness: Brightness.light,
                children: const [
                  CrownMark(size: 30, color: Color(0xff1f6f5b)),
                  CrownMark(size: 30, color: Color(0xffb3261e)),
                  PixelStatusIcon(
                    glyph: PixelStatusGlyph.crown,
                    color: Color(0xff315c99),
                    size: 18,
                  ),
                  PixelStatusIcon(
                    glyph: PixelStatusGlyph.crown,
                    color: Color(0xff315c99),
                    size: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('crown-atlas')),
      matchesGoldenFile('goldens/crown_identity_atlas.png'),
    );
  });
}

Widget _row({
  required Color background,
  required Color foreground,
  required Brightness brightness,
  required List<Widget> children,
}) => Expanded(
  child: Theme(
    data: ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: foreground,
        brightness: brightness,
      ),
    ),
    child: ColoredBox(
      color: background,
      child: Row(
        children: [
          for (final child in children) Expanded(child: Center(child: child)),
        ],
      ),
    ),
  ),
);
