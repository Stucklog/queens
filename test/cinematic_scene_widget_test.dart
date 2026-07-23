import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/arc_theme.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:regalia/widgets/cinematic_scene.dart';

void main() {
  testWidgets(
    'story scenes render arbitrary casts, per-frame art, and arc themes',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      final scene = StorySceneContent.fromJson({
        'id': 'regalia:scene/moon-court/opening',
        'role': 'opening',
        'defaults': {
          'background': {
            'asset': 'assets/art/backgrounds/story_opening.webp',
            'fit': 'cover',
          },
          'characters': [
            {
              'id': 'bearer',
              'character': 'crownBearer',
              'alignment': 'bottomLeft',
              'semanticLabel': 'The silver crown-bearer',
            },
            {
              'id': 'queen',
              'character': 'queen',
              'alignment': 'bottomRight',
              'semanticLabel': 'The Moon Queen',
            },
            {
              'id': 'rival',
              'asset': 'assets/art/knight.png',
              'alignment': 'center',
              'semanticLabel': 'The rival claimant',
              'zOrder': 3,
            },
          ],
        },
        'frames': [
          {
            'id': 'three-claimants',
            'title': 'Three Claimants',
            'paragraphs': ['Three figures met beneath a moonless sky.'],
            'semanticLabel': 'Three claimants meet in the silver court.',
            'actionLabel': 'Open the gate',
          },
          {
            'id': 'open-gate',
            'title': 'The Open Gate',
            'paragraphs': ['The gate opened onto a brighter court.'],
            'semanticLabel': 'The silver gate opens.',
            'actionLabel': 'Continue',
            'background': {
              'asset': 'assets/art/backgrounds/story_finale.webp',
              'fit': 'contain',
            },
            'characters': [
              {
                'id': 'new-antagonist',
                'asset': 'assets/art/knight.png',
                'alignment': 'bottomCenter',
                'mirrored': true,
                'semanticLabel': 'A newly revealed antagonist',
              },
            ],
          },
        ],
      });
      const arcTheme = ArcThemeColors(
        brightness: Brightness.light,
        background: Color(0xfff4ead7),
        surface: Color(0xfffffaf0),
        surfaceLow: Color(0xffead9bb),
        surfaceContainerHigh: Color(0xffe2ccaa),
        surfaceHigh: Color(0xffd7bd91),
        foreground: Color(0xff2b2118),
        mutedForeground: Color(0xff655848),
        outline: Color(0xff75634e),
        outlineVariant: Color(0xffbba88c),
        ink: Color(0xff17110c),
        danger: Color(0xffa22631),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StorySceneScreen.fromContent(
            controller: controller,
            scene: scene,
            palette: const JourneyPalette(
              primary: Color(0xff8567a8),
              secondary: Color(0xff9a641e),
              theme: arcTheme,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        arcTheme.background,
      );
      expect(
        find.byKey(const ValueKey('cinematic-character-bearer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-character-queen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-character-rival')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('The rival claimant'), findsOneWidget);
      expect(find.text('PROLOGUE · 1 of 2'), findsOneWidget);
      expect(
        tester
            .widget<CinematicSceneFrameView>(
              find.byKey(const ValueKey('cinematic-frame-three-claimants')),
            )
            .frame
            .background
            .asset,
        endsWith('story_opening.webp'),
      );
      expect(
        tester
            .widget<CinematicSceneFrameView>(
              find.byKey(const ValueKey('cinematic-frame-three-claimants')),
            )
            .backgroundFitOverride,
        BoxFit.contain,
      );

      await tester.tap(find.text('Open the gate'));
      await tester.pumpAndSettle();

      expect(find.text('PROLOGUE · 2 of 2'), findsOneWidget);
      expect(find.text('The Open Gate'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cinematic-character-new-antagonist')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-character-rival')),
        findsNothing,
      );
      expect(
        tester
            .widget<CinematicSceneFrameView>(
              find.byKey(const ValueKey('cinematic-frame-open-gate')),
            )
            .frame
            .background
            .asset,
        endsWith('story_finale.webp'),
      );
      expect(
        tester
            .widget<CinematicSceneFrameView>(
              find.byKey(const ValueKey('cinematic-frame-open-gate')),
            )
            .backgroundFitOverride,
        BoxFit.contain,
      );
    },
  );
}
