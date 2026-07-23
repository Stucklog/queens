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

  test('every bundled chapter declares one Origin-style 3x3 grid', () async {
    final manifest =
        jsonDecode(await File('assets/content/manifest.json').readAsString())
            as Map<String, Object?>;
    final descriptors = manifest['arcs']! as List<Object?>;

    expect(descriptors, hasLength(11));
    for (final descriptorValue in descriptors) {
      final descriptor = descriptorValue! as Map<String, Object?>;
      final arcId = descriptor['arcId']! as String;
      final metadata =
          jsonDecode(
                await File(
                  descriptor['metadataAsset']! as String,
                ).readAsString(),
              )
              as Map<String, Object?>;
      final chapters = metadata['chapters']! as List<Object?>;

      expect(chapters, hasLength(8), reason: arcId);
      for (final value in chapters) {
        final chapter = value! as Map<String, Object?>;
        final startOrder = chapter['startOrder']! as int;
        final endOrder = chapter['endOrder']! as int;
        final layout = JourneyMapLayout.fromJson(chapter['mapLayout']);
        expect(endOrder - startOrder + 1, 9, reason: chapter['id']! as String);
        expect(layout.columns, 3, reason: chapter['id']! as String);
        expect(
          layout.pattern,
          JourneyRoutePattern.snake,
          reason: chapter['id']! as String,
        );
        expect(
          layout.direction,
          JourneyRouteDirection.leftToRight,
          reason: chapter['id']! as String,
        );
      }
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
