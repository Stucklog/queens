import 'package:flutter/material.dart';

import '../core/models.dart';

class JourneyPalette {
  const JourneyPalette({
    required this.lightBackground,
    required this.lightSurface,
    required this.darkBackground,
    required this.darkSurface,
    required this.primary,
    required this.secondary,
  });

  final Color lightBackground;
  final Color lightSurface;
  final Color darkBackground;
  final Color darkSurface;
  final Color primary;
  final Color secondary;

  Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;
}

class JourneyChapter {
  const JourneyChapter({
    required this.id,
    required this.title,
    required this.caption,
    required this.startOrder,
    required this.endOrder,
    required this.difficulty,
    required this.size,
    required this.palette,
  });

  final String id;
  final String title;
  final String caption;
  final int startOrder;
  final int endOrder;
  final DifficultyTier difficulty;
  final int size;
  final JourneyPalette palette;

  String get storyBeatId => 'chapter.$id';

  bool contains(int order) => order >= startOrder && order <= endOrder;
}

const journeyChapters = <JourneyChapter>[
  JourneyChapter(
    id: 'clovermead',
    title: 'Asterfall Vale',
    caption:
        'Where heaven struck the earth, the fallen Regalia chooses its bearer.',
    startOrder: 1,
    endOrder: 20,
    difficulty: DifficultyTier.easy,
    size: 6,
    palette: JourneyPalette(
      lightBackground: Color(0xfffff3bc),
      lightSurface: Color(0xfffffbea),
      darkBackground: Color(0xff25332f),
      darkSurface: Color(0xff34433d),
      primary: Color(0xff527663),
      secondary: Color(0xff5d9ab5),
    ),
  ),
  JourneyChapter(
    id: 'whisperwood',
    title: 'Myrrhveil Wilds',
    caption: 'Ancient roots part for the crown—and wake what sleeps below.',
    startOrder: 21,
    endOrder: 30,
    difficulty: DifficultyTier.easy,
    size: 7,
    palette: JourneyPalette(
      lightBackground: Color(0xffdce4ca),
      lightSurface: Color(0xfff2f1dc),
      darkBackground: Color(0xff172c2a),
      darkSurface: Color(0xff263c38),
      primary: Color(0xff365f50),
      secondary: Color(0xff704d78),
    ),
  ),
  JourneyChapter(
    id: 'windmill-heights',
    title: 'Skyglass Reach',
    caption:
        'Ancient wind arches awaken, carrying the bearer beyond the storm.',
    startOrder: 31,
    endOrder: 40,
    difficulty: DifficultyTier.medium,
    size: 7,
    palette: JourneyPalette(
      lightBackground: Color(0xffdce3e8),
      lightSurface: Color(0xfffff8e8),
      darkBackground: Color(0xff27313d),
      darkSurface: Color(0xff354251),
      primary: Color(0xff536d88),
      secondary: Color(0xffa75b3b),
    ),
  ),
  JourneyChapter(
    id: 'sunken-cloister',
    title: 'Nacre Basilica',
    caption:
        'Beneath the drowned bells, a forgotten covenant opens the deep road.',
    startOrder: 41,
    endOrder: 60,
    difficulty: DifficultyTier.medium,
    size: 8,
    palette: JourneyPalette(
      lightBackground: Color(0xffc9ebe4),
      lightSurface: Color(0xffedf4e9),
      darkBackground: Color(0xff183637),
      darkSurface: Color(0xff294748),
      primary: Color(0xff247f82),
      secondary: Color(0xff879e91),
    ),
  ),
  JourneyChapter(
    id: 'emberbell-caverns',
    title: 'Pyreheart Caldera',
    caption: 'At the world’s molten heart, living crystal answers the crown.',
    startOrder: 61,
    endOrder: 80,
    difficulty: DifficultyTier.hard,
    size: 8,
    palette: JourneyPalette(
      lightBackground: Color(0xfff2d1b0),
      lightSurface: Color(0xffffead6),
      darkBackground: Color(0xff2c2022),
      darkSurface: Color(0xff443033),
      primary: Color(0xff8d3e31),
      secondary: Color(0xffdb7a37),
    ),
  ),
  JourneyChapter(
    id: 'goblin-underkeep',
    title: 'Brasswake Arsenal',
    caption: 'The old empire’s last war-engine wakes to bar the ascent.',
    startOrder: 81,
    endOrder: 90,
    difficulty: DifficultyTier.hard,
    size: 9,
    palette: JourneyPalette(
      lightBackground: Color(0xffddd9a8),
      lightSurface: Color(0xfff2ead1),
      darkBackground: Color(0xff29251c),
      darkSurface: Color(0xff403a2b),
      primary: Color(0xff5b4c2a),
      secondary: Color(0xff91a934),
    ),
  ),
  JourneyChapter(
    id: 'moonlit-catacombs',
    title: 'Pale Moon Necropolis',
    caption:
        'Seven fallen queens rise beneath the pale moon to judge the bearer.',
    startOrder: 91,
    endOrder: 100,
    difficulty: DifficultyTier.expert,
    size: 9,
    palette: JourneyPalette(
      lightBackground: Color(0xffddd8ec),
      lightSurface: Color(0xfff2eff8),
      darkBackground: Color(0xff17182c),
      darkSurface: Color(0xff272844),
      primary: Color(0xff514d82),
      secondary: Color(0xff9ca9c7),
    ),
  ),
  JourneyChapter(
    id: 'crownspire',
    title: 'Empyrean Citadel',
    caption: 'Above the clouds, the vacant throne waits beneath a dying sun.',
    startOrder: 101,
    endOrder: 120,
    difficulty: DifficultyTier.expert,
    size: 10,
    palette: JourneyPalette(
      lightBackground: Color(0xffe4e7f5),
      lightSurface: Color(0xfffffbeb),
      darkBackground: Color(0xff151d38),
      darkSurface: Color(0xff253052),
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
  static const opening = 'opening';
  static const finale = 'finale';
}
