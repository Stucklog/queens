import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/content/cinematic_scene_models.dart';

void main() {
  group('CinematicScenePresentation', () {
    test('parses ordered frames, defaults, and arbitrary character layers', () {
      final presentation = CinematicScenePresentation.fromJson({
        'defaults': {
          'background': {
            'asset': 'assets/art/backgrounds/throne-room.png',
            'fit': 'cover',
          },
          'characters': [
            {
              'id': 'queen',
              'source': {'type': 'builtIn', 'character': 'queen'},
              'alignment': 'bottomRight',
              'size': {'height': 144},
              'semanticLabel': 'Queen Mara waits beside the throne.',
              'zOrder': 4,
            },
          ],
        },
        'frames': [
          {
            'id': 'quiet-hall',
            'narrative': {
              'title': 'A Quiet Hall',
              'paragraphs': ['No courtiers answered the opening doors.'],
              'semanticLabel': 'The Queen waits in an empty throne room.',
              'actionLabel': 'Enter the hall',
            },
          },
          {
            'id': 'confrontation',
            'narrative': {
              'title': 'The Confrontation',
              'paragraphs': [
                'The crown-bearer stepped between the Queen and the usurper.',
                'The usurper raised a hand and the windows went dark.',
              ],
              'semanticLabel': 'Three figures face one another in the hall.',
              'actionLabel': 'Stand firm',
            },
            'background': {
              'asset': 'assets/art/backgrounds/throne-room-dark.png',
              'fit': 'contain',
            },
            'characters': [
              {
                'id': 'queen',
                'character': 'queen',
                'alignment': {'x': .72, 'y': .58},
                'scale': .9,
                'size': {'width': 92, 'height': 145},
                'mirrored': true,
                'semanticLabel': 'Queen Mara',
                'zOrder': 10,
              },
              {
                'id': 'usurper',
                'source': {
                  'type': 'asset',
                  'asset': 'assets/art/characters/usurper.png',
                },
                'alignment': 'center',
                'size': 128,
                'semanticLabel': 'The masked usurper',
                'zOrder': -2,
              },
              {
                'id': 'bearer',
                'source': 'crown-bearer',
                'alignment': 'bottom-left',
                'semanticLabel': 'The crown-bearer',
                'zOrder': 2,
              },
            ],
          },
          {
            'id': 'empty-dais',
            'title': 'The Empty Dais',
            'caption': 'Only the abandoned crown remained on the stone.',
            'backgroundAsset': 'assets/art/backgrounds/empty-dais.png',
            'backgroundFit': 'fitWidth',
            'characters': <Object?>[],
          },
        ],
      });

      expect(
        presentation.frames.map((frame) => frame.id),
        orderedEquals(['quiet-hall', 'confrontation', 'empty-dais']),
      );

      final inherited = presentation.frames.first;
      expect(inherited.background.asset, endsWith('throne-room.png'));
      expect(inherited.background.fit, CinematicBackgroundFit.cover);
      expect(inherited.characterLayers, hasLength(1));
      final inheritedQueen = inherited.characterLayers.single;
      expect(
        (inheritedQueen.source as CinematicBuiltInCharacterSource).character,
        CinematicBuiltInCharacter.queen,
      );
      expect(inheritedQueen.size?.height, 144);

      final confrontation = presentation.frameById('confrontation');
      expect(confrontation.narrative.paragraphs, hasLength(2));
      expect(confrontation.background.fit, CinematicBackgroundFit.contain);
      expect(
        confrontation.characterLayersInPaintOrder.map((layer) => layer.id),
        orderedEquals(['usurper', 'bearer', 'queen']),
      );
      final queen = confrontation.characterLayers.first;
      expect(queen.alignment.x, .72);
      expect(queen.alignment.y, .58);
      expect(queen.scale, .9);
      expect(queen.size?.width, 92);
      expect(queen.size?.height, 145);
      expect(queen.mirrored, isTrue);
      expect(queen.semanticLabel, 'Queen Mara');
      final usurper = confrontation.characterLayers[1];
      expect(
        (usurper.source as CinematicAssetCharacterSource).asset,
        'assets/art/characters/usurper.png',
      );
      expect(usurper.size?.width, 128);
      expect(usurper.size?.height, 128);

      final emptyDais = presentation.frames.last;
      expect(emptyDais.narrative.actionLabel, 'Continue');
      expect(emptyDais.narrative.semanticLabel, 'The Empty Dais');
      expect(emptyDais.background.fit, CinematicBackgroundFit.fitWidth);
      expect(emptyDais.characterLayers, isEmpty);

      expect(() => presentation.frames.clear(), throwsUnsupportedError);
      expect(
        () => confrontation.narrative.paragraphs.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => confrontation.characterLayers.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => confrontation.characterLayersInPaintOrder.clear(),
        throwsUnsupportedError,
      );
    });

    test('parses sprite-sheet timing and reduced-motion behavior', () {
      final layer = CinematicCharacterLayer.fromJson({
        'id': 'oracle',
        'asset': 'assets/art/characters/oracle-atlas.png',
        'alignment': {'x': -.25, 'y': .75},
        'semanticLabel': 'The oracle lifts her lantern.',
        'animation': {
          'frameCount': 4,
          'columns': 4,
          'rows': 2,
          'startFrame': 2,
          'framesPerSecond': 8,
          'loop': false,
          'reducedMotion': {'behavior': 'selectedFrame', 'frame': 2},
        },
      });

      final animation = layer.animation!;
      expect(animation.frameCount, 4);
      expect(animation.columns, 4);
      expect(animation.rows, 2);
      expect(animation.startFrame, 2);
      expect(animation.frameDuration, const Duration(milliseconds: 125));
      expect(animation.duration, const Duration(milliseconds: 500));
      expect(animation.loop, isFalse);
      expect(
        animation.reducedMotion.behavior,
        CinematicReducedMotionBehavior.selectedFrame,
      );
      expect(animation.reducedMotion.resolvedFrame(4), 2);

      final hidden = CinematicSpriteAnimation.fromJson({
        'frameCount': 6,
        'frameDurationMs': 90,
        'reducedMotion': 'hideLayer',
      });
      expect(hidden.columns, 6);
      expect(hidden.rows, 1);
      expect(
        hidden.reducedMotion.behavior,
        CinematicReducedMotionBehavior.hideLayer,
      );
      expect(hidden.reducedMotion.resolvedFrame(6), isNull);

      final still = CinematicSpriteAnimation.fromJson({'frameCount': 3});
      expect(still.frameDuration, const Duration(milliseconds: 150));
      expect(still.loop, isTrue);
      expect(still.reducedMotion.resolvedFrame(3), 0);
    });

    test('converts legacy paged opening and finale scene shapes', () {
      final opening = CinematicScenePresentation.fromJson({
        'id': 'regalia:scene/origin/opening',
        'role': 'opening',
        'artAsset': 'assets/art/backgrounds/story_opening.webp',
        'pages': [
          {
            'title': 'The Dark Star',
            'paragraphs': ['A dark star covered the sun.'],
            'semanticLabel': 'The dark star above the citadel.',
            'actionLabel': 'Follow the falling crown',
          },
          {
            'title': 'The Choice',
            'paragraphs': ['A traveler lifted the crown.'],
            'semanticLabel': 'A traveler chooses the dark road.',
            'actionLabel': 'Begin the journey',
          },
        ],
      });

      expect(opening.frames, hasLength(2));
      expect(
        opening.frames.map((frame) => frame.id),
        orderedEquals(['frame-1', 'frame-2']),
      );
      expect(
        opening.frames.every(
          (frame) =>
              frame.background.asset.endsWith('story_opening.webp') &&
              frame.background.fit == CinematicBackgroundFit.cover,
        ),
        isTrue,
      );
      expect(opening.frames.first.characterLayers, hasLength(1));
      expect(
        (opening.frames.first.characterLayers.single.source
                as CinematicBuiltInCharacterSource)
            .character,
        CinematicBuiltInCharacter.crownBearer,
      );

      final finale = CinematicScenePresentation.fromJson({
        'role': 'finale',
        'artAsset': 'assets/art/backgrounds/story_finale.webp',
        'title': 'Dawn',
        'caption': 'The restored roads shone in the sunrise.',
        'semanticLabel': 'The Queen and crown-bearer watch the sunrise.',
        'actionLabel': 'Return to the map',
      });

      expect(finale.frames, hasLength(1));
      expect(finale.frames.single.id, 'frame-1');
      expect(finale.frames.single.narrative.paragraphs, [
        'The restored roads shone in the sunrise.',
      ]);
      expect(
        finale.frames.single.characterLayers.map((layer) => layer.id),
        orderedEquals(['crown-bearer', 'queen']),
      );
      expect(finale.frames.single.characterLayers.last.mirrored, isTrue);
    });

    test('reports malformed content as FormatException with useful paths', () {
      Map<String, Object?> sceneWithFrame(Map<String, Object?> frame) => {
        'backgroundAsset': 'assets/art/backgrounds/hall.png',
        'frames': [
          {
            'id': 'test',
            'title': 'Test',
            'paragraphs': ['Test narrative.'],
            ...frame,
          },
        ],
      };

      expect(
        () => CinematicScenePresentation.fromJson({'frames': 'not-an-array'}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(r'$scene.frames'),
          ),
        ),
      );
      expect(
        () => CinematicScenePresentation.fromJson({'frames': <Object?>[]}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicScenePresentation.fromJson(
          sceneWithFrame({'backgroundFit': 'stretch-ish'}),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicScenePresentation.fromJson(
          sceneWithFrame({
            'characters': [
              {'asset': '../outside.png', 'semanticLabel': 'Unsafe character'},
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicScenePresentation.fromJson(
          sceneWithFrame({
            'characters': [
              {'character': 'duchess', 'semanticLabel': 'Unknown built-in'},
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicScenePresentation.fromJson(
          sceneWithFrame({
            'characters': [
              {
                'character': 'queen',
                'alignment': {'x': 1.2, 'y': 0},
              },
            ],
          }),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () =>
            CinematicSpriteAnimation.fromJson({'frameCount': 3, 'columns': 0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicSpriteAnimation.fromJson({
          'frameCount': 3,
          'columns': 3,
          'rows': 1,
          'startFrame': 1,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CinematicSpriteAnimation.fromJson({
          'frameCount': 3,
          'reducedMotion': {'behavior': 'frame', 'frame': 3},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate frame and character layer ids', () {
      final background = CinematicFrameBackground(
        asset: 'assets/art/backgrounds/hall.png',
      );
      final narrative = CinematicFrameNarrative(
        title: 'Test',
        paragraphs: ['A test frame.'],
        semanticLabel: 'A test frame.',
      );
      final queen = CinematicCharacterLayer(
        id: 'queen',
        source: const CinematicBuiltInCharacterSource(
          CinematicBuiltInCharacter.queen,
        ),
        semanticLabel: 'The Queen',
      );

      expect(
        () => CinematicSceneFrame(
          id: 'one',
          narrative: narrative,
          background: background,
          characterLayers: [queen, queen],
        ),
        throwsA(isA<FormatException>()),
      );

      final frame = CinematicSceneFrame(
        id: 'one',
        narrative: narrative,
        background: background,
      );
      expect(
        () => CinematicScenePresentation(frames: [frame, frame]),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
