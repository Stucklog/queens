import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/app/journey.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/journey_screen.dart';
import 'package:regalia/screens/settings_screen.dart';
import 'package:regalia/widgets/pixel_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'legacy light preference cannot override midnight or expose appearance controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'regalia.tutorialComplete': true,
        'regalia.journeySchemaVersion': 1,
        'regalia.seenStoryBeats': <String>[
          StoryBeatIds.opening,
          journeyChapters.first.storyBeatId,
        ],
        'regalia.settings':
            '{"themeMode":"light","showTimer":false,"showAutomaticExclusions":true,"reducedMotion":true}',
      });
      final controller = AppController();
      await tester.runAsync(controller.initialize);
      addTearDown(controller.dispose);

      await tester.pumpWidget(RegaliaApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(JourneyScreen), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(JourneyScreen))).brightness,
        Brightness.dark,
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('System'), findsNothing);
      expect(find.text('Light'), findsNothing);
      expect(find.text('Dark'), findsNothing);
      expect(find.text('Show timer'), findsOneWidget);
      expect(
        tester
            .widget<PixelToggleTile>(
              find.widgetWithText(PixelToggleTile, 'Show timer'),
            )
            .value,
        isFalse,
      );
    },
  );
}
