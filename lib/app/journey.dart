import 'package:flutter/material.dart';

import '../content/content_ids.dart';
import '../core/models.dart';

const regaliaMidnight = Color(0xff151d3b);
const regaliaMidnightSurface = Color(0xff253052);

class JourneyPalette {
  const JourneyPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  Color get background => regaliaMidnight;
  Color get surface => regaliaMidnightSurface;
}

class JourneyChapter {
  const JourneyChapter({
    required this.id,
    required this.mapId,
    required this.sceneId,
    required this.artKey,
    required this.artAsset,
    required this.visualIndex,
    required this.title,
    required this.caption,
    required this.startOrder,
    required this.endOrder,
    required this.difficulty,
    required this.size,
    required this.palette,
  });

  final String id;
  final String mapId;
  final String sceneId;
  final String artKey;
  final String artAsset;
  final int visualIndex;
  final String title;
  final String caption;
  final int startOrder;
  final int endOrder;
  final DifficultyTier difficulty;
  final int size;
  final JourneyPalette palette;

  String get storyBeatId => sceneId;

  bool contains(int order) => order >= startOrder && order <= endOrder;

  factory JourneyChapter.fromJson(Map<String, Object?> json) {
    Color color(String key) {
      final value = json[key]! as String;
      if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
        throw FormatException('Invalid $key color $value');
      }
      return Color(int.parse('ff${value.substring(1)}', radix: 16));
    }

    final id = json['id']! as String;
    final mapId = json['mapId']! as String;
    final sceneId = json['sceneId']! as String;
    ContentId.parse(id, expectedKind: 'chapter');
    ContentId.parse(mapId, expectedKind: 'map');
    ContentId.parse(sceneId, expectedKind: 'scene');
    return JourneyChapter(
      id: id,
      mapId: mapId,
      sceneId: sceneId,
      artKey: json['artKey']! as String,
      artAsset: json['artAsset']! as String,
      visualIndex: (json['visualIndex']! as num).toInt(),
      title: json['title']! as String,
      caption: json['caption']! as String,
      startOrder: (json['startOrder']! as num).toInt(),
      endOrder: (json['endOrder']! as num).toInt(),
      difficulty: DifficultyTierLabel.parse(json['difficulty']! as String),
      size: (json['size']! as num).toInt(),
      palette: JourneyPalette(
        primary: color('primaryColor'),
        secondary: color('secondaryColor'),
      ),
    );
  }
}

