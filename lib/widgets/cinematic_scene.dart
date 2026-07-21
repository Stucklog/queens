import 'package:flutter/material.dart';

import '../app/journey.dart';
import '../content/cinematic_scene_models.dart';
import 'pixel_art.dart';
import 'pixel_ui.dart';

/// Shared renderer for an authored cinematic frame.
///
/// The content model owns the background and cast. This widget owns loading,
/// sprite timing, reduced-motion behavior, semantics, and layout, so adding a
/// protagonist or antagonist never requires another one-off scene widget.
class CinematicSceneFrameView extends StatelessWidget {
  const CinematicSceneFrameView({
    super.key,
    required this.frame,
    required this.palette,
    required this.sceneKind,
    this.chapter,
  });

  final CinematicSceneFrame frame;
  final JourneyPalette palette;
  final PixelSceneKind sceneKind;
  final JourneyChapter? chapter;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: frame.narrative.semanticLabel,
    child: ClipPath(
      clipper: const ShapeBorderClipper(shape: PixelOrganicBorder()),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _background(context),
          for (final layer in frame.characterLayersInPaintOrder)
            _CinematicCharacterLayerView(layer: layer),
        ],
      ),
    ),
  );

  Widget _background(BuildContext context) {
    final activeChapter = chapter;
    if (activeChapter != null) {
      return PixelLandscape(
        chapter: activeChapter,
        brightness: palette.theme.brightness,
        sceneKind: sceneKind,
        assetPath: frame.background.asset,
        fit: _boxFit(frame.background.fit),
      );
    }
    return ColoredBox(
      color: palette.background,
      child: Image.asset(
        frame.background.asset,
        fit: _boxFit(frame.background.fit),
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
        errorBuilder:
            (context, error, stackTrace) => DecoratedBox(
              key: const ValueKey('cinematic-background-error-fallback'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.background, palette.surface],
                ),
              ),
            ),
      ),
    );
  }
}

class _CinematicCharacterLayerView extends StatelessWidget {
  const _CinematicCharacterLayerView({required this.layer});

  final CinematicCharacterLayer layer;

  @override
  Widget build(BuildContext context) {
    final source = layer.source;
    final size = layer.size;
    final defaultSize = switch (source) {
      CinematicBuiltInCharacterSource(
        character: CinematicBuiltInCharacter.crownBearer,
      ) =>
        const Size(92, 138),
      CinematicBuiltInCharacterSource(
        character: CinematicBuiltInCharacter.queen,
      ) =>
        const Size(92, 145),
      _ => const Size(124, 168),
    };
    final configuredWidth = size?.width;
    final configuredHeight = size?.height;
    final width =
        (configuredWidth ??
            (configuredHeight == null
                ? defaultSize.width
                : configuredHeight * defaultSize.aspectRatio)) *
        layer.scale;
    final height =
        (configuredHeight ??
            (configuredWidth == null
                ? defaultSize.height
                : configuredWidth / defaultSize.aspectRatio)) *
        layer.scale;
    Widget art = switch (source) {
      CinematicBuiltInCharacterSource(
        character: CinematicBuiltInCharacter.crownBearer,
      ) =>
        PixelStoryKnightSprite(width: width, height: height),
      CinematicBuiltInCharacterSource(
        character: CinematicBuiltInCharacter.queen,
      ) =>
        PixelQueenSprite(
          width: width,
          height: height,
          faceLeft: layer.mirrored,
        ),
      CinematicAssetCharacterSource(:final asset) => _CinematicAssetSprite(
        asset: asset,
        animation: layer.animation,
        width: width,
        height: height,
      ),
    };
    if (layer.mirrored && source is! CinematicBuiltInCharacterSource) {
      art = Transform.flip(flipX: true, child: art);
    }
    return Align(
      key: ValueKey('cinematic-character-${layer.id}'),
      alignment: Alignment(layer.alignment.x, layer.alignment.y),
      child: Semantics(
        image: true,
        label: layer.semanticLabel,
        child: ExcludeSemantics(child: art),
      ),
    );
  }
}

class _CinematicAssetSprite extends StatefulWidget {
  const _CinematicAssetSprite({
    required this.asset,
    required this.animation,
    required this.width,
    required this.height,
  });

  final String asset;
  final CinematicSpriteAnimation? animation;
  final double width;
  final double height;

  @override
  State<_CinematicAssetSprite> createState() => _CinematicAssetSpriteState();
}

class _CinematicAssetSpriteState extends State<_CinematicAssetSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation(restart: false);
  }

  @override
  void didUpdateWidget(covariant _CinematicAssetSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation(
      restart:
          oldWidget.asset != widget.asset ||
          oldWidget.animation != widget.animation,
    );
  }

  void _syncAnimation({required bool restart}) {
    final animation = widget.animation;
    _controller.stop();
    if (restart) _controller.value = 0;
    if (animation == null || _reduceMotion || !TickerMode.of(context)) return;
    _controller.duration = animation.duration;
    if (animation.loop) {
      _controller.repeat(period: animation.duration);
    } else {
      _controller.forward(from: restart ? 0 : _controller.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.animation;
    if (animation == null) return _image();
    if (_reduceMotion &&
        animation.reducedMotion.behavior ==
            CinematicReducedMotionBehavior.hideLayer) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final localFrame =
            _reduceMotion
                ? animation.reducedMotion.resolvedFrame(animation.frameCount) ??
                    0
                : (_controller.value * animation.frameCount).floor().clamp(
                  0,
                  animation.frameCount - 1,
                );
        return _image(frame: animation.startFrame + localFrame);
      },
    );
  }

  Widget _image({int? frame}) {
    final animation = widget.animation;
    Widget image = Image.asset(
      widget.asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder:
          (context, error, stackTrace) => const SizedBox.expand(
            key: ValueKey('cinematic-character-error-fallback'),
          ),
    );
    if (animation != null && frame != null) {
      final column = frame % animation.columns;
      final row = frame ~/ animation.columns;
      image = ClipRect(
        child: Align(
          alignment: Alignment(
            animation.columns == 1
                ? 0
                : -1 + (2 * column / (animation.columns - 1)),
            animation.rows == 1 ? 0 : -1 + (2 * row / (animation.rows - 1)),
          ),
          widthFactor: 1 / animation.columns,
          heightFactor: 1 / animation.rows,
          child: image,
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FittedBox(fit: BoxFit.contain, child: image),
    );
  }
}

BoxFit _boxFit(CinematicBackgroundFit fit) => switch (fit) {
  CinematicBackgroundFit.cover => BoxFit.cover,
  CinematicBackgroundFit.contain => BoxFit.contain,
  CinematicBackgroundFit.fill => BoxFit.fill,
  CinematicBackgroundFit.fitWidth => BoxFit.fitWidth,
  CinematicBackgroundFit.fitHeight => BoxFit.fitHeight,
  CinematicBackgroundFit.none => BoxFit.none,
  CinematicBackgroundFit.scaleDown => BoxFit.scaleDown,
};
