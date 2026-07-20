import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/bestiary.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('origin bestiary follows arc, chapter, and puzzle order', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final progress = BestiaryArcProgress.derive(
      arc: controller.originArc!,
      recordFor: controller.recordFor,
    );

    expect(progress.chapters, hasLength(8));
    expect(progress.totalCount, 24);
    expect(progress.defeatedCount, 0);
    for (final chapter in progress.chapters) {
      expect(chapter.foes, hasLength(3));
      expect(
        chapter.foes.map((foe) => foe.puzzleOrder).toList(),
        orderedEquals([
          chapter.chapter.startOrder + 2,
          chapter.chapter.startOrder + 5,
          chapter.chapter.endOrder,
        ]),
      );
      expect(chapter.foes.last.encounter.isBoss, isTrue);
    }
  });

  test('only durable solved records reveal foes', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final encounters = [
      arc.chapters.first.encounters.first,
      arc.chapters.first.encounters.last,
      arc.chapters.first.boss,
    ];
    controller.records[encounters[0].puzzleId] = const CompletionRecord(
      status: CompletionStatus.inProgress,
    );
    controller.records[encounters[1].puzzleId] = const CompletionRecord(
      status: CompletionStatus.assistedSolved,
    );
    controller.records[encounters[2].puzzleId] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );

    final progress = BestiaryArcProgress.derive(
      arc: arc,
      recordFor: controller.recordFor,
    );
    expect(progress.defeatedCount, 2);
    expect(progress.chapters.first.foes.map((foe) => foe.defeated), [
      false,
      true,
      true,
    ]);
  });

  test(
    'map unlock does not reveal foes and arc reset removes discoveries',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      final arc = controller.originArc!;
      final encounter = arc.chapters.first.encounters.first;

      await controller.unlockEntireMap(ContentIds.originArc);
      expect(
        BestiaryArcProgress.derive(
          arc: arc,
          recordFor: controller.recordFor,
        ).defeatedCount,
        0,
      );

      controller.records[encounter.puzzleId] = const CompletionRecord(
        status: CompletionStatus.cleanSolved,
      );
      expect(
        BestiaryArcProgress.derive(
          arc: arc,
          recordFor: controller.recordFor,
        ).defeatedCount,
        1,
      );

      await controller.resetStoryArc(arc.id);
      expect(
        BestiaryArcProgress.derive(
          arc: arc,
          recordFor: controller.recordFor,
        ).defeatedCount,
        0,
      );
    },
  );

  test('an active replay cannot hide an already defeated foe', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final encounter = arc.chapters.first.encounters.first;
    final puzzle = arc.catalog.byId(encounter.puzzleId);
    controller.records[puzzle.id] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );

    expect(controller.openPuzzle(puzzle), isTrue);
    controller.setCell(puzzle, const Cell(0, 0), ManualCellState.cross);
    expect(controller.statusFor(puzzle), CompletionStatus.inProgress);

    final entry =
        BestiaryArcProgress.derive(
          arc: arc,
          recordFor: controller.recordFor,
        ).chapters.first.foes.first;
    expect(entry.encounter.id, encounter.id);
    expect(entry.defeated, isTrue);
  });
}

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = AppController();
  await controller.initialize();
  return controller;
}
