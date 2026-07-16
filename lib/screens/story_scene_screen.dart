import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';

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
    title: 'The Crown Takes Flight',
    caption: 'A magical wind scatters the royal crown beyond Crownspire.',
    semanticLabel:
        'A knight in Clovermead holds the recovered crown while Crownspire rises in the distance.',
    actionLabel: 'Begin journey',
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
        'The crown bearer reaches ${chapter.title}, the next location on the road to Crownspire.',
    actionLabel: 'Follow the road',
    sceneKind: PixelSceneKind.chapter,
    chapter: chapter,
  );

  factory StorySceneScreen.finale({
    required AppController controller,
  }) => StorySceneScreen(
    controller: controller,
    beatId: StoryBeatIds.finale,
    title: 'The Crown Returns',
    caption: 'Morning reaches Crownspire, and the long road is complete.',
    semanticLabel:
        'At sunrise in Crownspire, the Queen wears the recovered crown beside the returning knight.',
    actionLabel: 'Open the journey',
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
    final themed = RegaliaTheme.forChapter(
      Theme.of(context).brightness,
      selectedChapter,
    );
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
                            icon: PixelStatusIcon(
                              glyph: PixelStatusGlyph.arrow,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 18,
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
