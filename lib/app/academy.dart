import 'dart:convert';

import '../core/human_solver.dart';
import '../core/models.dart';

/// A visual, non-playable board state used to explain one deduction.
class AcademyExample {
  AcademyExample({
    required this.size,
    required List<int> regions,
    required Set<Cell> crowns,
    required Set<Cell> crosses,
    required Set<Cell> sources,
    required Set<Cell> targets,
    required this.caption,
  }) : regions = List.unmodifiable(regions),
       crowns = Set.unmodifiable(crowns),
       crosses = Set.unmodifiable(crosses),
       sources = Set.unmodifiable(sources),
       targets = Set.unmodifiable(targets) {
    if (size < 3 || regions.length != size * size) {
      throw const FormatException('Academy example must be a square grid');
    }
    final allCells = {...crowns, ...crosses, ...sources, ...targets};
    if (allCells.any(
      (cell) =>
          cell.row < 0 ||
          cell.column < 0 ||
          cell.row >= size ||
          cell.column >= size,
    )) {
      throw const FormatException('Academy example cell is outside its grid');
    }
  }

  final int size;
  final List<int> regions;
  final Set<Cell> crowns;
  final Set<Cell> crosses;
  final Set<Cell> sources;
  final Set<Cell> targets;
  final String caption;

  int regionAt(Cell cell) => regions[cell.index(size)];

  factory AcademyExample.fromJson(Map<String, Object?> json) {
    final size = (json['size']! as num).toInt();
    final regionRows = json['regions']! as List<Object?>;
    final regions = regionRows
        .expand((row) => (row! as List<Object?>).cast<num>())
        .map((region) => region.toInt())
        .toList(growable: false);
    return AcademyExample(
      size: size,
      regions: regions,
      crowns: _cellsFromJson(json['crowns']),
      crosses: _cellsFromJson(json['crosses']),
      sources: _cellsFromJson(json['sources']),
      targets: _cellsFromJson(json['targets']),
      caption: json['caption']! as String,
    );
  }

  static Set<Cell> _cellsFromJson(Object? value) {
    if (value == null) return const {};
    return (value as List<Object?>).map((raw) {
      final coordinates = raw! as List<Object?>;
      return Cell(
        (coordinates[0]! as num).toInt(),
        (coordinates[1]! as num).toInt(),
      );
    }).toSet();
  }
}

/// One ordered Academy lesson and its isolated practice board.
class AcademyLesson {
  const AcademyLesson({
    required this.id,
    required this.order,
    required this.title,
    required this.technique,
    required this.summary,
    required this.explanation,
    required this.steps,
    required this.example,
    required this.practicePuzzle,
  });

  final String id;
  final int order;
  final String title;
  final DeductionTechnique technique;
  final String summary;
  final String explanation;
  final List<String> steps;
  final AcademyExample example;
  final PuzzleDefinition practicePuzzle;
}

/// Data-driven Academy curriculum loaded from the bundled lesson config.
class AcademyCatalog {
  AcademyCatalog({
    required this.schemaVersion,
    required List<AcademyLesson> lessons,
  }) : lessons = List.unmodifiable(lessons) {
    if (schemaVersion != 1) {
      throw FormatException('Unsupported Academy schema $schemaVersion');
    }
    if (lessons.isEmpty) {
      throw const FormatException('Academy must contain at least one lesson');
    }
    final ids = <String>{};
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      if (lesson.order != index + 1 || !ids.add(lesson.id)) {
        throw const FormatException(
          'Academy lessons must have unique IDs and consecutive order',
        );
      }
    }
  }

  final int schemaVersion;
  final List<AcademyLesson> lessons;

  AcademyLesson? lessonForId(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  AcademyLesson? lessonForPuzzle(PuzzleDefinition puzzle) {
    for (final lesson in lessons) {
      if (lesson.practicePuzzle.id == puzzle.id) return lesson;
    }
    return null;
  }

  factory AcademyCatalog.fromJsonString(
    String source, {
    required PuzzleCatalog sourceCatalog,
  }) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final lessons = <AcademyLesson>[];
    for (final raw in json['lessons']! as List<Object?>) {
      final lessonJson = raw! as Map<String, Object?>;
      final id = lessonJson['id']! as String;
      if (!id.startsWith('regalia:lesson/academy/')) {
        throw FormatException('Invalid Academy lesson ID $id');
      }
      final sourcePuzzle = sourceCatalog.byId(
        lessonJson['sourcePuzzleId']! as String,
      );
      final technique = DeductionTechnique.values.firstWhere(
        (value) => value.name == lessonJson['technique'],
        orElse:
            () =>
                throw FormatException(
                  'Unknown Academy technique ${lessonJson['technique']}',
                ),
      );
      final order = (lessonJson['order']! as num).toInt();
      final localId = id.substring('regalia:lesson/academy/'.length);
      final practicePuzzle = PuzzleDefinition(
        id: 'regalia:puzzle/academy/$localId',
        order: order,
        size: sourcePuzzle.size,
        tier: sourcePuzzle.tier,
        regions: sourcePuzzle.regions,
        schemaVersion: sourcePuzzle.schemaVersion,
        contentHash: sourcePuzzle.contentHash,
        difficultyScore: sourcePuzzle.difficultyScore,
        scoringModel: sourcePuzzle.scoringModel,
      );
      lessons.add(
        AcademyLesson(
          id: id,
          order: order,
          title: lessonJson['title']! as String,
          technique: technique,
          summary: lessonJson['summary']! as String,
          explanation: lessonJson['explanation']! as String,
          steps: List.unmodifiable(
            (lessonJson['steps']! as List<Object?>).cast<String>(),
          ),
          example: AcademyExample.fromJson(
            lessonJson['example']! as Map<String, Object?>,
          ),
          practicePuzzle: practicePuzzle,
        ),
      );
    }
    lessons.sort((first, second) => first.order.compareTo(second.order));
    return AcademyCatalog(
      schemaVersion: (json['schemaVersion']! as num).toInt(),
      lessons: lessons,
    );
  }
}
