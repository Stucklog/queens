import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  setUpAll(PixelKnightSprite.preload);

  testWidgets('only opening and finale cinematics retain character sprites', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SizedBox(
          width: 430,
          height: 600,
          child: PixelStoryScene(
            chapter: challengeVisualChapters.first,
            kind: PixelSceneKind.finale,
            semanticLabel: 'Finale artwork',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PixelStoryKnightSprite), findsOneWidget);
    expect(find.byType(PixelKnightSprite), findsNothing);
    expect(
      tester.widget<PixelQueenSprite>(find.byType(PixelQueenSprite)).faceLeft,
      isTrue,
    );
    final artwork = tester.widget<Image>(
      find.byKey(const ValueKey('story-knight-artwork')),
    );
    expect(artwork.image, isA<AssetImage>());
    expect(
      (artwork.image as AssetImage).assetName,
      PixelStoryKnightSprite.assetPath,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SizedBox(
          width: 430,
          height: 600,
          child: PixelStoryScene(
            chapter: challengeVisualChapters.first,
            kind: PixelSceneKind.opening,
            semanticLabel: 'Opening artwork',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PixelStoryKnightSprite), findsOneWidget);
    expect(find.byType(PixelQueenSprite), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SizedBox(
          width: 430,
          height: 600,
          child: PixelStoryScene(
            chapter: challengeVisualChapters.first,
            kind: PixelSceneKind.chapter,
            semanticLabel: 'Chapter artwork',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PixelStoryKnightSprite), findsNothing);
    expect(find.byType(PixelKnightSprite), findsNothing);
    expect(find.byType(PixelQueenSprite), findsNothing);
    final chapterArtwork = tester.widget<Image>(
      find.descendant(
        of: find.byType(PixelStoryScene),
        matching: find.byType(Image),
      ),
    );
    expect(chapterArtwork.fit, BoxFit.contain);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: SizedBox(
          width: 430,
          height: 190,
          child: PixelStoryScene(
            chapter: challengeVisualChapters.first,
            kind: PixelSceneKind.panorama,
            placement: PixelArtPlacement.banner,
            semanticLabel: 'Challenge artwork',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PixelStoryKnightSprite), findsNothing);
    expect(find.byType(PixelKnightSprite), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
