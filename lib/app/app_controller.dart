import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/human_solver.dart';
import '../core/models.dart';
import '../core/rule_engine.dart';

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
  });

  final RuleEngine ruleEngine;
  final HumanSolver humanSolver;
  late final SharedPreferences _preferences;
  PuzzleCatalog? catalog;
  PuzzleDefinition? tutorialPuzzle;
  AppSettings settings = const AppSettings();
  final Map<String, BoardState> boards = {};
  final Map<String, CompletionRecord> records = {};
  bool tutorialComplete = false;
  String? lastPuzzleId;
  Timer? _timer;
  String? _activePuzzleId;
  Future<void> _saveChain = Future.value();

  bool get isReady => catalog != null;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final source = await rootBundle.loadString('assets/puzzles/catalog.json');
    final tutorialSource = await rootBundle.loadString(
      'assets/puzzles/tutorial.json',
    );
    catalog = PuzzleCatalog.fromJsonString(source);
    tutorialPuzzle = PuzzleDefinition.fromJson(
      jsonDecode(tutorialSource) as Map<String, Object?>,
    );
    _preferences = await SharedPreferences.getInstance();
    settings =
        _decode('regalia.settings', AppSettings.fromJson) ??
        const AppSettings();
    tutorialComplete =
        _preferences.getBool('regalia.tutorialComplete') ?? false;
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
    notifyListeners();
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

  BoardState boardFor(PuzzleDefinition puzzle) => boards.putIfAbsent(
    puzzle.id,
    () => BoardState(puzzleId: puzzle.id, size: puzzle.size),
  );

  CompletionRecord recordFor(String id) =>
      records[id] ?? const CompletionRecord();

  CompletionStatus statusFor(PuzzleDefinition puzzle) =>
      hasActiveBoard(puzzle)
          ? CompletionStatus.inProgress
          : recordFor(puzzle.id).status;

  PuzzleDefinition recommendedPuzzle() {
    final puzzles = catalog!.puzzles;
    if (lastPuzzleId != null) {
      final board = boards[lastPuzzleId!];
      final puzzle = catalog!.byId(lastPuzzleId!);
      if (board != null && hasActiveBoard(puzzle)) {
        return puzzle;
      }
    }
    return puzzles.firstWhere(
      (puzzle) => recordFor(puzzle.id).status == CompletionStatus.newPuzzle,
      orElse:
          () => puzzles.firstWhere(
            (puzzle) =>
                recordFor(puzzle.id).status == CompletionStatus.assistedSolved,
            orElse: () => puzzles.first,
          ),
    );
  }

  bool hasActiveBoard(PuzzleDefinition puzzle) {
    final board = boards[puzzle.id];
    return board != null &&
        board.cells.any((cell) => cell != ManualCellState.empty) &&
        !ruleEngine.isComplete(puzzle, board);
  }

  void openPuzzle(PuzzleDefinition puzzle) {
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
        return;
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
  }

  bool cycle(PuzzleDefinition puzzle, Cell cell) {
    final board = boardFor(puzzle)..cycle(cell);
    final completed = _recordCompletionIfNeeded(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return completed;
  }

  bool setCell(PuzzleDefinition puzzle, Cell cell, ManualCellState state) {
    final board = boardFor(puzzle)..set(cell, state);
    final completed = _recordCompletionIfNeeded(puzzle, board);
    unawaited(_save());
    notifyListeners();
    return completed;
  }

  bool _recordCompletionIfNeeded(PuzzleDefinition puzzle, BoardState board) {
    if (!ruleEngine.isComplete(puzzle, board)) return false;
    records[puzzle.id] = recordFor(
      puzzle.id,
    ).complete(assisted: board.assisted, seconds: board.elapsedSeconds);
    stopTimer();
    return true;
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
      final board = boards[puzzleId];
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
    _saveChain = _saveChain.then(
      (_) => Future.wait([
        _preferences.setString('regalia.settings', settingsJson),
        _preferences.setString('regalia.boards', boardsJson),
        _preferences.setString('regalia.records', recordsJson),
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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
