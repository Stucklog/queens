import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';

class StorySceneScreen extends StatelessWidget {
  const StorySceneScreen({
    super.key,
    required this.controller,
    required this.beatId,
    required this.title,
    required this.caption,
    required this.semanticLabel,
    required this.actionLabel,
    required this.sceneKind,
    this.chapter,
    this.popOnContinue = true,
  });

  factory StorySceneScreen.opening({
    required AppController controller,
    bool popOnContinue = false,
  }) => StorySceneScreen(
    controller: controller,
    beatId: StoryBeatIds.opening,
    title: 'The Night of Crownfall',
    caption:
        'When the Hollow Star steals the dawn, the Queen’s Regalia falls into the hands of an unknown knight.',
    semanticLabel:
        'A lone knight holds the fallen Regalia beside a star-scarred crater as the Hollow Star eclipses the distant Empyrean Citadel.',
    actionLabel: 'Take up the Regalia',
    sceneKind: PixelSceneKind.opening,
    chapter: journeyChapters.first,
    popOnContinue: popOnContinue,
  );

  factory StorySceneScreen.chapter({
    required AppController controller,
    required JourneyChapter chapter,
  }) => StorySceneScreen(
    controller: controller,
    beatId: chapter.storyBeatId,
    title: chapter.title,
    caption: chapter.caption,
    semanticLabel:
        'The Regalia bearer enters ${chapter.title} beneath the advancing Hollow Star.',
    actionLabel: 'Press onward',
    sceneKind: PixelSceneKind.chapter,
    chapter: chapter,
  );

  factory StorySceneScreen.finale({
    required AppController controller,
  }) => StorySceneScreen(
    controller: controller,
    beatId: StoryBeatIds.finale,
    title: 'The Dawn Returns',
    caption:
        'The Regalia crowns its queen, the Hollow Star breaks, and morning returns to every realm.',
    semanticLabel:
        'At sunrise in the Empyrean Citadel, the Queen wears the restored Regalia beside the returning knight as the Hollow Star shatters above the awakened city.',
    actionLabel: 'Return to the realms',
    sceneKind: PixelSceneKind.finale,
    chapter: journeyChapters.last,
  );

  final AppController controller;
  final String beatId;
  final String title;
  final String caption;
  final String semanticLabel;
  final String actionLabel;
  final PixelSceneKind sceneKind;
  final JourneyChapter? chapter;
  final bool popOnContinue;

  @override
  Widget build(BuildContext context) {
    final selectedChapter = chapter ?? journeyChapters.first;
    final themed = RegaliaTheme.forChapter(selectedChapter);
    return Theme(
      data: themed,
      child: Builder(
        builder:
            (context) => Scaffold(
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Expanded(
                            child: PixelStoryScene(
                              chapter: selectedChapter,
                              kind: sceneKind,
                              semanticLabel: semanticLabel,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CrownMark(size: 28),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(caption, textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            key: ValueKey('story-continue-$beatId'),
                            onPressed: () => _continue(context),
                            icon: PixelIcon(
                              PixelGlyph.arrowRight,
                              color: Theme.of(context).colorScheme.onSecondary,
                              size: 24,
                              excludeFromSemantics: true,
                            ),
                            label: Text(actionLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _continue(BuildContext context) async {
    await controller.markStoryBeatSeen(beatId);
    if (popOnContinue && context.mounted) Navigator.pop(context);
  }
}
