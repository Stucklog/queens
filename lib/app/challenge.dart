import '../core/models.dart';
import 'journey.dart';

enum ChallengeMode { easy, medium, hard, expert, mixed }

extension ChallengeModeDetails on ChallengeMode {
  String get label => switch (this) {
    ChallengeMode.easy => 'Easy',
    ChallengeMode.medium => 'Medium',
    ChallengeMode.hard => 'Hard',
    ChallengeMode.expert => 'Expert',
    ChallengeMode.mixed => 'Mixed',
  };

  String get description => switch (this) {
    ChallengeMode.easy => 'A gentle run of 6 × 6 and 7 × 7 boards.',
    ChallengeMode.medium => 'A steady run of 7 × 7 and 8 × 8 boards.',
    ChallengeMode.hard => 'A demanding run of 8 × 8 and 9 × 9 boards.',
    ChallengeMode.expert => 'The deepest 9 × 9 and 10 × 10 deductions.',
    ChallengeMode.mixed => 'All four difficulties in a changing sequence.',
  };

  DifficultyTier tierFor(int seed, int number) => switch (this) {
    ChallengeMode.easy => DifficultyTier.easy,
    ChallengeMode.medium => DifficultyTier.medium,
    ChallengeMode.hard => DifficultyTier.hard,
    ChallengeMode.expert => DifficultyTier.expert,
    ChallengeMode.mixed =>
      DifficultyTier.values[((seed & 0x7fffffff) + number - 1) % 4],
  };
}

class ChallengeGenerationSpec {
  const ChallengeGenerationSpec({
    required this.sessionSeed,
    required this.number,
    required this.tier,
    required this.size,
  });

  final int sessionSeed;
  final int number;
  final DifficultyTier tier;
  final int size;

  int get generationSeed =>
      (sessionSeed + number * 104729 + tier.index * 15485863) & 0x7fffffff;

  String get puzzleId =>
      'challenge-${sessionSeed.toRadixString(16)}-${number.toString().padLeft(5, '0')}';

  Map<String, Object> toJson() => {
    'sessionSeed': sessionSeed,
    'number': number,
    'tier': tier.name,
    'size': size,
  };

  factory ChallengeGenerationSpec.fromJson(Map<String, Object?> json) =>
      ChallengeGenerationSpec(
        sessionSeed: (json['sessionSeed']! as num).toInt(),
        number: (json['number']! as num).toInt(),
        tier: DifficultyTierLabel.parse(json['tier']! as String),
        size: (json['size']! as num).toInt(),
      );
}

ChallengeGenerationSpec challengeSpec({
  required ChallengeMode mode,
  required int sessionSeed,
  required int number,
}) {
  final tier = mode.tierFor(sessionSeed, number);
  final larger = ((sessionSeed >> (number % 16)) + number).isOdd;
  final size = switch (tier) {
    DifficultyTier.easy => larger ? 7 : 6,
    DifficultyTier.medium => larger ? 8 : 7,
    DifficultyTier.hard => larger ? 9 : 8,
    DifficultyTier.expert => larger ? 10 : 9,
  };
  return ChallengeGenerationSpec(
    sessionSeed: sessionSeed,
    number: number,
    tier: tier,
    size: size,
  );
}

JourneyChapter challengeChapterFor(DifficultyTier tier, int number) {
  final pair = switch (tier) {
    DifficultyTier.easy => journeyChapters.sublist(0, 2),
    DifficultyTier.medium => journeyChapters.sublist(2, 4),
    DifficultyTier.hard => journeyChapters.sublist(4, 6),
    DifficultyTier.expert => journeyChapters.sublist(6, 8),
  };
  return pair[(number - 1) % pair.length];
}

class ChallengeSession {
  const ChallengeSession({
    required this.seed,
    required this.mode,
    required this.currentNumber,
    required this.currentPuzzle,
    required this.board,
    required this.completedCount,
    required this.cleanCount,
    required this.assistedCount,
    this.currentCompleted = false,
    this.queuedPuzzle,
  });

