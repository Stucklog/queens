import 'package:flutter/material.dart';

import '../content/content_ids.dart';
import '../core/models.dart';
import 'arc_theme.dart';
import 'combat_style.dart';

const regaliaMidnight = Color(0xff151d3b);
const regaliaMidnightSurface = Color(0xff253052);

class JourneyPalette {
  const JourneyPalette({
    required this.primary,
    required this.secondary,
    this.theme = ArcThemeColors.midnight,
  });

  final Color primary;
  final Color secondary;
  final ArcThemeColors theme;

  Color get background => theme.background;
  Color get surface => theme.surface;
}

enum JourneyRoutePattern {
  /// Alternates direction on each row so the route remains serpentine.
  snake,

  /// Starts every row from the configured side.
  rows;

  static JourneyRoutePattern parse(Object? value) {
    if (value == null) return JourneyRoutePattern.snake;
    return values.firstWhere(
      (pattern) => pattern.name == value,
      orElse:
          () => throw FormatException('Unknown journey route pattern $value'),
    );
  }
}

enum JourneyRouteDirection {
  leftToRight,
  rightToLeft;

  static JourneyRouteDirection parse(Object? value) {
    if (value == null) return JourneyRouteDirection.leftToRight;
    return values.firstWhere(
      (direction) => direction.name == value,
      orElse:
          () => throw FormatException('Unknown journey route direction $value'),
    );
  }
}

/// Controls how one chapter's puzzle nodes are arranged on the journey map.
///
/// Omitted content retains the original three-column, left-to-right snake.
class JourneyMapLayout {
  const JourneyMapLayout({
    this.columns = 3,
    this.pattern = JourneyRoutePattern.snake,
    this.direction = JourneyRouteDirection.leftToRight,
  }) : assert(columns > 0);

  static const standard = JourneyMapLayout();

  final int columns;
  final JourneyRoutePattern pattern;
  final JourneyRouteDirection direction;

  int displayColumnFor({
    required int row,
    required int logicalColumn,
    required int columnCount,
  }) {
    final startsOnLeft = direction == JourneyRouteDirection.leftToRight;
    final runsLeftToRight = switch (pattern) {
      JourneyRoutePattern.snake => row.isEven ? startsOnLeft : !startsOnLeft,
      JourneyRoutePattern.rows => startsOnLeft,
    };
    return runsLeftToRight ? logicalColumn : columnCount - 1 - logicalColumn;
  }

  factory JourneyMapLayout.fromJson(Object? value) {
    if (value == null) return standard;
    if (value is! Map<String, Object?>) {
      throw const FormatException('mapLayout must be an object');
    }
    final columns = (value['columns'] as num?)?.toInt() ?? standard.columns;
    if (columns < 1) {
      throw FormatException('mapLayout columns must be positive, got $columns');
    }
    return JourneyMapLayout(
      columns: columns,
      pattern: JourneyRoutePattern.parse(value['pattern']),
      direction: JourneyRouteDirection.parse(value['direction']),
    );
  }
}

enum EnemySpriteFamily {
  antlered,
  rootbound,
  winged,
  abyssal,
  volcanic,
  clockwork,
  spectral,
  cosmic;

  static EnemySpriteFamily parse(String value) => values.firstWhere(
    (family) => family.name == value,
    orElse: () => throw FormatException('Unknown enemy sprite family $value'),
  );
}

class CombatEncounter {
  const CombatEncounter({
    required this.id,
    required this.name,
    required this.puzzleId,
    required this.spriteFamily,
    required this.spriteAsset,
    required this.spectacleLevel,
    required this.isBoss,
    CombatFinisherStyle? finisherStyle,
  }) : _finisherStyle = finisherStyle;

  final String id;
  final String name;
  final String puzzleId;
  final EnemySpriteFamily spriteFamily;

  /// A 4-column by 6-row transparent pixel-art reaction atlas.
  final String spriteAsset;

  /// One for regular encounters and 1–8 for increasingly climactic bosses.
  final int spectacleLevel;
  final bool isBoss;
  final CombatFinisherStyle? _finisherStyle;

  CombatFinisherStyle get finisherStyle =>
      _finisherStyle ?? CombatFinisherStyle.legacy(spectacleLevel);
}

class ChapterEnemy extends CombatEncounter {
  const ChapterEnemy({
    required super.id,
    required super.name,
    required super.puzzleId,
    required super.spriteFamily,
    required super.spriteAsset,
    super.finisherStyle,
  }) : super(spectacleLevel: 1, isBoss: false);

  factory ChapterEnemy.fromJson(Map<String, Object?> json) {
    final id = json['id']! as String;
    final puzzleId = json['puzzleId']! as String;
    ContentId.parse(id, expectedKind: 'enemy');
    ContentId.parse(puzzleId, expectedKind: 'puzzle');
    return ChapterEnemy(
      id: id,
      name: json['name']! as String,
      puzzleId: puzzleId,
      spriteFamily: EnemySpriteFamily.parse(json['spriteFamily']! as String),
      spriteAsset: json['spriteAsset']! as String,
      finisherStyle: CombatFinisherStyle.fromJson(
        json['finisher'],
        legacySpectacleLevel: 1,
      ),
    );
  }
}

