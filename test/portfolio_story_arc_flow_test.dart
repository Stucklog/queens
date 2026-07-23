import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _portfolioArcIds = <String>[
  'regalia:arc/sun-sail-covenant',
  'regalia:arc/where-the-rain-trees-walk',
  'regalia:arc/oathstorm-fleet',
  'regalia:arc/crimson-ledger',
  'regalia:arc/atlas-of-borrowed-winds',
  'regalia:arc/treaty-written-in-thorns',
  'regalia:arc/inn-at-the-end-of-yesterday',
  'regalia:arc/ninth-library',
  'regalia:arc/shepherds-of-the-thunderwild',
  'regalia:arc/steal-the-seventh-tide',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every portfolio final boss independently unlocks and restores its finale',
    () async {
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
      });
      final controller = _controller();
      await controller.initialize();

      for (final arcId in _portfolioArcIds) {
        final arc = controller.content!.arc(arcId);
        expect(arc, isNotNull, reason: arcId);
        if (arc == null) continue;
        await controller.unlockEntireMap(arc.id);
        final finalBoss = arc.catalog.byId(arc.chapters.last.boss.puzzleId);
        expect(finalBoss.size, 12, reason: arcId);
        expect(controller.openPuzzle(finalBoss), isTrue, reason: arcId);
        final solution =
            const ExactSolver().solve(finalBoss, limit: 1).solutions.single;
        PuzzleCompletionOutcome? outcome;
        for (final cell in solution) {
          outcome =
              controller.setCell(finalBoss, cell, ManualCellState.crown) ??
              outcome;
        }
        expect(outcome, isNotNull, reason: arcId);
        expect(outcome!.puzzle.id, finalBoss.id, reason: arcId);
        expect(controller.isFinaleUnlocked(arc.id), isTrue, reason: arcId);
      }

      await controller.flushPersistence();
      controller.dispose();

      final restored = _controller();
      await restored.initialize();
      addTearDown(restored.dispose);
      for (final arcId in _portfolioArcIds) {
        final arc = restored.content!.arc(arcId);
        expect(arc, isNotNull, reason: arcId);
        if (arc == null) continue;
        final finalBoss = arc.catalog.byId(arc.chapters.last.boss.puzzleId);
        expect(restored.isFinaleUnlocked(arc.id), isTrue, reason: arcId);
        expect(
          restored.recordFor(finalBoss.id).status,
          CompletionStatus.cleanSolved,
          reason: arcId,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

AppController _controller() => AppController(
  contentPolicy: const ContentEntitlementPolicy.paidPlatform(),
  contentAssetReader: (path) => File(path).readAsString(),
);