  static const schemaVersion = 1;

  final int seed;
  final ChallengeMode mode;
  final int currentNumber;
  final PuzzleDefinition currentPuzzle;
  final BoardState board;
  final int completedCount;
  final int cleanCount;
  final int assistedCount;
  final bool currentCompleted;
  final PuzzleDefinition? queuedPuzzle;

  ChallengeSession withQueued(PuzzleDefinition puzzle) => ChallengeSession(
    seed: seed,
    mode: mode,
    currentNumber: currentNumber,
    currentPuzzle: currentPuzzle,
    board: board,
    completedCount: completedCount,
    cleanCount: cleanCount,
    assistedCount: assistedCount,
    currentCompleted: currentCompleted,
    queuedPuzzle: puzzle,
  );

  ChallengeSession complete({required bool assisted}) {
    if (currentCompleted) return this;
    return ChallengeSession(
      seed: seed,
      mode: mode,
      currentNumber: currentNumber,
      currentPuzzle: currentPuzzle,
      board: board,
      completedCount: completedCount + 1,
      cleanCount: cleanCount + (assisted ? 0 : 1),
      assistedCount: assistedCount + (assisted ? 1 : 0),
      currentCompleted: true,
      queuedPuzzle: queuedPuzzle,
    );
  }

  ChallengeSession advanceTo(PuzzleDefinition puzzle) => ChallengeSession(
    seed: seed,
    mode: mode,
    currentNumber: currentNumber + 1,
    currentPuzzle: puzzle,
    board: BoardState(puzzleId: puzzle.id, size: puzzle.size),
    completedCount: completedCount,
    cleanCount: cleanCount,
    assistedCount: assistedCount,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'seed': seed,
    'mode': mode.name,
    'currentNumber': currentNumber,
    'currentPuzzle': currentPuzzle.toJson(),
    'board': board.toJson(),
    'completedCount': completedCount,
    'cleanCount': cleanCount,
    'assistedCount': assistedCount,
    'currentCompleted': currentCompleted,
    'queuedPuzzle': queuedPuzzle?.toJson(),
  };

  factory ChallengeSession.fromJson(Map<String, Object?> json) {
    if ((json['schemaVersion'] as num?)?.toInt() != schemaVersion) {
      throw const FormatException('Unsupported challenge session schema');
    }
    final puzzle = PuzzleDefinition.fromJson(
      json['currentPuzzle']! as Map<String, Object?>,
    );
    final board = BoardState.fromJson(json['board']! as Map<String, Object?>);
    if (!puzzle.id.startsWith('challenge-') ||
        board.puzzleId != puzzle.id ||
        board.size != puzzle.size ||
        PuzzleDefinition.stableHash(puzzle.size, puzzle.regions) !=
            puzzle.contentHash) {
      throw const FormatException('Invalid saved challenge puzzle');
    }
    final queuedJson = json['queuedPuzzle'];
    final queued =
        queuedJson is Map<String, Object?>
            ? PuzzleDefinition.fromJson(queuedJson)
            : null;
    if (queued != null &&
        (!queued.id.startsWith('challenge-') ||
            PuzzleDefinition.stableHash(queued.size, queued.regions) !=
                queued.contentHash)) {
      throw const FormatException('Invalid queued challenge puzzle');
    }
    return ChallengeSession(
      seed: (json['seed']! as num).toInt(),
      mode: ChallengeMode.values.firstWhere(
        (value) => value.name == json['mode'],
      ),
      currentNumber: (json['currentNumber']! as num).toInt(),
      currentPuzzle: puzzle,
      board: board,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      cleanCount: (json['cleanCount'] as num?)?.toInt() ?? 0,
      assistedCount: (json['assistedCount'] as num?)?.toInt() ?? 0,
      currentCompleted: json['currentCompleted'] as bool? ?? false,
      queuedPuzzle: queued,
    );
  }
}
