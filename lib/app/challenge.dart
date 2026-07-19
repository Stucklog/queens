import '../core/models.dart';
import '../core/generator.dart';
import '../content/content_ids.dart';
import 'journey.dart';

enum ChallengeMode { easy, medium, hard, expert, extreme, mixed }

extension ChallengeModeDetails on ChallengeMode {
  String get label => switch (this) {
    ChallengeMode.easy => 'Easy',
    ChallengeMode.medium => 'Medium',
    ChallengeMode.hard => 'Hard',
    ChallengeMode.expert => 'Expert',
    ChallengeMode.extreme => 'Extreme',
    ChallengeMode.mixed => 'Mixed',
  };

  String get description => switch (this) {
    ChallengeMode.easy => 'A gentle run of 6 × 6 and 7 × 7 boards.',
    ChallengeMode.medium => 'A steady run of 7 × 7 and 8 × 8 boards.',
    ChallengeMode.hard => 'A demanding run of 8 × 8 and 9 × 9 boards.',
    ChallengeMode.expert => 'The deepest 9 × 9 and 10 × 10 deductions.',
    ChallengeMode.extreme => 'Towering 12 × 12 boards for the ultimate test.',
    ChallengeMode.mixed => 'Easy through Expert in a changing sequence.',
  };

  DifficultyTier tierFor(int seed, int number) => switch (this) {
    ChallengeMode.easy => DifficultyTier.easy,
    ChallengeMode.medium => DifficultyTier.medium,
    ChallengeMode.hard => DifficultyTier.hard,
    ChallengeMode.expert => DifficultyTier.expert,
    ChallengeMode.extreme => DifficultyTier.expert,
    ChallengeMode.mixed =>
      DifficultyTier.values[((seed & 0x7fffffff) + number - 1) % 4],
  };

  String difficultyLabelFor(DifficultyTier tier) =>
      this == ChallengeMode.extreme ? label : tier.label;
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

