import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/core/models.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/bestiary_screen.dart';
import 'package:regalia/widgets/combat_presentation.dart';
import 'package:regalia/widgets/pixel_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home shows collection count and opens the bestiary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    controller.records[arc.chapters.first.encounters.first.puzzleId] =
        const CompletionRecord(status: CompletionStatus.assistedSolved);

    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    final tile = find.byKey(const ValueKey('open-bestiary-home'));
    await tester.scrollUntilVisible(
      tile,
      240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home-content-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.byKey(const ValueKey('home-bestiary-progress')),
      findsOneWidget,
    );
    expect(find.text('1 of 24 foes defeated'), findsOneWidget);

    await tester.tap(tile);
    await _pumpRoute(tester);
    expect(find.byType(BestiaryScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bestiary-total-progress')),
      findsOneWidget,
    );
    expect(find.text('1 / 24 foes revealed'), findsOneWidget);
  });

  testWidgets('undiscovered slots do not expose foe names or assets', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final encounter = arc.chapters.first.encounters.first;
    final semantics = tester.ensureSemantics();

    await _pumpBestiary(tester, controller, const Size(390, 844));

    const slotKey = ValueKey('bestiary-slot-regalia:arc/origin-0-0');
    final slot = find.byKey(slotKey);
    expect(slot, findsOneWidget);
    expect(find.text(encounter.name), findsNothing);
    expect(find.byKey(ValueKey(encounter.spriteAsset)), findsNothing);
    expect(
      find.byKey(ValueKey('bestiary-thumbnail-${encounter.id}')),
      findsNothing,
    );
    expect(
      tester.getSemantics(slot).label,
      'Undiscovered foe. Defeat this story encounter to reveal it.',
    );
    expect(find.bySemanticsLabel(RegExp(encounter.name)), findsNothing);
    semantics.dispose();
  });

  testWidgets('clean and assisted victories reveal their exact foes', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final first = arc.chapters.first.encounters.first;
    final second = arc.chapters.first.encounters.last;
    controller.records[first.puzzleId] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
    controller.records[second.puzzleId] = const CompletionRecord(
      status: CompletionStatus.assistedSolved,
    );

    await _pumpBestiary(tester, controller, const Size(390, 844));

    expect(find.text(first.name), findsOneWidget);
    expect(find.text(second.name), findsOneWidget);
    expect(
      find.byKey(ValueKey('bestiary-thumbnail-${first.id}')),
      findsOneWidget,
    );
    expect(find.text(arc.chapters.first.boss.name), findsNothing);
    expect(find.text('2 / 24 foes revealed'), findsOneWidget);
  });

  testWidgets('detail replays all six direct reactions and repeats a row', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final encounter = arc.chapters.first.encounters.first;
    controller.records[encounter.puzzleId] = const CompletionRecord(
      status: CompletionStatus.cleanSolved,
    );
    await _pumpBestiary(tester, controller, const Size(600, 900));

    final entry = find.byKey(ValueKey('open-bestiary-foe-${encounter.id}'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await _pumpRoute(tester);
    expect(find.byType(BestiaryFoeScreen), findsOneWidget);

    var expectedToken = 0;
    for (final reaction in EnemyReaction.values) {
      final button = find.byKey(ValueKey('bestiary-reaction-${reaction.name}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expectedToken++;
      final sprite = tester.widget<PixelEnemySprite>(
        find.byKey(const ValueKey('bestiary-replay-sprite')),
      );
      expect(sprite.resolvedReaction, reaction);
      expect(sprite.restartToken, expectedToken);
      expect(find.text(reaction.label), findsOneWidget);
    }

    final defeat = find.byKey(const ValueKey('bestiary-reaction-defeated'));
    await tester.tap(defeat);
    await tester.pump();
    final replayed = tester.widget<PixelEnemySprite>(
      find.byKey(const ValueKey('bestiary-replay-sprite')),
    );
    expect(replayed.resolvedReaction, EnemyReaction.defeated);
    expect(replayed.restartToken, expectedToken + 1);
  });

  testWidgets('one-shot reactions resume idle while defeat holds', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final chapter = controller.originArc!.chapters.first;
    final encounter = chapter.encounters.first;
    await _pumpApp(
      tester,
      size: const Size(600, 900),
      home: BestiaryFoeScreen(encounter: encounter, chapter: chapter),
      disableAnimations: false,
    );

    PixelEnemySprite sprite() => tester.widget<PixelEnemySprite>(
      find.byKey(const ValueKey('bestiary-replay-sprite')),
    );

    expect(sprite().resolvedReaction, EnemyReaction.idle);
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-0')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-1')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-staggered')));
    await tester.pump();
    expect(sprite().resolvedReaction, EnemyReaction.staggered);
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-staggered-0')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 540));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-staggered-3')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 181));
    expect(sprite().resolvedReaction, EnemyReaction.idle);
    expect(find.text(EnemyReaction.idle.label), findsOneWidget);
    expect(
      tester.widget(find.byKey(const ValueKey('bestiary-reaction-idle'))),
      isA<FilledButton>(),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-pressing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-pressing')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 361));
    expect(sprite().resolvedReaction, EnemyReaction.pressing);
    await tester.pump(const Duration(milliseconds: 360));
    expect(sprite().resolvedReaction, EnemyReaction.idle);

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-defeated')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 721));
    expect(sprite().resolvedReaction, EnemyReaction.defeated);
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-defeated-3')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(sprite().resolvedReaction, EnemyReaction.defeated);
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-defeated-3')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-idle')));
    await tester.pump();
    expect(sprite().resolvedReaction, EnemyReaction.idle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-defeated')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 721));
    expect(sprite().resolvedReaction, EnemyReaction.defeated);

    await tester.tap(find.byKey(const ValueKey('bestiary-reaction-striking')));
    await tester.pump();
    expect(sprite().resolvedReaction, EnemyReaction.striking);
    await tester.pump(const Duration(milliseconds: 721));
    expect(sprite().resolvedReaction, EnemyReaction.idle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(const ValueKey('enemy-atlas-frame-idle-1')),
      findsOneWidget,
    );
  });

  testWidgets('chapter collection reflows at the screen breakpoint', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final arc = controller.originArc!;
    final first = find.byKey(
      ValueKey('bestiary-chapter-${arc.chapters[0].id}'),
    );
    final second = find.byKey(
      ValueKey('bestiary-chapter-${arc.chapters[1].id}'),
    );

    await _pumpBestiary(tester, controller, const Size(390, 844));
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getBottomLeft(first).dy),
    );

    await _pumpBestiary(tester, controller, const Size(600, 900));
    expect(
      tester.getTopLeft(second).dy,
      closeTo(tester.getTopLeft(first).dy, 0.1),
    );
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopRight(first).dx),
    );
  });

  testWidgets('paid story accents stay readable on the shared Bestiary theme', (
    tester,
  ) async {
    final controller = await _paidController(tester);
    addTearDown(controller.dispose);
    final arc = controller.content!.arc('regalia:arc/atlas-of-borrowed-winds')!;

    await _pumpBestiary(tester, controller, const Size(600, 6000));
    final surface = RegaliaTheme.midnight().colorScheme.surface;
    for (final chapter in arc.chapters) {
      final panel = find.byKey(ValueKey('bestiary-chapter-${chapter.id}'));
      expect(panel, findsOneWidget);
      final expected = RegaliaTheme.readableAccent(
        preferred: chapter.palette.secondary,
        background: surface,
      );
      expect(tester.widget<PixelPanel>(panel).borderColor, expected);
      final progress = find.descendant(
        of: panel,
        matching: find.text('0/${chapter.encounters.length + 1}'),
      );
      expect(tester.widget<Text>(progress).style?.color, expected);
    }
  });

  testWidgets('narrow scaled detail remains scrollable without overflow', (
    tester,
  ) async {
    final controller = await _controller(tester);
    addTearDown(controller.dispose);
    final chapter = controller.originArc!.chapters.last;
    await _pumpApp(
      tester,
      size: const Size(320, 568),
      textScaleFactor: 1.5,
      home: BestiaryFoeScreen(encounter: chapter.boss, chapter: chapter),
    );

    expect(
      find.byKey(const ValueKey('bestiary-reaction-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bestiary-reaction-controls')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bestiary-foe-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<AppController> _controller(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = AppController();
  await tester.runAsync(controller.initialize);
  return controller;
}

Future<AppController> _paidController(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    SaveIds.tutorialComplete: true,
    'regalia.journeySchemaVersion': 1,
  });
  final controller = AppController(
    contentAssetReader: (path) => File(path).readAsString(),
    contentAssetExists: (path) => File(path).exists(),
    contentPolicy: const ContentEntitlementPolicy.paidPlatform(),
  );
  await tester.runAsync(controller.initialize);
  return controller;
}

Future<void> _pumpBestiary(
  WidgetTester tester,
  AppController controller,
  Size size,
) => _pumpApp(tester, size: size, home: BestiaryScreen(controller: controller));

Future<void> _pumpApp(
  WidgetTester tester, {
  required Size size,
  required Widget home,
  double textScaleFactor = 1,
  bool disableAnimations = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RegaliaTheme.midnight(),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        );
      },
      home: home,
    ),
  );
  await tester.pump();
}

Future<void> _pumpRoute(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
