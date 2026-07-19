import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/widgets/pixel_ui.dart';

void main() {
  test('organic border keeps straight edges and pixel-stepped corners', () {
    const border = PixelOrganicBorder(side: BorderSide(width: 2));
    const rect = Rect.fromLTWH(0, 0, 100, 48);

    final outer = border.getOuterPath(rect);
    final inner = border.getInnerPath(rect);

    expect(outer.getBounds(), rect);
    expect(outer.contains(const Offset(.5, .5)), isFalse);
    expect(outer.contains(const Offset(6.5, .5)), isTrue);
    expect(outer.contains(const Offset(4.5, .5)), isFalse);
    expect(outer.contains(const Offset(4.5, 2.5)), isTrue);
    expect(outer.contains(const Offset(2.5, 2.5)), isFalse);
    expect(outer.contains(rect.center), isTrue);
    expect(inner.getBounds(), const Rect.fromLTWH(2, 2, 96, 44));
    expect(border.copyWith(), border);
    expect(const PixelOrganicBorder.compact().radius, 5);
  });

  testWidgets('every pixel glyph renders at each supported size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Wrap(
            children: [
              for (final glyph in PixelGlyph.values)
                for (final size in const [16.0, 24.0, 32.0])
                  PixelIcon(glyph, size: size),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PixelIcon), findsNWidgets(PixelGlyph.values.length * 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pixel icons expose or exclude their semantic label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            PixelIcon(PixelGlyph.book, semanticLabel: 'Rules'),
            PixelIcon(
              PixelGlyph.gear,
              semanticLabel: 'Hidden settings icon',
              excludeFromSemantics: true,
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Rules'), findsOneWidget);
    expect(find.bySemanticsLabel('Hidden settings icon'), findsNothing);
  });

  testWidgets('pixel icon button keeps a 48 pixel target and tooltip', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PixelIconButton(
            glyph: PixelGlyph.undo,
            tooltip: 'Undo move',
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Undo move'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
    await tester.tap(find.byType(PixelIconButton));
    expect(presses, 1);
    final target = tester.getRect(find.byType(IconButton));
    await tester.tapAt(target.topLeft + const Offset(3, 3));
    expect(presses, 2);
  });

  testWidgets('pixel panel paints an organic shadow without changing layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PixelPanel(child: SizedBox(width: 100, height: 40)),
        ),
      ),
    );

    final panel = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = panel.decoration as ShapeDecoration;
    expect(decoration.shape, isA<PixelOrganicBorder>());
    expect(decoration.shadows, isNotEmpty);
    expect(tester.getSize(find.byType(PixelPanel)), const Size(132, 72));
  });

  testWidgets('pixel toggle tile announces and changes its state', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder:
              (context, setState) => PixelToggleTile(
                title: const Text('Reduce motion'),
                subtitle: const Text('Minimize decorative movement'),
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(PixelToggleTile)),
      matchesSemantics(
        label: 'Reduce motion\nMinimize decorative movement',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: false,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('Reduce motion'));
    await tester.pump();
    expect(value, isTrue);
    final track = tester.widget<Container>(
      find.descendant(
        of: find.byType(PixelToggleTile),
        matching: find.byType(Container),
      ),
    );
    expect(
      (track.decoration as ShapeDecoration).shape,
      isA<PixelOrganicBorder>(),
    );
  });

  testWidgets(
    'pixel progress bar supports determinate and reduced-motion idle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Column(
              children: [
                SizedBox(
                  width: 240,
                  child: PixelProgressBar(
                    value: .5,
                    semanticLabel: 'Quest progress',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: PixelProgressBar(semanticLabel: 'Forging puzzle'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Quest progress')),
        matchesSemantics(label: 'Quest progress', value: '50%'),
      );
      expect(find.byType(PixelProgressBar), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
