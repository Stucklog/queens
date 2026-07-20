import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/challenge_generator.dart';
import '../core/generator.dart';
import '../core/human_solver.dart';
import '../core/models.dart';
import '../core/rule_engine.dart';
import '../content/content_ids.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../content/entitlements.dart';
import 'academy.dart';
import 'challenge.dart';
import 'journey.dart';

class AppSettings {
  const AppSettings({
    this.showTimer = true,
    this.showAutomaticExclusions = true,
    this.reducedMotion = false,
  });

  final bool showTimer;
  final bool showAutomaticExclusions;
  final bool reducedMotion;

  AppSettings copyWith({
    bool? showTimer,
    bool? showAutomaticExclusions,
    bool? reducedMotion,
  }) => AppSettings(
    showTimer: showTimer ?? this.showTimer,
    showAutomaticExclusions:
        showAutomaticExclusions ?? this.showAutomaticExclusions,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  Map<String, Object> toJson() => {
    'showTimer': showTimer,
    'showAutomaticExclusions': showAutomaticExclusions,
    'reducedMotion': reducedMotion,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    showTimer: json['showTimer'] as bool? ?? true,
    showAutomaticExclusions: json['showAutomaticExclusions'] as bool? ?? true,
    reducedMotion: json['reducedMotion'] as bool? ?? false,
  );
}

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    this.ruleEngine = const RuleEngine(),
    this.humanSolver = const HumanSolver(),
    this.challengePuzzleFactory = generateChallengePuzzle,
    ContentAssetReader? contentAssetReader,
    ContentEntitlementPolicy? contentPolicy,
    this.contentManifestAsset = 'assets/content/manifest.json',
  }) : _contentAssetReader = contentAssetReader ?? rootBundle.loadString,
       contentPolicy = contentPolicy ?? ContentEntitlementPolicy.current();

  final RuleEngine ruleEngine;
  final HumanSolver humanSolver;
  final ChallengePuzzleFactory challengePuzzleFactory;
  final ContentAssetReader _contentAssetReader;
  final ContentEntitlementPolicy contentPolicy;
  final String contentManifestAsset;
  static const journeySchemaVersion = 1;
  static const saveMigrationVersion = 1;
  late final SharedPreferences _preferences;
  String? _catalogFingerprint;
  final Map<String, String> _arcCatalogFingerprints = {};
  ContentRegistry? content;
  PuzzleCatalog? catalog;
  AcademyCatalog? academy;
  PuzzleDefinition? tutorialPuzzle;
  AppSettings settings = const AppSettings();
  final Map<String, BoardState> boards = {};
  final Map<String, CompletionRecord> records = {};
  final Set<String> seenStoryBeatIds = {};
  final Set<String> supportPromptedChapterIds = {};
  final Set<String> unlockedContentIds = {};
  final Set<String> completedAcademyLessonIds = {};
  ChallengeSession? challengeSession;
  bool isStartingChallenge = false;
  bool isPreparingChallenge = false;
  Object? challengeGenerationError;
  bool tutorialComplete = false;
  String? lastPuzzleId;
  Timer? _timer;
  String? _activePuzzleId;
  Future<void> _saveChain = Future.value();
  Future<void>? _challengePrefetch;
  final Map<String, int> _challengeRetrySalts = {};
  List<PuzzleDiversitySignature> _challengeDiversityHistory = const [];
  bool _challengePreparationAllowed = true;
  int _challengeStartEpoch = 0;
  int gameGeneration = 0;
  bool _disposed = false;

  bool get isReady => content != null;

  StoryArc? get originArc => content?.arc(ContentIds.originArc);
  Iterable<StoryArc> get availableStoryArcs =>
      content?.availableArcs ?? const <StoryArc>[];
  bool get hasOriginStory => originArc != null;
  bool get justPuzzleAvailable => content?.justPuzzleAvailable ?? false;
  bool get academyAvailable => academy?.lessons.isNotEmpty ?? false;
  List<AcademyLesson> get academyLessons =>
      academy?.lessons ?? const <AcademyLesson>[];
  int get academyCompletedCount => completedAcademyLessonIds.length;
  bool get fullMapUnlocked => isMapUnlocked(ContentIds.originArc);

  ArcAvailability availabilityForArc(String arcId) =>
      content?.availabilityFor(arcId) ??
      const ArcAvailability(status: ContentAvailabilityStatus.notPackaged);

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _challengePreparationAllowed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    content = await ContentRepository(
      readAsset: _contentAssetReader,
    ).load(manifestAsset: contentManifestAsset, policy: contentPolicy);
    catalog = originArc?.catalog;
    for (final arc in availableStoryArcs) {
      _arcCatalogFingerprints[arc.id] = _fingerprintFor(arc);
    }
    _catalogFingerprint = _arcCatalogFingerprints[ContentIds.originArc];
    try {
      final tutorialSource = await _contentAssetReader(
        'assets/puzzles/tutorial.json',
      );
      tutorialPuzzle = PuzzleDefinition.fromJson(
        jsonDecode(tutorialSource) as Map<String, Object?>,
      );
    } on Object catch (error) {
      // The tutorial is system content, not a prerequisite for either an arc
      // or Just Puzzle. A damaged optional asset must not brick the app.
      debugPrint('Tutorial content is unavailable: $error');
    }
    try {
      final sourceCatalog = catalog;
      if (sourceCatalog != null) {
        academy = AcademyCatalog.fromJsonString(
          await _contentAssetReader('assets/academy/lessons.json'),
          sourceCatalog: sourceCatalog,
        );
      }
    } on Object catch (error) {
      // Lessons are optional system content. Story and puzzle-only play stay
      // available if the Academy package cannot be decoded.
      debugPrint('Academy content is unavailable: $error');
    }
    _preferences = await SharedPreferences.getInstance();
    await _migrateLegacySave();
    settings =
        _decode(SaveIds.settings, AppSettings.fromJson) ?? const AppSettings();
    challengeSession = _decode(
      SaveIds.justPuzzleSession,
      ChallengeSession.fromJson,
    );
    _restoreChallengeGenerationState();
    tutorialComplete = _preferences.getBool(SaveIds.tutorialComplete) ?? false;
    final academyLessonIds = academyLessons.map((lesson) => lesson.id).toSet();
    completedAcademyLessonIds.addAll(
      (_preferences.getStringList(SaveIds.academyCompletedLessons) ?? const [])
          .where(academyLessonIds.contains),
    );
    final academyPuzzleSizes = {
      for (final lesson in academyLessons)
        lesson.practicePuzzle.id: lesson.practicePuzzle.size,
    };
    final academyBoardPayload = _preferences.getString(SaveIds.academyBoards);
    if (academyBoardPayload != null) {
      try {
        final entries = jsonDecode(academyBoardPayload) as Map<String, Object?>;
        for (final entry in entries.entries) {
          try {
            final board = BoardState.fromJson(
              entry.value! as Map<String, Object?>,
            );
            if (board.puzzleId == entry.key &&
                academyPuzzleSizes[entry.key] == board.size) {
              boards[entry.key] = board;
            }
          } on Object catch (error) {
            debugPrint('Ignoring invalid Academy board ${entry.key}: $error');
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid Academy boards: $error');
      }
    }
    unlockedContentIds.addAll(
      _preferences.getStringList(SaveIds.unlockedContentIds) ?? const [],
    );
    final packagedChapterIds = {
      for (final arc in availableStoryArcs)
        for (final chapter in arc.chapters) chapter.id,
    };
    supportPromptedChapterIds.addAll(
      (_preferences.getStringList(SaveIds.supportPromptedChapters) ?? const [])
          .where(packagedChapterIds.contains),
    );
    if (_preferences.getInt('regalia.journeySchemaVersion') !=
        journeySchemaVersion) {
      // Version one changes a freely selectable collection into a strict
      // journey. This compatibility guard remains for pre-v1 saves; the
      // namespacing migration itself deliberately preserves v1 progress.
      await _clearOriginProgress();
      await _preferences.setInt(
        'regalia.journeySchemaVersion',
        journeySchemaVersion,
      );
    }
    final legacyFingerprint = _preferences.getString(
      'regalia.catalogFingerprint',
    );
    if (_catalogFingerprint != null &&
        legacyFingerprint != null &&
        legacyFingerprint != _catalogFingerprint) {
      await _clearOriginProgress();
      await _preferences.remove('regalia.catalogFingerprint');
    }
    if (_catalogFingerprint != null &&
        _preferences.getString(SaveIds.originCatalogFingerprint) !=
            _catalogFingerprint) {
      // Changed boards receive new puzzle IDs. Keep entries whose stable IDs
      // still exist; restore below filters removed IDs and incompatible sizes.
      await _preferences.setString(
        SaveIds.originCatalogFingerprint,
        _catalogFingerprint!,
      );
    }
    final puzzleSizes = {
      for (final puzzle in catalog?.puzzles ?? const <PuzzleDefinition>[])
        puzzle.id: puzzle.size,
    };
    final storedLastPuzzleId = _preferences.getString(SaveIds.originLastPuzzle);
    lastPuzzleId =
        puzzleSizes.containsKey(storedLastPuzzleId) ? storedLastPuzzleId : null;
    final boardPayload = _preferences.getString(SaveIds.originBoards);
    if (boardPayload != null) {
      try {
        final entries = jsonDecode(boardPayload) as Map<String, Object?>;
        for (final entry in entries.entries) {
          try {
            final board = BoardState.fromJson(
              entry.value! as Map<String, Object?>,
            );
            if (board.puzzleId == entry.key &&
                puzzleSizes[entry.key] == board.size) {
              boards[entry.key] = board;
            }
          } on Object catch (error) {
            debugPrint('Ignoring invalid saved board ${entry.key}: $error');
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid saved boards: $error');
      }
    }
    final recordPayload = _preferences.getString(SaveIds.originRecords);
    if (recordPayload != null) {
      try {
        final entries = jsonDecode(recordPayload) as Map<String, Object?>;
        for (final entry in entries.entries) {
          try {
            if (puzzleSizes.containsKey(entry.key)) {
              records[entry.key] = CompletionRecord.fromJson(
                entry.value! as Map<String, Object?>,
              );
            }
          } on Object catch (error) {
            debugPrint(
              'Ignoring invalid completion record ${entry.key}: $error',
            );
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid completion records: $error');
      }
    }
    final seenPayload = _preferences.getStringList(SaveIds.originSeenScenes);
    if (seenPayload != null) seenStoryBeatIds.addAll(seenPayload);
    for (final arc in availableStoryArcs) {
      if (arc.id == ContentIds.originArc) continue;
      await _restoreArcProgress(arc);
    }
    final reconciledFinaleUnlocks = _reconcileFinaleUnlocksWithBossRecords();
    if (reconciledFinaleUnlocks) {
      await _preferences.setStringList(
        SaveIds.unlockedContentIds,
        unlockedContentIds.toList()..sort(),
      );
    }
    notifyListeners();
    if (challengeSession != null &&
        challengeSession!.preparedPuzzles.length < _challengePreparedTarget) {
      unawaited(ensureChallengeQueued());
    }
  }

  int get _challengePreparedTarget =>
      kIsWeb ? 1 : ChallengeSession.preparedCapacity;

  String _fingerprintFor(StoryArc arc) =>
      '${arc.id}:${arc.contentVersion}:${arc.catalog.schemaVersion}:${arc.catalog.puzzles.map((puzzle) => '${puzzle.id}:${puzzle.contentHash}').join(',')}';

  Future<void> _restoreArcProgress(StoryArc arc) async {
    final fingerprint = _arcCatalogFingerprints[arc.id]!;
    final fingerprintKey = SaveIds.forArc(arc.id, 'catalog-fingerprint');
    if (_preferences.getString(fingerprintKey) != fingerprint) {
      // Arc-owned puzzle IDs are immutable for a given grid. Restore below
      // keeps compatible IDs and ignores content that was replaced.
      await _preferences.setString(fingerprintKey, fingerprint);
    }
    final puzzleSizes = {
      for (final puzzle in arc.catalog.puzzles) puzzle.id: puzzle.size,
    };
    final boardPayload = _preferences.getString(
      SaveIds.forArc(arc.id, 'boards'),
    );
    if (boardPayload != null) {
      try {
        final entries = jsonDecode(boardPayload) as Map<String, Object?>;
        for (final entry in entries.entries) {
          try {
            final board = BoardState.fromJson(
              entry.value! as Map<String, Object?>,
            );
            if (board.puzzleId == entry.key &&
                puzzleSizes[entry.key] == board.size) {
              boards[entry.key] = board;
            }
          } on Object catch (error) {
            debugPrint('Ignoring invalid saved board ${entry.key}: $error');
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid saved boards for ${arc.id}: $error');
      }
    }
    final recordPayload = _preferences.getString(
      SaveIds.forArc(arc.id, 'records'),
    );
    if (recordPayload != null) {
      try {
        final entries = jsonDecode(recordPayload) as Map<String, Object?>;
        for (final entry in entries.entries) {
          try {
            if (puzzleSizes.containsKey(entry.key)) {
              records[entry.key] = CompletionRecord.fromJson(
                entry.value! as Map<String, Object?>,
              );
            }
          } on Object catch (error) {
            debugPrint(
              'Ignoring invalid completion record ${entry.key}: $error',
            );
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid completion records for ${arc.id}: $error');
      }
    }
    final seenPayload = _preferences.getStringList(
      SaveIds.forArc(arc.id, 'seen-scenes'),
    );
    if (seenPayload != null) {
      seenStoryBeatIds.addAll(
        seenPayload.where(
          (id) => ContentId.belongsToArc(id, arc.id, kind: 'scene'),
        ),
      );
    }
    final storedLastPuzzleId = _preferences.getString(
      SaveIds.forArc(arc.id, 'last-puzzle'),
    );
    if (puzzleSizes.containsKey(storedLastPuzzleId)) {
      lastPuzzleId = storedLastPuzzleId;
    }
  }

  Future<void> _migrateLegacySave() async {
    if ((_preferences.getInt(SaveIds.migrationVersion) ?? 0) >=
        saveMigrationVersion) {
      return;
    }

    Future<void> copyString(String legacy, String current) async {
      final value = _preferences.getString(legacy);
      if (value != null && !_preferences.containsKey(current)) {
        await _preferences.setString(current, value);
      }
    }

    Future<void> copyBool(String legacy, String current) async {
      final value = _preferences.getBool(legacy);
      if (value != null && !_preferences.containsKey(current)) {
        await _preferences.setBool(current, value);
      }
    }

    await copyString('regalia.settings', SaveIds.settings);
    await copyBool('regalia.tutorialComplete', SaveIds.tutorialComplete);
    final legacyFullMapUnlocked =
        _preferences.getBool('regalia.fullMapUnlocked') ??
        _preferences.getBool(SaveIds.originFullMap) ??
        false;
    if (legacyFullMapUnlocked &&
        !_preferences.containsKey(SaveIds.unlockedContentIds)) {
      await _preferences.setStringList(SaveIds.unlockedContentIds, [
        ContentIds.originFullMapUnlock,
      ]);
    }

    final legacyBoards = _preferences.getString('regalia.boards');
    if (legacyBoards != null &&
        !_preferences.containsKey(SaveIds.originBoards)) {
      try {
        final raw = jsonDecode(legacyBoards) as Map<String, Object?>;
        final migrated = <String, Object?>{};
        for (final entry in raw.entries) {
          final id = ContentIds.migratePuzzleId(entry.key);
          final board = Map<String, Object?>.from(
            entry.value! as Map<String, Object?>,
          )..['puzzleId'] = id;
          migrated[id] = board;
        }
        await _preferences.setString(
          SaveIds.originBoards,
          jsonEncode(migrated),
        );
      } on Object catch (error) {
        debugPrint('Ignoring invalid legacy boards during migration: $error');
      }
    }

    final legacyRecords = _preferences.getString('regalia.records');
    if (legacyRecords != null &&
        !_preferences.containsKey(SaveIds.originRecords)) {
      try {
        final raw = jsonDecode(legacyRecords) as Map<String, Object?>;
        await _preferences.setString(
          SaveIds.originRecords,
          jsonEncode({
            for (final entry in raw.entries)
              ContentIds.migratePuzzleId(entry.key): entry.value,
          }),
        );
      } on Object catch (error) {
        debugPrint('Ignoring invalid legacy records during migration: $error');
      }
    }

    final legacyLastPuzzle = _preferences.getString('regalia.lastPuzzle');
    if (legacyLastPuzzle != null &&
        !_preferences.containsKey(SaveIds.originLastPuzzle)) {
      await _preferences.setString(
        SaveIds.originLastPuzzle,
        ContentIds.migratePuzzleId(legacyLastPuzzle),
      );
    }

    final legacyScenes = _preferences.getStringList('regalia.seenStoryBeats');
    if (legacyScenes != null &&
        !_preferences.containsKey(SaveIds.originSeenScenes)) {
      await _preferences.setStringList(
        SaveIds.originSeenScenes,
        legacyScenes.map(ContentIds.originScene).toSet().toList()..sort(),
      );
    }

    final legacyChallenge = _preferences.getString('regalia.challengeSession');
    if (legacyChallenge != null &&
        !_preferences.containsKey(SaveIds.justPuzzleSession)) {
      try {
        final raw = jsonDecode(legacyChallenge);
        await _preferences.setString(
          SaveIds.justPuzzleSession,
          jsonEncode(_migrateEmbeddedPuzzleIds(raw)),
        );
      } on Object catch (error) {
        debugPrint('Ignoring invalid legacy Just Puzzle run: $error');
      }
    }
    await copyString(
      'regalia.challengeDiversityHistory',
      SaveIds.justPuzzleDiversity,
    );
    final legacyRetries = _preferences.getString('regalia.challengeRetrySalts');
    if (legacyRetries != null &&
        !_preferences.containsKey(SaveIds.justPuzzleRetries)) {
      try {
        final raw = jsonDecode(legacyRetries) as Map<String, Object?>;
        await _preferences.setString(
          SaveIds.justPuzzleRetries,
          jsonEncode({
            for (final entry in raw.entries)
              ContentIds.migratePuzzleId(entry.key): entry.value,
          }),
        );
      } on Object catch (error) {
        debugPrint('Ignoring invalid legacy retry state: $error');
      }
    }

    if (_catalogFingerprint != null) {
      await _preferences.setString(
        SaveIds.originCatalogFingerprint,
        _catalogFingerprint!,
      );
    }
    await _preferences.setInt(
      'regalia.journeySchemaVersion',
      journeySchemaVersion,
    );
    await _preferences.setInt(SaveIds.migrationVersion, saveMigrationVersion);

    // Legacy data is removed only after every namespaced value has been
    // committed. The journey schema marker remains as a compatibility guard.
    await Future.wait([
      for (final key in const [
        'regalia.settings',
        'regalia.tutorialComplete',
        'regalia.fullMapUnlocked',
        SaveIds.originFullMap,
        'regalia.boards',
        'regalia.records',
        'regalia.lastPuzzle',
        'regalia.seenStoryBeats',
        'regalia.challengeSession',
        'regalia.challengeDiversityHistory',
        'regalia.challengeRetrySalts',
        'regalia.catalogFingerprint',
      ])
        _preferences.remove(key),
    ]);
  }

  Object? _migrateEmbeddedPuzzleIds(Object? value) {
    if (value is List<Object?>) {
      return value.map(_migrateEmbeddedPuzzleIds).toList();
    }
    if (value is Map<String, Object?>) {
      return {
        for (final entry in value.entries)
          entry.key:
              (entry.key == 'id' || entry.key == 'puzzleId') &&
                      entry.value is String
                  ? ContentIds.migratePuzzleId(entry.value! as String)
                  : _migrateEmbeddedPuzzleIds(entry.value),
      };
    }
    return value;
  }

  Future<void> _clearOriginProgress({bool keepSeenScenes = false}) async {
    await Future.wait([
      _preferences.remove(SaveIds.originBoards),
      _preferences.remove(SaveIds.originRecords),
      _preferences.remove(SaveIds.originLastPuzzle),
      if (!keepSeenScenes) _preferences.remove(SaveIds.originSeenScenes),
    ]);
  }

  void _restoreChallengeGenerationState() {
    final historyPayload = _preferences.getString(SaveIds.justPuzzleDiversity);
    if (historyPayload != null) {
      try {
        final raw = jsonDecode(historyPayload);
        if (raw is List<Object?>) {
          final restored = <PuzzleDiversitySignature>[];
          for (final item in raw) {
            try {
              restored.add(
                PuzzleDiversitySignature.fromJson(
                  item! as Map<String, Object?>,
                ),
              );
            } on Object {
              // Ignore a damaged entry without discarding the useful history.
            }
          }
          _challengeDiversityHistory = ChallengeSession.normalizeSignatures(
            restored,
          );
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid challenge diversity history: $error');
      }
    }
    for (final signature in challengeSession?.recentSignatures ?? const []) {
      _rememberChallengeSignature(signature);
    }

    final retryPayload = _preferences.getString(SaveIds.justPuzzleRetries);
    if (retryPayload != null) {
      try {
        final raw = jsonDecode(retryPayload);
        if (raw is Map<String, Object?>) {
          for (final entry in raw.entries) {
            final value = entry.value;
            if (value is num && value.toInt() > 0) {
              _challengeRetrySalts[entry.key] = value.toInt();
            }
          }
        }
      } on Object catch (error) {
        debugPrint('Ignoring invalid challenge retry state: $error');
      }
    }
  }

  void _rememberChallengeSignature(PuzzleDiversitySignature signature) {
    _challengeDiversityHistory = ChallengeSession.rememberSignature(
      _challengeDiversityHistory,
      signature,
    );
  }

  T? _decode<T>(String key, T Function(Map<String, Object?>) decode) {
    final value = _preferences.getString(key);
    if (value == null) return null;
    try {
      return decode(jsonDecode(value) as Map<String, Object?>);
    } on Object catch (error) {
      debugPrint('Ignoring invalid $key: $error');
      return null;
    }
  }

  BoardState boardFor(PuzzleDefinition puzzle) {
    final challenge = challengeSession;
    if (challenge?.currentPuzzle.id == puzzle.id) return challenge!.board;
    return boards.putIfAbsent(
      puzzle.id,
      () => BoardState(puzzleId: puzzle.id, size: puzzle.size),
    );
  }

  BoardState? _boardById(String puzzleId) {
    final challenge = challengeSession;
    if (challenge?.currentPuzzle.id == puzzleId) return challenge!.board;
    return boards[puzzleId];
  }

  bool get hasChallenge => challengeSession != null;

  JourneyChapter challengeVisualChapter(DifficultyTier tier, int number) =>
      challengeChapterFor(
        tier,
        number,
        chapters: originArc?.chapters ?? journeyChapters,
      );

  Future<bool> startChallenge(ChallengeMode mode, {int? seed}) async {
    if (!justPuzzleAvailable || isStartingChallenge) return false;
    final startEpoch = ++_challengeStartEpoch;
    isStartingChallenge = true;
    challengeGenerationError = null;
    notifyListeners();
    final sessionSeed =
        seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
    final spec = challengeSpec(mode: mode, sessionSeed: sessionSeed, number: 1);
    try {
      // A replacement run waits for the single existing worker instead of
      // competing with it for CPU and battery. The busy flag also prevents the
      // old prefetch from chaining another board while this request waits.
      final pendingPrefetch = _challengePrefetch;
      if (pendingPrefetch != null) await pendingPrefetch;
      if (_disposed || startEpoch != _challengeStartEpoch) return false;
      challengeGenerationError = null;
      final result = await challengePuzzleFactory(
        spec,
        _challengeGenerationContext(spec),
      );
      if (_disposed || startEpoch != _challengeStartEpoch) return false;
      _validateChallengeResult(result, spec);
      final puzzle = result.puzzle;
      _rememberChallengeSignature(result.signature);
      _challengeRetrySalts.remove(spec.puzzleId);
      challengeSession = ChallengeSession(
        seed: sessionSeed,
        mode: mode,
        currentNumber: 1,
        currentPuzzle: puzzle,
        board: BoardState(puzzleId: puzzle.id, size: puzzle.size),
        completedCount: 0,
        cleanCount: 0,
        assistedCount: 0,
        recentSignatures: _challengeDiversityHistory,
      );
      isStartingChallenge = false;
      challengeGenerationError = null;
      notifyListeners();
      await _save();
      unawaited(ensureChallengeQueued());
      return true;
    } on Object catch (error) {
      if (_disposed || startEpoch != _challengeStartEpoch) return false;
      _challengeRetrySalts[spec.puzzleId] =
          (_challengeRetrySalts[spec.puzzleId] ?? 0) + 1;
      isStartingChallenge = false;
      challengeGenerationError = error;
      notifyListeners();
      await _save();
      return false;
    }
  }

  Future<void> ensureChallengeQueued() {
    final session = challengeSession;
    if (session == null ||
        !_challengePreparationAllowed ||
        session.preparedPuzzles.length >= _challengePreparedTarget) {
      return Future.value();
    }
    final existing = _challengePrefetch;
    if (existing != null) return existing;
    isPreparingChallenge = true;
    challengeGenerationError = null;
    if (!_disposed) notifyListeners();
    final nextNumber =
        session.currentNumber + session.preparedPuzzles.length + 1;
    final spec = challengeSpec(
      mode: session.mode,
      sessionSeed: session.seed,
      number: nextNumber,
    );
    final operation = _runChallengePrefetch(session.seed, session.mode, spec);
    _challengePrefetch = operation;
    return operation;
  }

  Future<void> _runChallengePrefetch(
    int sessionSeed,
    ChallengeMode mode,
    ChallengeGenerationSpec spec,
  ) async {
    try {
      final result = await challengePuzzleFactory(
        spec,
        _challengeGenerationContext(spec),
      );
      if (_disposed) return;
      final current = challengeSession;
      if (current != null &&
          current.seed == sessionSeed &&
          current.mode == mode &&
          current.currentNumber + current.preparedPuzzles.length + 1 ==
              spec.number) {
        _validateChallengeResult(result, spec);
        _rememberChallengeSignature(result.signature);
        challengeSession = current.withPrepared(
          result.puzzle,
          result.signature,
        );
        _challengeRetrySalts.remove(spec.puzzleId);
        challengeGenerationError = null;
        await _save();
      }
    } on Object catch (error) {
      final current = challengeSession;
      if (!_disposed &&
          current != null &&
          current.seed == sessionSeed &&
          current.mode == mode &&
          current.currentNumber + current.preparedPuzzles.length + 1 ==
              spec.number) {
        _challengeRetrySalts[spec.puzzleId] =
            (_challengeRetrySalts[spec.puzzleId] ?? 0) + 1;
        challengeGenerationError = error;
        await _save();
      }
    } finally {
      if (!_disposed) {
        isPreparingChallenge = false;
        _challengePrefetch = null;
        notifyListeners();
        final current = challengeSession;
        if (!isStartingChallenge &&
            _challengePreparationAllowed &&
            challengeGenerationError == null &&
            current != null &&
            current.preparedPuzzles.length < _challengePreparedTarget) {
          unawaited(ensureChallengeQueued());
        }
      }
    }
  }

  ChallengeGenerationContext _challengeGenerationContext(
    ChallengeGenerationSpec spec,
  ) {
    final session = challengeSession;
    return ChallengeGenerationContext(
      storyPuzzles: [
        for (final puzzle in catalog?.puzzles ?? const <PuzzleDefinition>[])
          if (puzzle.size == spec.size) puzzle,
      ],
      recentPuzzles: [
        if (session != null && session.currentPuzzle.size == spec.size)
          session.currentPuzzle,
        if (session != null)
          for (final puzzle in session.preparedPuzzles)
            if (puzzle.size == spec.size) puzzle,
      ],
      recentSignatures: [
        for (final signature in _challengeDiversityHistory)
          if (signature.size == spec.size) signature,
      ],
      retrySalt: _challengeRetrySalts[spec.puzzleId] ?? 0,
    );
  }

  void _validateChallengeResult(
    ChallengePuzzleResult result,
    ChallengeGenerationSpec spec,
  ) {
    final puzzle = result.puzzle;
    const generator = PuzzleGenerator();
    if (puzzle.id != spec.puzzleId ||
        puzzle.order != spec.number ||
        puzzle.tier != spec.tier ||
        puzzle.size != spec.size ||
        result.signature.size != spec.size ||
        result.signature.canonicalFingerprint !=
            generator.canonicalFingerprint(puzzle) ||
        result.signature.boundarySignature !=
            generator.boundarySignature(puzzle) ||
        PuzzleDefinition.stableHash(puzzle.size, puzzle.regions) !=
            puzzle.contentHash) {
      throw const FormatException('Invalid generated challenge puzzle');
    }
  }

  bool openChallengePuzzle() {
    if (challengeSession == null || isStartingChallenge) return false;
    unawaited(_save());
    notifyListeners();
    return true;
  }

  Future<PuzzleDefinition?> advanceChallenge() async {
    var session = challengeSession;
    if (session == null) return null;
    if (!session.currentCompleted) return session.currentPuzzle;
    if (session.queuedPuzzle == null) {
      await ensureChallengeQueued();
      session = challengeSession;
    }
    final next = session?.queuedPuzzle;
    if (session == null || next == null) return null;
    challengeSession = session.advanceToPrepared();
    challengeGenerationError = null;
    notifyListeners();
    await _save();
    unawaited(ensureChallengeQueued());
    return next;
  }

  Future<void> abandonChallenge() async {
    _challengeStartEpoch++;
    stopTimer();
    challengeSession = null;
    challengeGenerationError = null;
    isPreparingChallenge = false;
    isStartingChallenge = false;
    _challengeRetrySalts.clear();
    notifyListeners();
    await _save();
  }

  CompletionRecord recordFor(String id) =>
      records[id] ?? const CompletionRecord();

  JourneyProgress get journeyProgress => JourneyProgress.derive(
    catalog: catalog!,
    recordFor: recordFor,
    hasActiveBoard: hasActiveBoard,
  );

  JourneyProgress journeyProgressFor(StoryArc arc) => JourneyProgress.derive(
    catalog: arc.catalog,
    recordFor: recordFor,
    hasActiveBoard: hasActiveBoard,
  );

  PuzzleDefinition? get frontierPuzzle => journeyProgress.frontierPuzzle;

  PuzzleDefinition? frontierPuzzleFor(StoryArc arc) =>
      journeyProgressFor(arc).frontierPuzzle;

  bool get isJourneyComplete => journeyProgress.isJourneyComplete;

  StoryArc? arcForPuzzle(PuzzleDefinition puzzle) {
    for (final arc in availableStoryArcs) {
      if (ContentId.belongsToArc(puzzle.id, arc.id, kind: 'puzzle')) return arc;
    }
    return null;
  }

  AcademyLesson? academyLessonForPuzzle(PuzzleDefinition puzzle) =>
      academy?.lessonForPuzzle(puzzle);

  bool isAcademyLessonComplete(AcademyLesson lesson) =>
      completedAcademyLessonIds.contains(lesson.id);

  bool isAcademyLessonUnlocked(AcademyLesson lesson) {
    final lessons = academyLessons;
    final index = lessons.indexWhere((candidate) => candidate.id == lesson.id);
    if (index < 0) return false;
    return index == 0 || isAcademyLessonComplete(lessons[index - 1]);
  }

  /// Opens a fresh, Academy-owned attempt without creating a journey record.
  bool openAcademyPractice(AcademyLesson lesson) {
    if (!isAcademyLessonUnlocked(lesson)) return false;
    final board = boardFor(lesson.practicePuzzle);
    board.cells.fillRange(0, board.cells.length, ManualCellState.empty);
    board.undoStack.clear();
    board.redoStack.clear();
    board.elapsedSeconds = 0;
    board.assisted = false;
    board.hintCount = 0;
    board.checkCount = 0;
    unawaited(_save());
    notifyListeners();
    return true;
  }

  StoryArc? arcForChapter(JourneyChapter chapter) {
    for (final arc in availableStoryArcs) {
      if (ContentId.belongsToArc(chapter.id, arc.id, kind: 'chapter')) {
        return arc;
      }
    }
    return null;
  }

  StoryArc? arcForScene(String sceneId) {
    for (final arc in availableStoryArcs) {
      if (ContentId.belongsToArc(sceneId, arc.id, kind: 'scene')) return arc;
    }
    return null;
  }

  bool canOpenPuzzle(PuzzleDefinition puzzle) {
    final arc = arcForPuzzle(puzzle);
    return arc != null &&
        (isMapUnlocked(arc.id) ||
            journeyProgressFor(arc).canOpen(puzzle, recordFor(puzzle.id)));
  }

  JourneyChapter chapterForPuzzleOrder(int order) =>
      originArc!.chapterForOrder(order);

  bool hasSeenStoryBeat(String id) =>
      seenStoryBeatIds.contains(ContentIds.originScene(id));

  Future<void> markStoryBeatSeen(String id) async {
    final sceneId = ContentIds.originScene(id);
    if (!seenStoryBeatIds.add(sceneId)) return;
    notifyListeners();
    final arc = arcForScene(sceneId);
    await _preferences.setStringList(
      arc == null
          ? SaveIds.originSeenScenes
          : SaveIds.forArc(arc.id, 'seen-scenes'),
      (seenStoryBeatIds
          .where(
            (candidate) =>
                arc == null ||
                ContentId.belongsToArc(candidate, arc.id, kind: 'scene'),
          )
          .toList()
        ..sort()),
    );
  }

  /// Claims the one-time web support prompt after the puzzle immediately
  /// before a chapter boss. Returning a chapter means the caller owns showing
  /// that prompt; the claim is persisted before UI is presented.
  Future<JourneyChapter?> claimSupportPromptAfter(
    StoryArc arc,
    PuzzleDefinition puzzle,
  ) async {
    if (contentPolicy.channel != ReleaseChannel.web ||
        arcForPuzzle(puzzle)?.id != arc.id) {
      return null;
    }
    final status = recordFor(puzzle.id).status;
    if (status != CompletionStatus.cleanSolved &&
        status != CompletionStatus.assistedSolved) {
      return null;
    }
    final chapter = arc.chapterForOrder(puzzle.order);
    if (chapter.endOrder <= chapter.startOrder ||
        puzzle.order != chapter.endOrder - 1 ||
        !supportPromptedChapterIds.add(chapter.id)) {
      return null;
    }
    notifyListeners();
    await _save();
    return chapter;
  }

  CompletionStatus statusFor(PuzzleDefinition puzzle) =>
      hasActiveBoard(puzzle)
          ? CompletionStatus.inProgress
          : recordFor(puzzle.id).status;

  PuzzleDefinition recommendedPuzzle() {
    return recommendedPuzzleFor(originArc!);
  }

  PuzzleDefinition recommendedPuzzleFor(StoryArc arc) {
    final puzzles = arc.catalog.puzzles;
    final frontier = frontierPuzzleFor(arc);
    if (frontier != null) return frontier;
    return puzzles.firstWhere(
      (puzzle) =>
          recordFor(puzzle.id).status == CompletionStatus.assistedSolved,
      orElse: () => puzzles.first,
    );
  }

  bool hasActiveBoard(PuzzleDefinition puzzle) {
    final board = boards[puzzle.id];
    return board != null &&
        board.cells.any((cell) => cell != ManualCellState.empty) &&
        !ruleEngine.isComplete(puzzle, board);
  }

  bool openPuzzle(PuzzleDefinition puzzle) {
    // Keep this guard before every mutation, including board creation and the
    // last-puzzle pointer. A locked node is a completely read-only action.
    if (!canOpenPuzzle(puzzle)) return false;
    lastPuzzleId = puzzle.id;
    final board = boardFor(puzzle);
    final record = recordFor(puzzle.id);
    if (record.status == CompletionStatus.newPuzzle) {
      records[puzzle.id] = CompletionRecord(
        status: CompletionStatus.inProgress,
        attemptCount: record.attemptCount + 1,
      );
    } else if (record.status == CompletionStatus.assistedSolved ||
        record.status == CompletionStatus.cleanSolved) {
      if (hasActiveBoard(puzzle)) {
        unawaited(_save());
        notifyListeners();
        return true;
      }
      board.cells.fillRange(0, board.cells.length, ManualCellState.empty);
      board.undoStack.clear();
      board.redoStack.clear();
      board.elapsedSeconds = 0;
      board.assisted = false;
      board.hintCount = 0;
      board.checkCount = 0;
      records[puzzle.id] = CompletionRecord(
        status: record.status,
        bestCleanSeconds: record.bestCleanSeconds,
        bestAssistedSeconds: record.bestAssistedSeconds,
        attemptCount: record.attemptCount + 1,
      );
    }
    unawaited(_save());
    notifyListeners();
    return true;
  }

  PuzzleCompletionOutcome? cycle(PuzzleDefinition puzzle, Cell cell) {
    final board = boardFor(puzzle)..cycle(cell);
    final completed = _recordCompletionIfNeeded(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return completed;
  }

  PuzzleCompletionOutcome? setCell(
    PuzzleDefinition puzzle,
    Cell cell,
    ManualCellState state,
  ) {
    final board = boardFor(puzzle)..set(cell, state);
    final completed = _recordCompletionIfNeeded(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return completed;
  }

  void beginCellBatch(PuzzleDefinition puzzle) {
    boardFor(puzzle).beginBatch();
  }

  void endCellBatch(PuzzleDefinition puzzle) {
    if (boardFor(puzzle).endBatch()) {
      unawaited(_save());
      notifyListeners();
    }
  }

  PuzzleCompletionOutcome? _recordCompletionIfNeeded(
    PuzzleDefinition puzzle,
    BoardState board,
  ) {
    if (!ruleEngine.isComplete(puzzle, board)) return null;
    final challenge = challengeSession;
    if (challenge?.currentPuzzle.id == puzzle.id) {
      challengeSession = challenge!.complete(assisted: board.assisted);
      stopTimer();
      return PuzzleCompletionOutcome(
        puzzle: puzzle,
        advancedJourney: false,
        nextPuzzle: null,
        enteredChapter: null,
        isJourneyComplete: false,
        isChallenge: true,
      );
    }
    final academyLesson = academyLessonForPuzzle(puzzle);
    if (academyLesson != null) {
      completedAcademyLessonIds.add(academyLesson.id);
      stopTimer();
      return PuzzleCompletionOutcome(
        puzzle: puzzle,
        advancedJourney: false,
        nextPuzzle: null,
        enteredChapter: null,
        isJourneyComplete: false,
      );
    }
    final arc = arcForPuzzle(puzzle);
    if (arc == null) return null;
    final wasFrontier = frontierPuzzleFor(arc)?.id == puzzle.id;
    records[puzzle.id] = recordFor(
      puzzle.id,
    ).complete(assisted: board.assisted, seconds: board.elapsedSeconds);
    stopTimer();
    final next = frontierPuzzleFor(arc);
    final currentChapter = arc.chapterForOrder(puzzle.order);
    final nextChapter = next == null ? null : arc.chapterForOrder(next.order);
    final journeyComplete = wasFrontier && next == null;
    final boss = arc.bossForPuzzle(puzzle);
    if (boss?.unlockTargetId == arc.unlockIds.finale) {
      unlockedContentIds.add(arc.unlockIds.finale);
    }
    return PuzzleCompletionOutcome(
      puzzle: puzzle,
      advancedJourney: wasFrontier,
      nextPuzzle: wasFrontier ? next : null,
      enteredChapter:
          wasFrontier &&
                  nextChapter != null &&
                  nextChapter.id != currentChapter.id
              ? nextChapter
              : null,
      isJourneyComplete: journeyComplete,
    );
  }

  void undo(PuzzleDefinition puzzle) {
    if (boardFor(puzzle).undo()) {
      unawaited(_save());
      notifyListeners();
    }
  }

  void redo(PuzzleDefinition puzzle) {
    if (boardFor(puzzle).redo()) {
      unawaited(_save());
      notifyListeners();
    }
  }

  void reset(PuzzleDefinition puzzle) {
    final board = boardFor(puzzle);
    board.reset();
    board.elapsedSeconds = 0;
    board.assisted = false;
    board.hintCount = 0;
    board.checkCount = 0;
    if (academyLessonForPuzzle(puzzle) != null) {
      unawaited(_save());
      notifyListeners();
      return;
    }
    if (challengeSession?.currentPuzzle.id == puzzle.id) {
      unawaited(_save());
      notifyListeners();
      return;
    }
    final record = recordFor(puzzle.id);
    records[puzzle.id] = CompletionRecord(
      status:
          record.status == CompletionStatus.cleanSolved
              ? CompletionStatus.cleanSolved
              : record.status == CompletionStatus.assistedSolved
              ? CompletionStatus.assistedSolved
              : CompletionStatus.inProgress,
      bestCleanSeconds: record.bestCleanSeconds,
      bestAssistedSeconds: record.bestAssistedSeconds,
      attemptCount: record.attemptCount + 1,
    );
    unawaited(_save());
    notifyListeners();
  }

  ProgressCheck checkProgress(PuzzleDefinition puzzle) {
    final board = boardFor(puzzle);
    board.assisted = true;
    board.checkCount++;
    final check = ruleEngine.check(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return check;
  }

  Deduction? hint(PuzzleDefinition puzzle) {
    final board = boardFor(puzzle);
    board.assisted = true;
    board.hintCount++;
    final deduction = humanSolver.nextDeduction(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return deduction;
  }

  void startTimer(String puzzleId) {
    _activePuzzleId = puzzleId;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final board = _boardById(puzzleId);
      if (board == null) return;
      board.elapsedSeconds++;
      if (board.elapsedSeconds % 10 == 0) unawaited(_save());
      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _activePuzzleId = null;
    if (isReady) unawaited(_save());
  }

  void updateSettings(AppSettings value) {
    settings = value;
    unawaited(_save());
    notifyListeners();
  }

  bool isMapUnlocked(String arcId) {
    final arc = content?.arc(arcId);
    return arc != null && unlockedContentIds.contains(arc.unlockIds.fullMap);
  }

  bool isFinaleUnlocked(String arcId) {
    final arc = content?.arc(arcId);
    return arc != null && _hasDefeatedFinalBoss(arc);
  }

  bool _hasDefeatedFinalBoss(StoryArc arc) {
    final finalBoss = arc.chapters.last.boss;
    final status = recordFor(finalBoss.puzzleId).status;
    return status == CompletionStatus.cleanSolved ||
        status == CompletionStatus.assistedSolved;
  }

  bool _reconcileFinaleUnlocksWithBossRecords() {
    var changed = false;
    for (final arc in availableStoryArcs) {
      if (_hasDefeatedFinalBoss(arc)) {
        changed = unlockedContentIds.add(arc.unlockIds.finale) || changed;
      } else {
        changed = unlockedContentIds.remove(arc.unlockIds.finale) || changed;
      }
    }
    return changed;
  }

  Future<void> unlockEntireMap(String arcId) async {
    final arc = content?.arc(arcId);
    if (arc == null) throw ArgumentError.value(arcId, 'arcId');
    final changed = unlockedContentIds.add(arc.unlockIds.fullMap);
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  Future<void> resetStoryArc(String arcId) async {
    final arc = content?.arc(arcId);
    if (arc == null) throw ArgumentError.value(arcId, 'arcId');

    bool belongs(String id, String kind) =>
        ContentId.belongsToArc(id, arcId, kind: kind);
    if (_activePuzzleId != null && belongs(_activePuzzleId!, 'puzzle')) {
      stopTimer();
    }
    boards.removeWhere((id, _) => belongs(id, 'puzzle'));
    records.removeWhere((id, _) => belongs(id, 'puzzle'));
    seenStoryBeatIds.removeWhere((id) => belongs(id, 'scene'));
    supportPromptedChapterIds.removeWhere((id) => belongs(id, 'chapter'));
    unlockedContentIds.removeWhere((id) => belongs(id, 'unlock'));
    if (lastPuzzleId != null && belongs(lastPuzzleId!, 'puzzle')) {
      lastPuzzleId = null;
    }
    notifyListeners();
    await _save();
    await Future.wait([
      _preferences.remove(SaveIds.forArc(arcId, 'boards')),
      _preferences.remove(SaveIds.forArc(arcId, 'records')),
      _preferences.remove(SaveIds.forArc(arcId, 'last-puzzle')),
      _preferences.remove(SaveIds.forArc(arcId, 'seen-scenes')),
    ]);
  }

  Future<void> resetGame() async {
    // Invalidate generated work before clearing its in-memory session so an
    // old result cannot restore data after preferences have been erased.
    _challengeStartEpoch++;
    _timer?.cancel();
    _timer = null;
    _activePuzzleId = null;
    challengeSession = null;
    isStartingChallenge = false;
    isPreparingChallenge = false;
    challengeGenerationError = null;
    _challengeRetrySalts.clear();
    _challengeDiversityHistory = const [];

    // Let already-queued snapshots finish first, then erase them together.
    await _saveChain;
    await _preferences.clear();

    settings = const AppSettings();
    boards.clear();
    records.clear();
    seenStoryBeatIds.clear();
    supportPromptedChapterIds.clear();
    completedAcademyLessonIds.clear();
    tutorialComplete = false;
    unlockedContentIds.clear();
    lastPuzzleId = null;
    gameGeneration++;
    notifyListeners();
  }

  Future<void> finishTutorial() async {
    tutorialComplete = true;
    notifyListeners();
    await _preferences.setBool(SaveIds.tutorialComplete, true);
  }

  Future<void> _save() {
    final settingsJson = jsonEncode(settings.toJson());
    final latestPuzzle = lastPuzzleId;
    final challengeJson =
        challengeSession == null
            ? null
            : jsonEncode(challengeSession!.toJson());
    final challengeDiversityJson = jsonEncode([
      for (final signature in _challengeDiversityHistory) signature.toJson(),
    ]);
    final challengeRetryJson = jsonEncode(_challengeRetrySalts);
    final academyBoardsJson = jsonEncode({
      for (final lesson in academyLessons)
        if (boards.containsKey(lesson.practicePuzzle.id))
          lesson.practicePuzzle.id: boards[lesson.practicePuzzle.id]!.toJson(),
    });
    final academyCompleted = completedAcademyLessonIds.toList()..sort();
    final arcSnapshots = {
      for (final arc in availableStoryArcs)
        arc.id: (
          boards: jsonEncode({
            for (final entry in boards.entries)
              if (ContentId.belongsToArc(entry.key, arc.id, kind: 'puzzle'))
                entry.key: entry.value.toJson(),
          }),
          records: jsonEncode({
            for (final entry in records.entries)
              if (ContentId.belongsToArc(entry.key, arc.id, kind: 'puzzle'))
                entry.key: entry.value.toJson(),
          }),
          scenes:
              (seenStoryBeatIds
                  .where(
                    (id) => ContentId.belongsToArc(id, arc.id, kind: 'scene'),
                  )
                  .toList()
                ..sort()),
        ),
    };
    _saveChain = _saveChain.then(
      (_) => Future.wait([
        _preferences.setString(SaveIds.settings, settingsJson),
        for (final arc in availableStoryArcs) ...[
          _preferences.setString(
            SaveIds.forArc(arc.id, 'catalog-fingerprint'),
            _arcCatalogFingerprints[arc.id]!,
          ),
          _preferences.setString(
            SaveIds.forArc(arc.id, 'boards'),
            arcSnapshots[arc.id]!.boards,
          ),
          _preferences.setString(
            SaveIds.forArc(arc.id, 'records'),
            arcSnapshots[arc.id]!.records,
          ),
          _preferences.setStringList(
            SaveIds.forArc(arc.id, 'seen-scenes'),
            arcSnapshots[arc.id]!.scenes,
          ),
        ],
        _preferences.setStringList(
          SaveIds.unlockedContentIds,
          unlockedContentIds.toList()..sort(),
        ),
        _preferences.setStringList(
          SaveIds.supportPromptedChapters,
          supportPromptedChapterIds.toList()..sort(),
        ),
        if (challengeJson == null)
          _preferences.remove(SaveIds.justPuzzleSession)
        else
          _preferences.setString(SaveIds.justPuzzleSession, challengeJson),
        _preferences.setString(
          SaveIds.justPuzzleDiversity,
          challengeDiversityJson,
        ),
        _preferences.setString(SaveIds.justPuzzleRetries, challengeRetryJson),
        if (academy != null) ...[
          _preferences.setString(SaveIds.academyBoards, academyBoardsJson),
          _preferences.setStringList(
            SaveIds.academyCompletedLessons,
            academyCompleted,
          ),
        ],
        if (latestPuzzle != null)
          for (final arc in availableStoryArcs)
            if (ContentId.belongsToArc(latestPuzzle, arc.id, kind: 'puzzle'))
              _preferences.setString(
                SaveIds.forArc(arc.id, 'last-puzzle'),
                latestPuzzle,
              ),
      ]),
    );
    return _saveChain;
  }

  Future<void> flushPersistence() => _saveChain;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _challengePreparationAllowed = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      if (_activePuzzleId != null) startTimer(_activePuzzleId!);
      if (challengeSession != null &&
          challengeSession!.preparedPuzzles.length < _challengePreparedTarget) {
        unawaited(ensureChallengeQueued());
      }
    } else {
      _timer?.cancel();
      _timer = null;
      if (isReady) unawaited(_save());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
