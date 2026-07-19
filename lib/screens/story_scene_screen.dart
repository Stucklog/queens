import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/journey.dart';
import '../app/theme.dart';
import '../content/content_models.dart';
import '../widgets/crown_mark.dart';
import '../widgets/pixel_art.dart';
import '../widgets/pixel_ui.dart';

class StorySceneScreen extends StatefulWidget {
  const StorySceneScreen({
    super.key,
    required this.controller,
    required this.scene,
    this.chapter,
    this.popOnContinue = true,
    this.recordSeenOnComplete = true,
  });

  factory StorySceneScreen.opening({
    required AppController controller,
    StoryArc? arc,
    bool popOnContinue = false,
    bool recordSeenOnComplete = true,
  }) {
    final selectedArc = arc ?? controller.originArc!;
    return StorySceneScreen.fromContent(
      controller: controller,
      scene: selectedArc.openingScene,
      chapter: selectedArc.chapters.first,
      popOnContinue: popOnContinue,
      recordSeenOnComplete: recordSeenOnComplete,
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
    bool recordSeenOnComplete = true,
  }) => StorySceneScreen(
    controller: controller,
    scene: scene,
    chapter: chapter,
    popOnContinue: popOnContinue,
    recordSeenOnComplete: recordSeenOnComplete,
  );

  final AppController controller;
  final StorySceneContent scene;
  final JourneyChapter? chapter;
  final bool popOnContinue;

  /// Replays deliberately leave the durable seen-scene set untouched.
  final bool recordSeenOnComplete;

  @override
  State<StorySceneScreen> createState() => _StorySceneScreenState();
}

class _StorySceneScreenState extends State<StorySceneScreen> {
  int _pageIndex = 0;

  @override
  void didUpdateWidget(covariant StorySceneScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.id != widget.scene.id) {
      _pageIndex = 0;
    } else if (_pageIndex >= widget.scene.pages.length) {
      _pageIndex = widget.scene.pages.length - 1;
    }
  }

  PixelSceneKind get _sceneKind => switch (widget.scene.role) {
    StorySceneRole.opening => PixelSceneKind.opening,
    StorySceneRole.chapter => PixelSceneKind.chapter,
    StorySceneRole.finale => PixelSceneKind.finale,
  };

  @override
  Widget build(BuildContext context) {
    final selectedChapter =
        widget.chapter ??
        widget.controller.originArc?.chapters.first ??
        journeyChapters.first;
    final themed = RegaliaTheme.forChapter(selectedChapter);
    final page = widget.scene.pages[_pageIndex];
    return Theme(
      data: themed,
      child: Builder(
        builder:
            (context) => Scaffold(
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide =
                        constraints.maxWidth >= 760 &&
                        constraints.maxHeight >= 560;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder:
                          (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(.025, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                      child: KeyedSubtree(
                        key: ValueKey(
                          'story-page-${widget.scene.id}-$_pageIndex',
                        ),
                        child:
                            wide
                                ? _buildWide(
                                  context,
                                  constraints,
                                  selectedChapter,
                                  page,
                                )
                                : _buildNarrow(
                                  context,
                                  constraints,
                                  selectedChapter,
                                  page,
                                ),
                      ),
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    BoxConstraints constraints,
    JourneyChapter chapter,
    StoryScenePageContent page,
  ) {
    final artHeight = math.min(
      360.0,
      math.max(230.0, constraints.maxHeight * .41),
    );
    return SingleChildScrollView(
      key: const ValueKey('story-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: artHeight, child: _artPanel(chapter, page)),
              const SizedBox(height: 22),
              _narrative(context, page),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    BoxConstraints constraints,
    JourneyChapter chapter,
    StoryScenePageContent page,
  ) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 11, child: _artPanel(chapter, page)),
            const SizedBox(width: 30),
            Expanded(
              flex: 9,
              child: SingleChildScrollView(
                key: const ValueKey('story-scroll'),
                child: _narrative(context, page),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _art(JourneyChapter chapter, StoryScenePageContent page) =>
      PixelStoryScene(
        chapter: chapter,
        kind: _sceneKind,
        semanticLabel: page.semanticLabel,
        assetPath: widget.scene.artAsset,
      );

  Widget _artPanel(JourneyChapter chapter, StoryScenePageContent page) {
    final art = _art(chapter, page);
    if (widget.scene.role != StorySceneRole.chapter) return art;
    return Align(child: AspectRatio(aspectRatio: 1, child: art));
  }

  Widget _narrative(BuildContext context, StoryScenePageContent page) {
    final pages = widget.scene.pages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pages.length > 1) ...[
          Text(
            '${_pageLabel(widget.scene.role)} · ${_pageIndex + 1} of ${pages.length}',
            key: const ValueKey('story-page-indicator'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CrownMark(size: 28),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final paragraph in page.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              paragraph,
              textAlign: TextAlign.start,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ),
        const SizedBox(height: 6),
        if (_pageIndex > 0)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('story-previous'),
                  onPressed: _previous,
                  icon: PixelIcon(
                    PixelGlyph.arrowLeft,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 16,
                    excludeFromSemantics: true,
                  ),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _continueButton(context, page)),
            ],
          )
        else
          _continueButton(context, page),
      ],
    );
  }

  Widget _continueButton(BuildContext context, StoryScenePageContent page) =>
      FilledButton.icon(
        key: ValueKey('story-continue-${widget.scene.id}'),
        onPressed: _continue,
        icon: PixelIcon(
          PixelGlyph.arrowRight,
          color: Theme.of(context).colorScheme.onSecondary,
          size: 16,
          excludeFromSemantics: true,
        ),
        label: Text(page.actionLabel, textAlign: TextAlign.center),
      );

  void _previous() => setState(() => _pageIndex--);

  Future<void> _continue() async {
    if (_pageIndex + 1 < widget.scene.pages.length) {
      setState(() => _pageIndex++);
      return;
    }
    if (widget.recordSeenOnComplete) {
      await widget.controller.markStoryBeatSeen(widget.scene.id);
    }
    if (widget.popOnContinue && mounted) Navigator.pop(context);
  }
}

String _pageLabel(StorySceneRole role) => switch (role) {
  StorySceneRole.opening => 'PROLOGUE',
  StorySceneRole.chapter => 'CHAPTER',
  StorySceneRole.finale => 'EPILOGUE',
};
