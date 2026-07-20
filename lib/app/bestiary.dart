import 'package:flutter/foundation.dart';

import '../content/content_models.dart';
import '../core/models.dart';
import 'journey.dart';

typedef CompletionRecordLookup = CompletionRecord Function(String puzzleId);

/// A story encounter paired with its durable collection state.
@immutable
class BestiaryFoeEntry {
  const BestiaryFoeEntry({
    required this.encounter,
    required this.puzzleOrder,
    required this.defeated,
  });

  final CombatEncounter encounter;
  final int puzzleOrder;
  final bool defeated;
}

/// One chapter's encounters, kept in their story-puzzle order.
@immutable
class BestiaryChapterProgress {
  const BestiaryChapterProgress({required this.chapter, required this.foes});

  final JourneyChapter chapter;
  final List<BestiaryFoeEntry> foes;

  int get defeatedCount => foes.where((foe) => foe.defeated).length;
}

/// Collection progress derived from an arc's existing completion records.
///
/// The bestiary deliberately owns no save data. Resetting an arc therefore
/// removes its discoveries with the same durable records that unlocked them,
/// while a map-only unlock cannot reveal an encounter that was never defeated.
@immutable
class BestiaryArcProgress {
  const BestiaryArcProgress({required this.arc, required this.chapters});

  factory BestiaryArcProgress.derive({
    required StoryArc arc,
    required CompletionRecordLookup recordFor,
  }) {
    final chapters = <BestiaryChapterProgress>[];
    for (final chapter in arc.chapters) {
      final encounters = <CombatEncounter>[...chapter.encounters, chapter.boss]
        ..sort(
          (left, right) => arc.catalog
              .byId(left.puzzleId)
              .order
              .compareTo(arc.catalog.byId(right.puzzleId).order),
        );
      chapters.add(
        BestiaryChapterProgress(
          chapter: chapter,
          foes: List.unmodifiable([
            for (final encounter in encounters)
              BestiaryFoeEntry(
                encounter: encounter,
                puzzleOrder: arc.catalog.byId(encounter.puzzleId).order,
                defeated: isDefeatedRecord(recordFor(encounter.puzzleId)),
              ),
          ]),
        ),
      );
    }
    return BestiaryArcProgress(arc: arc, chapters: List.unmodifiable(chapters));
  }

  final StoryArc arc;
  final List<BestiaryChapterProgress> chapters;

  Iterable<BestiaryFoeEntry> get foes =>
      chapters.expand((chapter) => chapter.foes);

  int get totalCount => foes.length;
  int get defeatedCount => foes.where((foe) => foe.defeated).length;
}

bool isDefeatedRecord(CompletionRecord record) => switch (record.status) {
  CompletionStatus.cleanSolved || CompletionStatus.assistedSolved => true,
  CompletionStatus.newPuzzle || CompletionStatus.inProgress => false,
};