  String get puzzleId => ContentIds.justPuzzle(sessionSeed, number);

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
  final size =
      mode == ChallengeMode.extreme
          ? 12
          : switch (tier) {
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

JourneyChapter challengeChapterFor(
  DifficultyTier tier,
  int number, {
  List<JourneyChapter> chapters = journeyChapters,
}) {
  final pair = switch (tier) {
    DifficultyTier.easy => chapters.sublist(0, 2),
    DifficultyTier.medium => chapters.sublist(2, 4),
    DifficultyTier.hard => chapters.sublist(4, 6),
    DifficultyTier.expert => chapters.sublist(6, 8),
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
    this.preparedPuzzles = const [],
    this.recentSignatures = const [],
  });

  static const schemaVersion = 2;
  static const preparedCapacity = 2;
  static const recentSignatureCapacityPerSize = 16;
  static const recentSignatureCapacity = 80;

  final int seed;
  final ChallengeMode mode;
  final int currentNumber;
  final PuzzleDefinition currentPuzzle;
  final BoardState board;
  final int completedCount;
  final int cleanCount;
  final int assistedCount;
  final bool currentCompleted;
  final List<PuzzleDefinition> preparedPuzzles;
  final List<PuzzleDiversitySignature> recentSignatures;

  PuzzleDefinition? get queuedPuzzle =>
      preparedPuzzles.isEmpty ? null : preparedPuzzles.first;

  static List<PuzzleDiversitySignature> rememberSignature(
    Iterable<PuzzleDiversitySignature> existing,
    PuzzleDiversitySignature signature,
  ) {
    final history = [
      for (final item in existing)
        if (item.canonicalFingerprint != signature.canonicalFingerprint) item,
      signature,
    ];
    while (history.where((item) => item.size == signature.size).length >
        recentSignatureCapacityPerSize) {
      history.removeAt(
        history.indexWhere((item) => item.size == signature.size),
      );
    }
    if (history.length > recentSignatureCapacity) {
      history.removeRange(0, history.length - recentSignatureCapacity);
    }
    return List.unmodifiable(history);
  }

  static List<PuzzleDiversitySignature> normalizeSignatures(
    Iterable<PuzzleDiversitySignature> signatures,
  ) {
    var normalized = const <PuzzleDiversitySignature>[];
    for (final signature in signatures) {
      normalized = rememberSignature(normalized, signature);
    }
    return normalized;
  }

  ChallengeSession withPrepared(
    PuzzleDefinition puzzle,
    PuzzleDiversitySignature signature,
  ) {
    if (preparedPuzzles.length >= preparedCapacity) return this;
    return ChallengeSession(
      seed: seed,
      mode: mode,
      currentNumber: currentNumber,
      currentPuzzle: currentPuzzle,
      board: board,
      completedCount: completedCount,
      cleanCount: cleanCount,
      assistedCount: assistedCount,
      currentCompleted: currentCompleted,
      preparedPuzzles: [...preparedPuzzles, puzzle],
      recentSignatures: rememberSignature(recentSignatures, signature),
    );
  }

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
      preparedPuzzles: preparedPuzzles,
      recentSignatures: recentSignatures,
    );
  }

  ChallengeSession advanceToPrepared() {
    if (preparedPuzzles.isEmpty) {
      throw StateError('No prepared challenge puzzle');
    }
    final puzzle = preparedPuzzles.first;
    return ChallengeSession(
      seed: seed,
      mode: mode,
      currentNumber: currentNumber + 1,
      currentPuzzle: puzzle,
      board: BoardState(puzzleId: puzzle.id, size: puzzle.size),
      completedCount: completedCount,
      cleanCount: cleanCount,
      assistedCount: assistedCount,
      preparedPuzzles: preparedPuzzles.skip(1).toList(),
      recentSignatures: recentSignatures,
    );
  }

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
    'preparedPuzzles': [for (final puzzle in preparedPuzzles) puzzle.toJson()],
    'recentSignatures': [
      for (final signature in recentSignatures) signature.toJson(),
    ],
  };

  factory ChallengeSession.fromJson(Map<String, Object?> json) {
    final storedSchema = (json['schemaVersion'] as num?)?.toInt();
    if (storedSchema != 1 && storedSchema != schemaVersion) {
      throw const FormatException('Unsupported challenge session schema');
    }
    final seed = (json['seed']! as num).toInt();
    final mode = ChallengeMode.values.firstWhere(
      (value) => value.name == json['mode'],
    );
    final currentNumber = (json['currentNumber']! as num).toInt();
    final puzzle = PuzzleDefinition.fromJson(
      json['currentPuzzle']! as Map<String, Object?>,
    );
    final board = BoardState.fromJson(json['board']! as Map<String, Object?>);
    final currentSpec = challengeSpec(
      mode: mode,
      sessionSeed: seed,
      number: currentNumber,
    );
    if (currentNumber < 1 ||
        puzzle.id != currentSpec.puzzleId ||
        puzzle.order != currentNumber ||
        puzzle.tier != currentSpec.tier ||
        puzzle.size != currentSpec.size ||
        board.puzzleId != puzzle.id ||
        board.size != puzzle.size ||
        PuzzleDefinition.stableHash(puzzle.size, puzzle.regions) !=
            puzzle.contentHash) {
      throw const FormatException('Invalid saved challenge puzzle');
    }

    final storedPrepared = json['preparedPuzzles'];
    final rawPrepared =
        storedSchema == 1
            ? [if (json['queuedPuzzle'] != null) json['queuedPuzzle']]
            : storedPrepared is List<Object?>
            ? storedPrepared
            : const <Object?>[];
    final prepared = <PuzzleDefinition>[];
    for (final raw in rawPrepared.take(preparedCapacity)) {
      try {
        final candidate = PuzzleDefinition.fromJson(
          raw! as Map<String, Object?>,
        );
        final expectedNumber = currentNumber + prepared.length + 1;
        final expected = challengeSpec(
          mode: mode,
          sessionSeed: seed,
          number: expectedNumber,
        );
        if (candidate.id != expected.puzzleId ||
            candidate.order != expectedNumber ||
            candidate.tier != expected.tier ||
            candidate.size != expected.size ||
            PuzzleDefinition.stableHash(candidate.size, candidate.regions) !=
                candidate.contentHash) {
          break;
        }
        prepared.add(candidate);
      } on Object {
        break;
      }
    }

    final recentSignatures = <PuzzleDiversitySignature>[];
    if (storedSchema == schemaVersion) {
      final storedSignatures = json['recentSignatures'];
      final rawSignatures =
          storedSignatures is List<Object?>
              ? storedSignatures
              : const <Object?>[];
      for (final raw in rawSignatures) {
        try {
          recentSignatures.add(
            PuzzleDiversitySignature.fromJson(raw! as Map<String, Object?>),
          );
        } on Object {
          // A damaged diversity entry should not discard a valid run.
        }
      }
    }
    return ChallengeSession(
      seed: seed,
      mode: mode,
      currentNumber: currentNumber,
      currentPuzzle: puzzle,
      board: board,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      cleanCount: (json['cleanCount'] as num?)?.toInt() ?? 0,
      assistedCount: (json['assistedCount'] as num?)?.toInt() ?? 0,
      currentCompleted: json['currentCompleted'] as bool? ?? false,
      preparedPuzzles: prepared,
      recentSignatures: normalizeSignatures(recentSignatures),
    );
  }
}
