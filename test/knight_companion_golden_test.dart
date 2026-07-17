@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/theme.dart';
import 'package:regalia/screens/game_screen.dart';
import 'package:regalia/widgets/pixel_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('RegaliaPixel')..addFont(
      rootBundle.load('assets/fonts/PixelifySans-Variable.ttf'),
    )).load();
    await PixelKnightSprite.preload();
  });

  testWidgets('puzzle companion attacks in the narrow play layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'regalia.tutorialComplete': true});
    final controller = _TimerlessController();
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);
    final puzzle = controller.catalog!.puzzles.first;
    expect(controller.openPuzzle(puzzle), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        theme: RegaliaTheme.midnight(),
        home: RepaintBoundary(
          key: const ValueKey('knight-companion-golden'),
          child: GameScreen(controller: controller, puzzle: puzzle),
        ),
      ),
    );
    await tester.pump();
    final cell = find.byKey(const ValueKey('cell-0-0'));
    await tester.tap(cell);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 260));

    await expectLater(
      find.byKey(const ValueKey('knight-companion-golden')),
      matchesGoldenFile('goldens/knight_companion_attack.png'),
    );
    await expectLater(
      find.byKey(const ValueKey('puzzle-knight-companion-surface')),
      matchesGoldenFile('goldens/knight_companion_attack_bar.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TimerlessController extends AppController {
  @override
  void startTimer(String puzzleId) {}

  @override
  void stopTimer() {}
}
