import 'dart:convert';

enum DifficultyTier { easy, medium, hard, expert }

extension DifficultyTierLabel on DifficultyTier {
  String get label => name[0].toUpperCase() + name.substring(1);
  int get bandStart => index * 25;

  static DifficultyTier parse(String value) => DifficultyTier.values.firstWhere(
    (tier) => tier.name == value.toLowerCase(),
    orElse: () => throw FormatException('Unknown difficulty tier: $value'),
  );
}

class Cell implements Comparable<Cell> {
  const Cell(this.row, this.column);

  final int row;
  final int column;

  int index(int size) => row * size + column;

  factory Cell.fromIndex(int index, int size) =>
      Cell(index ~/ size, index % size);

  @override
  int compareTo(Cell other) =>
      row != other.row
          ? row.compareTo(other.row)
          : column.compareTo(other.column);

  @override
  bool operator ==(Object other) =>
      other is Cell && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => '${String.fromCharCode(65 + column)}${row + 1}';
}

class PuzzleDefinition {
  PuzzleDefinition({
    required this.id,
    required this.order,
    required this.size,
    required this.tier,
    required List<int> regions,
    required this.schemaVersion,
    required this.contentHash,
    this.difficultyScore = 0,
    this.scoringModel = 'human-v3',
  }) : regions = List.unmodifiable(regions) {
    validateShape();
  }

  final String id;
  final int order;
  final int size;
  final DifficultyTier tier;
  final List<int> regions;
  final int schemaVersion;
  final String contentHash;
  final int difficultyScore;
  final String scoringModel;

  int regionAt(Cell cell) => regions[cell.index(size)];

  Iterable<Cell> get cells sync* {
    for (var index = 0; index < size * size; index++) {
      yield Cell.fromIndex(index, size);
    }
  }

  void validateShape() {
    if (size < 4 || regions.length != size * size) {
      throw FormatException('$id must contain a square region grid');
    }
    final ids = regions.toSet();
    if (ids.length != size || !ids.containsAll(List.generate(size, (i) => i))) {
      throw FormatException(
        '$id must contain region IDs 0 through ${size - 1}',
      );
    }
    if (difficultyScore < tier.bandStart ||
        difficultyScore > tier.bandStart + 24) {
      throw FormatException(
        '$id score $difficultyScore is outside the ${tier.label} band',
      );
    }
  }