class ChapterBoss extends CombatEncounter {
  const ChapterBoss({
    required super.id,
    required super.name,
    required super.puzzleId,
    required super.spriteFamily,
    required super.spriteAsset,
    required super.spectacleLevel,
    super.finisherStyle,
    required this.size,
    required this.targetDifficulty,
    required this.unlockTargetId,
  }) : super(isBoss: true);

  final int size;
  final DifficultyTier targetDifficulty;

  /// The next chapter ID, or the arc finale unlock ID for the final boss.
  final String unlockTargetId;

  factory ChapterBoss.fromJson(Map<String, Object?> json) {
    final id = json['id']! as String;
    final puzzleId = json['puzzleId']! as String;
    final unlockTargetId = json['unlocks']! as String;
    ContentId.parse(id, expectedKind: 'boss');
    ContentId.parse(puzzleId, expectedKind: 'puzzle');
    ContentId.parse(unlockTargetId);
    final spectacleLevel = (json['spectacleLevel']! as num).toInt();
    return ChapterBoss(
      id: id,
      name: json['name']! as String,
      puzzleId: puzzleId,
      spriteFamily: EnemySpriteFamily.parse(json['spriteFamily']! as String),
      spriteAsset: json['spriteAsset']! as String,
      spectacleLevel: spectacleLevel,
      finisherStyle: CombatFinisherStyle.fromJson(
        json['finisher'],
        legacySpectacleLevel: spectacleLevel,
      ),
      size: (json['size']! as num).toInt(),
      targetDifficulty: DifficultyTierLabel.parse(
        json['targetDifficulty']! as String,
      ),
      unlockTargetId: unlockTargetId,
    );
  }
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
    required this.boss,
    this.encounters = const [],
    required this.palette,
    this.mapLayout = JourneyMapLayout.standard,
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
  final ChapterBoss boss;
  final List<ChapterEnemy> encounters;
  final JourneyPalette palette;
  final JourneyMapLayout mapLayout;

  String get storyBeatId => sceneId;

  bool contains(int order) => order >= startOrder && order <= endOrder;

  factory JourneyChapter.fromJson(
    Map<String, Object?> json, {
    ArcThemeColors arcTheme = ArcThemeColors.midnight,
  }) {
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
      boss: ChapterBoss.fromJson(json['boss']! as Map<String, Object?>),
      encounters: List.unmodifiable(
        (json['encounters'] as List<Object?>? ?? const []).map(
          (encounter) =>
              ChapterEnemy.fromJson(encounter! as Map<String, Object?>),
        ),
      ),
      palette: JourneyPalette(
        primary: color('primaryColor'),
        secondary: color('secondaryColor'),
        theme: ArcThemeColors.mergeFromJson(json['theme'], base: arcTheme),
      ),
      mapLayout: JourneyMapLayout.fromJson(json['mapLayout']),
    );
  }
}

/// Story-independent visual themes for generated puzzles and resilient UI
/// fallbacks. Canonical story chapters are loaded only from content packages.
final List<JourneyChapter> challengeVisualChapters = List.unmodifiable([
  _challengeVisualChapter(
    tier: DifficultyTier.easy,
    title: 'Verdant Crucible',
    primary: const Color(0xff527663),
    secondary: const Color(0xff5d9ab5),
    visualIndex: 0,
  ),
  _challengeVisualChapter(
    tier: DifficultyTier.medium,
    title: 'Tempest Crucible',
    primary: const Color(0xff536d88),
    secondary: const Color(0xffa75b3b),
    visualIndex: 2,
  ),
  _challengeVisualChapter(
    tier: DifficultyTier.hard,
    title: 'Ember Crucible',
    primary: const Color(0xff8d3e31),
    secondary: const Color(0xffdb7a37),
    visualIndex: 4,
  ),
  _challengeVisualChapter(
    tier: DifficultyTier.expert,
    title: 'Astral Crucible',
    primary: const Color(0xff514d82),
    secondary: const Color(0xffbd8b2d),
    visualIndex: 6,
  ),
]);

JourneyChapter _challengeVisualChapter({
  required DifficultyTier tier,
  required String title,
  required Color primary,
  required Color secondary,
  required int visualIndex,
}) {
  final slug = tier.name;
  final order = tier.index + 1;
  return JourneyChapter(
    id: 'regalia:chapter/just-puzzle/$slug',
    mapId: 'regalia:map/just-puzzle/endless-crucible',
    sceneId: 'regalia:scene/just-puzzle/$slug',
    artKey: 'challenge-$slug',
    artAsset: 'assets/art/backgrounds/story_opening.webp',
    visualIndex: visualIndex,
    title: title,
    caption: 'A story-independent visual theme for generated puzzles.',
    startOrder: order,
    endOrder: order,
    difficulty: tier,
    size: switch (tier) {
      DifficultyTier.easy => 6,
      DifficultyTier.medium => 7,
      DifficultyTier.hard => 8,
      DifficultyTier.expert => 10,
    },
    boss: ChapterBoss(
      id: 'regalia:boss/just-puzzle/$slug',
      name: 'Crucible Sentinel',
      puzzleId: 'regalia:puzzle/just-puzzle/visual-$slug',
      spriteFamily: EnemySpriteFamily.cosmic,
      spriteAsset: 'assets/art/combat/opponents/starbound-sentinel.png',
      spectacleLevel: order,
      size: 6,
      targetDifficulty: tier,
      unlockTargetId: 'regalia:unlock/just-puzzle/continue',
    ),
    palette: JourneyPalette(primary: primary, secondary: secondary),
  );
}

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
