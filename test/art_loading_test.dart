import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_art.dart';

void main() {
  testWidgets(
    'production art never exposes procedural fallbacks while loading',
    (tester) async {
      final chapter = challengeVisualChapters.first;
      final encounter = chapter.boss;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: false,
              child: Column(
                children: [
                  SizedBox(
                    width: 180,
                    height: 90,
                    child: PixelLandscape(
                      chapter: chapter,
                      brightness: Brightness.light,
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                    height: 72,
                    child: PixelStoryKnightSprite(),
                  ),
                  const SizedBox(
                    width: 48,
                    height: 72,
                    child: PixelKnightSprite(),
                  ),
                  const SizedBox(
                    width: 48,
                    height: 76,
                    child: PixelQueenSprite(),
                  ),
                  SizedBox(
                    width: 72,
                    height: 76,
                    child: PixelEnemySprite(
                      encounter: encounter,
                      stimulus: KnightAnimation.bounce,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('pixel-landscape-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('story-knight-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('knight-atlas-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('queen-art-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('enemy-atlas-loading')), findsOneWidget);
      expect(_allErrorFallbacks, findsNothing);
    },
  );

  testWidgets('a genuinely missing landscape keeps the graceful fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 90,
          child: PixelLandscape(
            chapter: challengeVisualChapters.first,
            brightness: Brightness.light,
            assetPath: 'assets/art/backgrounds/not-packaged.webp',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pixel-landscape-error-fallback')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pixel-landscape-loading')), findsNothing);
  });
}

final Finder _allErrorFallbacks = find.byWidgetPredicate(
  (widget) => switch (widget.key) {
    const ValueKey<String>('pixel-landscape-error-fallback') ||
    const ValueKey<String>('story-knight-error-fallback') ||
    const ValueKey<String>('knight-atlas-error-fallback') ||
    const ValueKey<String>('queen-art-error-fallback') ||
    const ValueKey<String>('enemy-atlas-error-fallback') => true,
    _ => false,
  },
);