  factory PuzzleDefinition.fromJson(Map<String, Object?> json) {
    final rows = (json['regions'] as List<Object?>);
    final flattened =
        rows
            .expand((row) => (row as List<Object?>).cast<num>())
            .map((v) => v.toInt())
            .toList();
    return PuzzleDefinition(
      id: json['id']! as String,
      order: (json['order']! as num).toInt(),
      size: (json['size']! as num).toInt(),
      tier: DifficultyTierLabel.parse(json['tier']! as String),
      regions: flattened,
      schemaVersion: (json['schemaVersion']! as num).toInt(),
      contentHash: json['contentHash']! as String,
      difficultyScore: (json['difficultyScore']! as num).toInt(),
      scoringModel: json['scoringModel']! as String,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'order': order,
    'size': size,
    'tier': tier.name,
    'regions': List.generate(
      size,
      (row) => regions.sublist(row * size, (row + 1) * size),
    ),
    'schemaVersion': schemaVersion,
    'contentHash': contentHash,
    'difficultyScore': difficultyScore,
    'scoringModel': scoringModel,
  };

  static String stableHash(int size, List<int> regions) {
    // Portable FNV-1a. The hash is integrity metadata, not a security boundary.
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('$size:${regions.join(',')}')) {
      hash ^= byte;
      // 0x01000193 = 0x193 + 0x01000000. Splitting the product
      // keeps every intermediate exactly representable when compiled to JS.
      hash = ((hash * 0x193) + ((hash << 24) & 0xffffffff)) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class PuzzleCatalog {
  PuzzleCatalog({
    required this.schemaVersion,
    required this.scoringModel,
    required List<PuzzleDefinition> puzzles,
  }) : puzzles = List.unmodifiable(puzzles);

  final int schemaVersion;
  final String scoringModel;
  final List<PuzzleDefinition> puzzles;

  PuzzleDefinition byId(String id) =>
      puzzles.firstWhere((puzzle) => puzzle.id == id);

  factory PuzzleCatalog.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final catalog = PuzzleCatalog(
      schemaVersion: (json['schemaVersion']! as num).toInt(),
      scoringModel: json['scoringModel']! as String,
      puzzles:
          (json['puzzles']! as List<Object?>)
              .map(
                (entry) =>
                    PuzzleDefinition.fromJson(entry! as Map<String, Object?>),
              )
              .toList(),
    );
    catalog.validateSchema();
    return catalog;
  }

  void validateSchema() {
    final ids = <String>{};
    for (final puzzle in puzzles) {
      if (puzzle.schemaVersion != schemaVersion ||
          puzzle.scoringModel != scoringModel) {
        throw FormatException(
          '${puzzle.id} uses incompatible catalog metadata',
        );
      }
      if (!ids.add(puzzle.id)) {
        throw FormatException('Duplicate puzzle ID ${puzzle.id}');
      }
      if (PuzzleDefinition.stableHash(puzzle.size, puzzle.regions) !=
          puzzle.contentHash) {
        throw FormatException('${puzzle.id} has an invalid content hash');
      }
    }
  }
}

enum ManualCellState { empty, cross, crown }

enum CompletionStatus { newPuzzle, inProgress, assistedSolved, cleanSolved }

class CompletionRecord {
  const CompletionRecord({
    this.status = CompletionStatus.newPuzzle,
    this.bestCleanSeconds,
    this.bestAssistedSeconds,
    this.attemptCount = 0,
  });

  final CompletionStatus status;
  final int? bestCleanSeconds;
  final int? bestAssistedSeconds;
  final int attemptCount;

  CompletionRecord complete({required bool assisted, required int seconds}) {
    if (!assisted) {
      return CompletionRecord(
        status: CompletionStatus.cleanSolved,
        bestCleanSeconds:
            bestCleanSeconds == null
                ? seconds
                : (seconds < bestCleanSeconds! ? seconds : bestCleanSeconds),
        bestAssistedSeconds: bestAssistedSeconds,
        attemptCount: attemptCount,
      );
    }
    return CompletionRecord(
      status:
          status == CompletionStatus.cleanSolved
              ? status
              : CompletionStatus.assistedSolved,
      bestCleanSeconds: bestCleanSeconds,
      bestAssistedSeconds:
          bestAssistedSeconds == null
              ? seconds
              : (seconds < bestAssistedSeconds!
                  ? seconds
                  : bestAssistedSeconds),
      attemptCount: attemptCount,
    );
  }

  Map<String, Object?> toJson() => {
    'status': status.name,
    'bestCleanSeconds': bestCleanSeconds,
    'bestAssistedSeconds': bestAssistedSeconds,
    'attemptCount': attemptCount,
  };

  factory CompletionRecord.fromJson(Map<String, Object?> json) {
    final rawStatus = json['status'];
    final status =
        rawStatus is num
            ? CompletionStatus.values[rawStatus.toInt().clamp(
              0,
              CompletionStatus.values.length - 1,
            )]
            : CompletionStatus.values.firstWhere(
              (value) => value.name == rawStatus,
              orElse: () => CompletionStatus.newPuzzle,
            );
    return CompletionRecord(
      status: status,
      bestCleanSeconds: (json['bestCleanSeconds'] as num?)?.toInt(),
      bestAssistedSeconds: (json['bestAssistedSeconds'] as num?)?.toInt(),
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BoardSnapshot {
  const BoardSnapshot(this.cells);
  final List<ManualCellState> cells;
}

class BoardState {
  BoardState({
    required this.puzzleId,
    required this.size,
    List<ManualCellState>? cells,
    this.elapsedSeconds = 0,
    this.hintCount = 0,
    this.checkCount = 0,
    this.assisted = false,
  }) : cells = List.of(
         cells ?? List.filled(size * size, ManualCellState.empty),
       );

  final String puzzleId;
  final int size;
  final List<ManualCellState> cells;
  int elapsedSeconds;
  int hintCount;
  int checkCount;
  bool assisted;
  final List<BoardSnapshot> undoStack = [];
  final List<BoardSnapshot> redoStack = [];
  BoardSnapshot? _batchStart;

  ManualCellState at(Cell cell) => cells[cell.index(size)];

  void set(Cell cell, ManualCellState value, {bool recordUndo = true}) {
    if (at(cell) == value) return;
    if (recordUndo && _batchStart == null) {
      undoStack.add(BoardSnapshot(List.of(cells)));
      redoStack.clear();
    }
    cells[cell.index(size)] = value;
  }

  void beginBatch() {
    _batchStart ??= BoardSnapshot(List.of(cells));
  }

  bool endBatch() {
    final start = _batchStart;
    _batchStart = null;
    if (start == null || _sameCells(start.cells, cells)) return false;
    undoStack.add(start);
    redoStack.clear();
    return true;
  }

  void cycle(Cell cell) {
    final next =
        ManualCellState.values[(at(cell).index + 1) %
            ManualCellState.values.length];
    set(cell, next);
  }

  bool undo() {
    if (undoStack.isEmpty) return false;
    redoStack.add(BoardSnapshot(List.of(cells)));
    cells.setAll(0, undoStack.removeLast().cells);
    return true;
  }

  bool redo() {
    if (redoStack.isEmpty) return false;
    undoStack.add(BoardSnapshot(List.of(cells)));
    cells.setAll(0, redoStack.removeLast().cells);
    return true;
  }

  bool _sameCells(List<ManualCellState> first, List<ManualCellState> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void reset() {
    if (cells.every((cell) => cell == ManualCellState.empty)) return;
    undoStack.add(BoardSnapshot(List.of(cells)));
    redoStack.clear();
    cells.fillRange(0, cells.length, ManualCellState.empty);
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 2,
    'puzzleId': puzzleId,
    'size': size,
    'cells': cells.map((cell) => cell.name).toList(),
    'elapsedSeconds': elapsedSeconds,
    'hintCount': hintCount,
    'checkCount': checkCount,
    'assisted': assisted,
  };

  factory BoardState.fromJson(Map<String, Object?> json) {
    final size = (json['size']! as num).toInt();
    final rawCells = (json['cells'] as List<Object?>?) ?? const [];
    if (size < 1 || rawCells.length != size * size) {
      throw const FormatException('Saved board has an invalid shape');
    }
    final cells =
        rawCells.map((value) {
          if (value is num) {
            return ManualCellState.values[value.toInt()]; // v1 migration.
          }
          return ManualCellState.values.firstWhere(
            (state) => state.name == value,
          );
        }).toList();
    return BoardState(
      puzzleId: json['puzzleId']! as String,
      size: size,
      cells: cells,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      hintCount: (json['hintCount'] as num?)?.toInt() ?? 0,
      checkCount: (json['checkCount'] as num?)?.toInt() ?? 0,
      assisted: json['assisted'] as bool? ?? false,
    );
  }
}
