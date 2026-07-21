import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/app_controller.dart';
import 'package:regalia/content/content_ids.dart';
import 'package:regalia/content/content_models.dart';
import 'package:regalia/content/entitlements.dart';
import 'package:regalia/main.dart';
import 'package:regalia/screens/home_screen.dart';
import 'package:regalia/screens/story_scene_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web boots every story and opens the final portfolio arc', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SaveIds.tutorialComplete: true,
      'regalia.journeySchemaVersion': 1,
      SaveIds.originSeenScenes: [
        ContentIds.originOpeningScene,
        'regalia:scene/origin/clovermead',
      ],
    });
    final controller = AppController(
      contentPolicy: const ContentEntitlementPolicy.web(),
      // Browser widget tests do not provide Flutter's generated binary asset
      // manifest, so read the declared fixtures directly from the test bundle.
      contentAssetReader: rootBundle.loadString,
    );
    await tester.runAsync(controller.initialize);
    addTearDown(controller.dispose);

    expect(controller.availableStoryArcs, hasLength(11));
    const arcId = 'regalia:arc/steal-the-seventh-tide';
    expect(
      controller.availabilityForArc(arcId).status,
      ContentAvailabilityStatus.available,
    );

    await tester.pumpWidget(RegaliaApp(controller: controller));
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);

    final tile = find.byKey(const ValueKey('story-arc-tile-$arcId'));
    await tester.scrollUntilVisible(
      tile,
      320,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('home-content-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(tile),
      alignment: .5,
      duration: Duration.zero,
    );
    await tester.pump();
    expect(tile, findsOneWidget);
    expect(find.text('Steal the Seventh Tide'), findsOneWidget);
    expect(find.byKey(const ValueKey('locked-story-$arcId')), findsNothing);

    await tester.tap(tile);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(StorySceneScreen), findsOneWidget);
    expect(find.text('An Ocean One Tide Short'), findsOneWidget);
  });
}
