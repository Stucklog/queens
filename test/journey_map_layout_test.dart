import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/core/models.dart';

void main() {
  test('map layout defaults preserve the original three-column snake', () {
    final layout = JourneyMapLayout.fromJson(null);

    expect(layout.columns, 3);
    expect(layout.pattern, JourneyRoutePattern.snake);
    expect(layout.direction, JourneyRouteDirection.leftToRight);
  });

  test('map layout parses configurable columns, pattern, and direction', () {
    final layout = JourneyMapLayout.fromJson({
      'columns': 4,
      'pattern': 'rows',
      'direction': 'rightToLeft',
    });

    expect(layout.columns, 4);
    expect(layout.pattern, JourneyRoutePattern.rows);
    expect(layout.direction, JourneyRouteDirection.rightToLeft);
  });

  test('route patterns honor their configured starting direction', () {
    const snake = JourneyMapLayout();
    const reverseSnake = JourneyMapLayout(
      direction: JourneyRouteDirection.rightToLeft,
    );
    const reverseRows = JourneyMapLayout(
      pattern: JourneyRoutePattern.rows,
      direction: JourneyRouteDirection.rightToLeft,
    );

    List<int> row(JourneyMapLayout layout, int row) => [
      for (var logicalColumn = 0; logicalColumn < 3; logicalColumn++)
        layout.displayColumnFor(
          row: row,
          logicalColumn: logicalColumn,
          columnCount: 3,
        ),
    ];

    expect(row(snake, 0), [0, 1, 2]);
    expect(row(snake, 1), [2, 1, 0]);
    expect(row(reverseSnake, 0), [2, 1, 0]);
    expect(row(reverseSnake, 1), [0, 1, 2]);
    expect(row(reverseRows, 0), [2, 1, 0]);
    expect(row(reverseRows, 1), [2, 1, 0]);
  });

  test('map layout rejects invalid authoring values', () {
    expect(
      () => JourneyMapLayout.fromJson({'columns': 0}),
      throwsFormatException,
    );
    expect(
      () => JourneyMapLayout.fromJson({'pattern': 'spiral'}),
      throwsFormatException,
    );
    expect(
      () => JourneyMapLayout.fromJson({'direction': 'up'}),
      throwsFormatException,
    );
  });

  test('Origin declares its route layout in canonical content', () async {
    final metadata =
        jsonDecode(
              await File('assets/content/arcs/origin/arc.json').readAsString(),
            )
            as Map<String, Object?>;
    final chapters = metadata['chapters']! as List<Object?>;

    expect(chapters, hasLength(8));
    for (final value in chapters) {
      final chapter = value! as Map<String, Object?>;
      final layout = JourneyMapLayout.fromJson(chapter['mapLayout']);
      expect(layout.columns, 3);
      expect(layout.pattern, JourneyRoutePattern.snake);
      expect(layout.direction, JourneyRouteDirection.leftToRight);
    }
  });

  test('generated puzzles use a compact story-independent visual palette', () {
    expect(challengeVisualChapters, hasLength(DifficultyTier.values.length));
    expect(
      challengeVisualChapters.map((chapter) => chapter.difficulty),
      orderedEquals(DifficultyTier.values),
    );
    expect(
      challengeVisualChapters.every(
        (chapter) => !chapter.id.contains('/origin/'),
      ),
      isTrue,
    );
  });
}
