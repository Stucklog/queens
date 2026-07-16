import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/challenge_generator.dart';
import '../core/human_solver.dart';
import '../core/models.dart';
import '../core/rule_engine.dart';
import 'challenge.dart';
import 'journey.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.showTimer = true,
    this.showAutomaticExclusions = true,
    this.reducedMotion = false,
  });

  final ThemeMode themeMode;
  final bool showTimer;
  final bool showAutomaticExclusions;
  final bool reducedMotion;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? showTimer,
    bool? showAutomaticExclusions,
    bool? reducedMotion,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    showTimer: showTimer ?? this.showTimer,
    showAutomaticExclusions:
        showAutomaticExclusions ?? this.showAutomaticExclusions,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );

  Map<String, Object> toJson() => {
    'themeMode': themeMode.name,
    'showTimer': showTimer,
    'showAutomaticExclusions': showAutomaticExclusions,
    'reducedMotion': reducedMotion,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (mode) => mode.name == json['themeMode'],
      orElse: () => ThemeMode.system,
    ),
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
  });

  final RuleEngine ruleEngine;
  final HumanSolver humanSolver;
  final ChallengePuzzleFactory challengePuzzleFactory;
  static const journeySchemaVersion = 1;
  late final SharedPreferences _preferences;
  late final String _catalogFingerprint;
  PuzzleCatalog? catalog;
  PuzzleDefinition? tutorialPuzzle;
  AppSettings settings = const AppSettings();
  final Map<String, BoardState> boards = {};
  final Map<String, CompletionRecord> records = {};
  final Set<String> seenStoryBeatIds = {};
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
  bool _disposed = false;

  bool get isReady => catalog != null;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final source = await rootBundle.loadString('assets/puzzles/catalog.json');
    final tutorialSource = await rootBundle.loadString(
      'assets/puzzles/tutorial.json',
    );
    catalog = PuzzleCatalog.fromJsonString(source);
    _catalogFingerprint =
        '${catalog!.schemaVersion}:${catalog!.puzzles.map((puzzle) => puzzle.contentHash).join(',')}';
    tutorialPuzzle = PuzzleDefinition.fromJson(
      jsonDecode(tutorialSource) as Map<String, Object?>,
    );
    _preferences = await SharedPreferences.getInstance();
    settings =
        _decode('regalia.settings', AppSettings.fromJson) ??
        const AppSettings();
    challengeSession = _decode(
      'regalia.challengeSession',
      ChallengeSession.fromJson,
    );
    tutorialComplete =
        _preferences.getBool('regalia.tutorialComplete') ?? false;
    if (_preferences.getInt('regalia.journeySchemaVersion') !=
        journeySchemaVersion) {
      // Version one changes a freely selectable collection into a strict
      // journey. Old attempt data cannot establish a trustworthy frontier, so
      // it is cleared once while settings and tutorial completion survive.
      await Future.wait([
        _preferences.remove('regalia.boards'),
        _preferences.remove('regalia.records'),
        _preferences.remove('regalia.lastPuzzle'),
        _preferences.remove('regalia.seenStoryBeats'),
        _preferences.setInt(
          'regalia.journeySchemaVersion',
          journeySchemaVersion,
        ),
      ]);
    }
    if (_preferences.getString('regalia.catalogFingerprint') !=
        _catalogFingerprint) {
      // Puzzle IDs stay stable between curated releases. Discard attempt data
      // when their underlying boards change so marks and completions cannot be
      // applied to a different puzzle.
      await Future.wait([
        _preferences.remove('regalia.boards'),
        _preferences.remove('regalia.records'),
        _preferences.remove('regalia.lastPuzzle'),
        _preferences.setString(
          'regalia.catalogFingerprint',
          _catalogFingerprint,
        ),
      ]);
    }
    final puzzleSizes = {
      for (final puzzle in catalog!.puzzles) puzzle.id: puzzle.size,
    };
    final storedLastPuzzleId = _preferences.getString('regalia.lastPuzzle');
    lastPuzzleId =
        puzzleSizes.containsKey(storedLastPuzzleId) ? storedLastPuzzleId : null;
    final boardPayload = _preferences.getString('regalia.boards');
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
    final recordPayload = _preferences.getString('regalia.records');
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
    final seenPayload = _preferences.getStringList('regalia.seenStoryBeats');
    if (seenPayload != null) seenStoryBeatIds.addAll(seenPayload);
    notifyListeners();
    if (challengeSession != null && challengeSession!.queuedPuzzle == null) {
      unawaited(ensureChallengeQueued());
    }
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

  Future<bool> startChallenge(ChallengeMode mode, {int? seed}) async {
    if (isStartingChallenge) return false;
    isStartingChallenge = true;
    challengeGenerationError = null;
    notifyListeners();
    final sessionSeed =
        seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
    final spec = challengeSpec(mode: mode, sessionSeed: sessionSeed, number: 1);
    try {
      final puzzle = await challengePuzzleFactory(spec);
      if (_disposed) return false;
      challengeSession = ChallengeSession(
        seed: sessionSeed,
        mode: mode,
        currentNumber: 1,
        currentPuzzle: puzzle,
        board: BoardState(puzzleId: puzzle.id, size: puzzle.size),
        completedCount: 0,
        cleanCount: 0,
        assistedCount: 0,
      );
      isStartingChallenge = false;
      challengeGenerationError = null;
      notifyListeners();
      await _save();
      unawaited(ensureChallengeQueued());
      return true;
    } on Object catch (error) {
      if (_disposed) return false;
      isStartingChallenge = false;
      challengeGenerationError = error;
      notifyListeners();
      return false;
    }
  }

  Future<void> ensureChallengeQueued() {
    final session = challengeSession;
    if (session == null || session.queuedPuzzle != null) {
      return Future.value();
    }
    final existing = _challengePrefetch;
    if (existing != null) return existing;
    isPreparingChallenge = true;
    challengeGenerationError = null;
    if (!_disposed) notifyListeners();
    final operation = _runChallengePrefetch(
      session.seed,
      session.currentNumber,
      challengeSpec(
        mode: session.mode,
        sessionSeed: session.seed,
        number: session.currentNumber + 1,
      ),
    );
    _challengePrefetch = operation;
    return operation;
  }

  Future<void> _runChallengePrefetch(
    int sessionSeed,
    int currentNumber,
    ChallengeGenerationSpec spec,
  ) async {
    try {
      final puzzle = await challengePuzzleFactory(spec);
      if (_disposed) return;
      final current = challengeSession;
      if (current != null &&
          current.seed == sessionSeed &&
          current.currentNumber == currentNumber &&
          current.queuedPuzzle == null) {
        challengeSession = current.withQueued(puzzle);
        challengeGenerationError = null;
        await _save();
      }
    } on Object catch (error) {
      if (!_disposed) challengeGenerationError = error;
    } finally {
      if (!_disposed) {
        final current = challengeSession;
        final prepareReplacement =
            current != null &&
            current.queuedPuzzle == null &&
            (current.seed != sessionSeed ||
                current.currentNumber != currentNumber);
        isPreparingChallenge = false;
        _challengePrefetch = null;
        notifyListeners();
        if (prepareReplacement) unawaited(ensureChallengeQueued());
      }
    }
  }

  bool openChallengePuzzle() {
    if (challengeSession == null) return false;
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
    challengeSession = session.advanceTo(next);
    challengeGenerationError = null;
    notifyListeners();
    await _save();
    unawaited(ensureChallengeQueued());
    return next;
  }

  Future<void> abandonChallenge() async {
    stopTimer();
    challengeSession = null;
    challengeGenerationError = null;
    isPreparingChallenge = false;
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

  PuzzleDefinition? get frontierPuzzle => journeyProgress.frontierPuzzle;

  bool get isJourneyComplete => journeyProgress.isJourneyComplete;

  bool canOpenPuzzle(PuzzleDefinition puzzle) =>
      journeyProgress.canOpen(puzzle, recordFor(puzzle.id));

  bool hasSeenStoryBeat(String id) => seenStoryBeatIds.contains(id);

  Future<void> markStoryBeatSeen(String id) async {
    if (!seenStoryBeatIds.add(id)) return;
    notifyListeners();
    await _preferences.setStringList(
      'regalia.seenStoryBeats',
      seenStoryBeatIds.toList()..sort(),
    );
  }

  CompletionStatus statusFor(PuzzleDefinition puzzle) =>
      hasActiveBoard(puzzle)
          ? CompletionStatus.inProgress
          : recordFor(puzzle.id).status;

  PuzzleDefinition recommendedPuzzle() {
    final puzzles = catalog!.puzzles;
    final frontier = frontierPuzzle;
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
    final wasFrontier = frontierPuzzle?.id == puzzle.id;
    records[puzzle.id] = recordFor(
      puzzle.id,
    ).complete(assisted: board.assisted, seconds: board.elapsedSeconds);
    stopTimer();
    final next = frontierPuzzle;
    final currentChapter = chapterForOrder(puzzle.order);
    final nextChapter = next == null ? null : chapterForOrder(next.order);
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
      isJourneyComplete: wasFrontier && next == null,
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

  Future<void> finishTutorial() async {
    tutorialComplete = true;
    notifyListeners();
    await _preferences.setBool('regalia.tutorialComplete', true);
  }

  Future<void> _save() {
    final settingsJson = jsonEncode(settings.toJson());
    final boardsJson = jsonEncode(
      boards.map((key, value) => MapEntry(key, value.toJson())),
    );
    final recordsJson = jsonEncode(
      records.map((key, value) => MapEntry(key, value.toJson())),
    );
    final latestPuzzle = lastPuzzleId;
    final challengeJson =
        challengeSession == null
            ? null
            : jsonEncode(challengeSession!.toJson());
    _saveChain = _saveChain.then(
      (_) => Future.wait([
        _preferences.setString('regalia.settings', settingsJson),
        _preferences.setString(
          'regalia.catalogFingerprint',
          _catalogFingerprint,
        ),
        _preferences.setString('regalia.boards', boardsJson),
        _preferences.setString('regalia.records', recordsJson),
        _preferences.setInt(
          'regalia.journeySchemaVersion',
          journeySchemaVersion,
        ),
        _preferences.setStringList(
          'regalia.seenStoryBeats',
          seenStoryBeatIds.toList()..sort(),
        ),
        if (challengeJson == null)
          _preferences.remove('regalia.challengeSession')
        else
          _preferences.setString('regalia.challengeSession', challengeJson),
        if (latestPuzzle != null)
          _preferences.setString('regalia.lastPuzzle', latestPuzzle),
      ]),
    );
    return _saveChain;
  }

  Future<void> flushPersistence() => _saveChain;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activePuzzleId != null) {
      startTimer(_activePuzzleId!);
    } else if (state != AppLifecycleState.resumed) {
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