/// Offline visual fallback for Just Puzzle and compatibility helpers in tests.
/// The story UI uses the chapters loaded from the active [StoryArc].
const journeyChapters = <JourneyChapter>[
  JourneyChapter(
    id: 'regalia:chapter/origin/clovermead',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/clovermead',
    artKey: 'clovermead',
    artAsset: 'assets/art/backgrounds/chapter_clovermead.webp',
    visualIndex: 0,
    title: 'Asterfall Vale',
    caption:
        'Where heaven struck the earth, the fallen Regalia chooses its bearer.',
    startOrder: 1,
    endOrder: 20,
    difficulty: DifficultyTier.easy,
    size: 6,
    palette: JourneyPalette(
      primary: Color(0xff527663),
      secondary: Color(0xff5d9ab5),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/whisperwood',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/whisperwood',
    artKey: 'whisperwood',
    artAsset: 'assets/art/backgrounds/chapter_whisperwood.webp',
    visualIndex: 1,
    title: 'Myrrhveil Wilds',
    caption: 'Ancient roots part for the crown—and wake what sleeps below.',
    startOrder: 21,
    endOrder: 30,
    difficulty: DifficultyTier.easy,
    size: 7,
    palette: JourneyPalette(
      primary: Color(0xff365f50),
      secondary: Color(0xff704d78),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/windmill-heights',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/windmill-heights',
    artKey: 'windmill-heights',
    artAsset: 'assets/art/backgrounds/chapter_windmill_heights.webp',
    visualIndex: 2,
    title: 'Skyglass Reach',
    caption:
        'Ancient wind arches awaken, carrying the bearer beyond the storm.',
    startOrder: 31,
    endOrder: 40,
    difficulty: DifficultyTier.medium,
    size: 7,
    palette: JourneyPalette(
      primary: Color(0xff536d88),
      secondary: Color(0xffa75b3b),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/sunken-cloister',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/sunken-cloister',
    artKey: 'sunken-cloister',
    artAsset: 'assets/art/backgrounds/chapter_sunken_cloister.webp',
    visualIndex: 3,
    title: 'Nacre Basilica',
    caption:
        'Beneath the drowned bells, a forgotten covenant opens the deep road.',
    startOrder: 41,
    endOrder: 60,
    difficulty: DifficultyTier.medium,
    size: 8,
    palette: JourneyPalette(
      primary: Color(0xff247f82),
      secondary: Color(0xff879e91),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/emberbell-caverns',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/emberbell-caverns',
    artKey: 'emberbell-caverns',
    artAsset: 'assets/art/backgrounds/chapter_emberbell_caverns.webp',
    visualIndex: 4,
    title: 'Pyreheart Caldera',
    caption: 'At the world’s molten heart, living crystal answers the crown.',
    startOrder: 61,
    endOrder: 80,
    difficulty: DifficultyTier.hard,
    size: 8,
    palette: JourneyPalette(
      primary: Color(0xff8d3e31),
      secondary: Color(0xffdb7a37),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/goblin-underkeep',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/goblin-underkeep',
    artKey: 'goblin-underkeep',
    artAsset: 'assets/art/backgrounds/chapter_goblin_underkeep.webp',
    visualIndex: 5,
    title: 'Brasswake Arsenal',
    caption: 'The old empire’s last war-engine wakes to bar the ascent.',
    startOrder: 81,
    endOrder: 90,
    difficulty: DifficultyTier.hard,
    size: 9,
    palette: JourneyPalette(
      primary: Color(0xff5b4c2a),
      secondary: Color(0xff91a934),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/moonlit-catacombs',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/moonlit-catacombs',
    artKey: 'moonlit-catacombs',
    artAsset: 'assets/art/backgrounds/chapter_moonlit_catacombs.webp',
    visualIndex: 6,
    title: 'Pale Moon Necropolis',
    caption:
        'Seven fallen queens rise beneath the pale moon to judge the bearer.',
    startOrder: 91,
    endOrder: 100,
    difficulty: DifficultyTier.expert,
    size: 9,
    palette: JourneyPalette(
      primary: Color(0xff514d82),
      secondary: Color(0xff9ca9c7),
    ),
  ),
  JourneyChapter(
    id: 'regalia:chapter/origin/crownspire',
    mapId: ContentIds.originMap,
    sceneId: 'regalia:scene/origin/crownspire',
    artKey: 'crownspire',
    artAsset: 'assets/art/backgrounds/chapter_crownspire.webp',
    visualIndex: 7,
    title: 'Empyrean Citadel',
    caption: 'Above the clouds, the vacant throne waits beneath a dying sun.',
    startOrder: 101,
    endOrder: 120,
    difficulty: DifficultyTier.expert,
    size: 10,
    palette: JourneyPalette(
      primary: Color(0xff244a98),
      secondary: Color(0xffbd8b2d),
    ),
  ),
];

JourneyChapter chapterForOrder(int order) => journeyChapters.firstWhere(
  (chapter) => chapter.contains(order),
  orElse: () => journeyChapters.last,
);

class JourneyProgress {
  const JourneyProgress({
    required this.frontierPuzzle,
    required this.completedCount,
    required this.cleanCount,
    required this.assistedCount,
    required this.inProgressPuzzleIds,
  });

  factory JourneyProgress.derive({
    required PuzzleCatalog catalog,
    required CompletionRecord Function(String id) recordFor,
    required bool Function(PuzzleDefinition puzzle) hasActiveBoard,
  }) {
    PuzzleDefinition? frontier;
    var completed = 0;
    var clean = 0;
    var assisted = 0;
    final active = <String>{};
    for (final puzzle in catalog.puzzles) {
      final status = recordFor(puzzle.id).status;
      if (status == CompletionStatus.cleanSolved) {
        clean++;
        completed++;
      } else if (status == CompletionStatus.assistedSolved) {
        assisted++;
        completed++;
      } else {
        frontier ??= puzzle;
      }
      if (hasActiveBoard(puzzle)) active.add(puzzle.id);
    }
    return JourneyProgress(
      frontierPuzzle: frontier,
      completedCount: completed,
      cleanCount: clean,
      assistedCount: assisted,
      inProgressPuzzleIds: Set.unmodifiable(active),
    );
  }

  final PuzzleDefinition? frontierPuzzle;
  final int completedCount;
  final int cleanCount;
  final int assistedCount;
  final Set<String> inProgressPuzzleIds;

  bool get isJourneyComplete => frontierPuzzle == null;

  bool isCompleted(PuzzleDefinition puzzle, CompletionRecord record) =>
      record.status == CompletionStatus.cleanSolved ||
      record.status == CompletionStatus.assistedSolved;

  bool canOpen(PuzzleDefinition puzzle, CompletionRecord record) =>
      isCompleted(puzzle, record) || frontierPuzzle?.id == puzzle.id;
}

class PuzzleCompletionOutcome {
  const PuzzleCompletionOutcome({
    required this.puzzle,
    required this.advancedJourney,
    required this.nextPuzzle,
    required this.enteredChapter,
    required this.isJourneyComplete,
    this.isChallenge = false,
  });

  final PuzzleDefinition puzzle;
  final bool advancedJourney;
  final PuzzleDefinition? nextPuzzle;
  final JourneyChapter? enteredChapter;
  final bool isJourneyComplete;
  final bool isChallenge;
}

abstract final class StoryBeatIds {
  static const opening = ContentIds.originOpeningScene;
  static const finale = ContentIds.originFinaleScene;
}
