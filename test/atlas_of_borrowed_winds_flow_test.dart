import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/exact_solver.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/widgets/cinematic_scene.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const atlasArcId = 'regalia:arc/atlas-of-borrowed-winds';

  testWidgets('Atlas final boss unlocks its own finale map art and ensemble', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'regalia.tutorialComplete': true,
      'regalia.journeySchemaVersion': 1,
    });
    final controller = AppController(
      contentPolicy: const ContentEntitlementPolicy.paidPlatform(),
      contentAssetReader: (path) => File(path).readAsString(),
    );
    await tester.runAsync(controller.initialize);
    final arc = controller.content!.arc(atlasArcId)!;
    await controller.markStoryBeatSeen(arc.openingScene.id);
    for (final chapter in arc.chapters) {
      await controller.markStoryBeatSeen(chapter.storyBeatId);
    }
    await controller.unlockEntireMap(arc.id);

    final finalBoss = arc.catalog.byId(arc.chapters.last.boss.puzzleId);
    expect(finalBoss.size, 12);
    expect(controller.openPuzzle(finalBoss), isTrue);
    final solution =
        const ExactSolver().solve(finalBoss, limit: 1).solutions.single;
    PuzzleCompletionOutcome? outcome;
    for (final cell in solution) {
      outcome =
          controller.setCell(finalBoss, cell, ManualCellState.crown) ?? outcome;
    }
    expect(outcome, isNotNull);
    expect(outcome!.advancedJourney, isFalse);
    expect(controller.isFinaleUnlocked(arc.id), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: JourneyScreen(controller: controller, arc: arc),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey('final-landmark-cinematic-frame')),
      findsOneWidget,
    );
    expect(find.byType(CinematicSceneFrameView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cinematic-character-nahla')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cinematic-character-ilyun')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cinematic-character-samir')),
      findsOneWidget,
    );
    expect(find.byType(PixelQueenSprite), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith(
              'atlas-of-borrowed-winds/backgrounds/finale_dawn.jpg',
            ),
      ),
      findsOneWidget,
    );

    final finaleLandmark = find.byKey(const ValueKey('final-landmark'));
    final journeyScrollable = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      finaleLandmark,
      500,
      scrollable: journeyScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(finaleLandmark);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'story-page-regalia:scene/atlas-of-borrowed-winds/finale-0',
        ),
      ),
      findsOneWidget,
    );

    await tester.runAsync(controller.flushPersistence);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();

    final restored = AppController(
      contentPolicy: const ContentEntitlementPolicy.paidPlatform(),
      contentAssetReader: (path) => File(path).readAsString(),
    );
    await tester.runAsync(restored.initialize);
    addTearDown(restored.dispose);
    final restoredArc = restored.content!.arc(atlasArcId)!;
    expect(restored.isFinaleUnlocked(restoredArc.id), isTrue);
    expect(
      restored.recordFor(finalBoss.id).status,
      CompletionStatus.cleanSolved,
    );
  });
}
