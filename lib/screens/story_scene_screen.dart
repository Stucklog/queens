import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../content/content_models.dart';
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
    this.artAsset,
    this.chapter,
    this.popOnContinue = true,
  });

  factory StorySceneScreen.opening({
    required AppController controller,
    StoryArc? arc,
    bool popOnContinue = false,
  }) {
    final selectedArc = arc ?? controller.originArc!;
    return StorySceneScreen.fromContent(
      controller: controller,
      scene: selectedArc.openingScene,
      chapter: selectedArc.chapters.first,
      popOnContinue: popOnContinue,
    );
  }

  factory StorySceneScreen.chapter({
    required AppController controller,
    required JourneyChapter chapter,
    StoryArc? arc,
  }) {
    final selectedArc = arc ?? controller.arcForChapter(chapter)!;
    return StorySceneScreen.fromContent(
      controller: controller,
      scene: selectedArc.sceneById(chapter.sceneId),
      chapter: chapter,
    );
  }

  factory StorySceneScreen.finale({
    required AppController controller,
    StoryArc? arc,
  }) {
    final selectedArc = arc ?? controller.originArc!;
    return StorySceneScreen.fromContent(
      controller: controller,
      scene: selectedArc.finaleScene,
      chapter: selectedArc.chapters.last,
    );
  }

  factory StorySceneScreen.fromContent({
    required AppController controller,
    required StorySceneContent scene,
    JourneyChapter? chapter,
    bool popOnContinue = true,
  }) => StorySceneScreen(
    controller: controller,
    beatId: scene.id,
    title: scene.title,
    caption: scene.caption,
    semanticLabel: scene.semanticLabel,
    actionLabel: scene.actionLabel,
    sceneKind: switch (scene.role) {
      StorySceneRole.opening => PixelSceneKind.opening,
      StorySceneRole.chapter => PixelSceneKind.chapter,
      StorySceneRole.finale => PixelSceneKind.finale,
    },
    artAsset: scene.artAsset,
    chapter: chapter,
    popOnContinue: popOnContinue,
  );

  final AppController controller;
  final String beatId;
  final String title;
  final String caption;
  final String semanticLabel;
  final String actionLabel;
  final PixelSceneKind sceneKind;
  final String? artAsset;
  final JourneyChapter? chapter;
  final bool popOnContinue;

  @override
  Widget build(BuildContext context) {
    final selectedChapter =
        chapter ??
        controller.originArc?.chapters.first ??
        journeyChapters.first;
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
                              assetPath: artAsset,
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
