/// Data-only presentation models for story cinematics.
///
/// A scene may use the preferred `frames` shape, or the legacy `pages` shape:
///
/// ```json
/// {
///   "defaults": {
///     "background": {"asset": "assets/art/hall.png", "fit": "cover"},
///     "characters": [
///       {
///         "id": "bearer",
///         "source": {"type": "builtIn", "character": "crownBearer"},
///         "alignment": "bottomLeft",
///         "semanticLabel": "The crown-bearer"
///       }
///     ]
///   },
///   "frames": [
///     {
///       "id": "arrival",
///       "narrative": {
///         "title": "The Arrival",
///         "paragraphs": ["The doors opened."],
///         "semanticLabel": "The crown-bearer enters the hall.",
///         "actionLabel": "Continue"
///       }
///     }
///   ]
/// }
/// ```
///
/// Models in this file deliberately do not depend on Flutter widgets. Renderers
/// can translate fit and normalized alignment values to their UI equivalents.
library;

enum CinematicBackgroundFit {
  cover,
  contain,
  fill,
  fitWidth,
  fitHeight,
  none,
  scaleDown,
}

enum CinematicBuiltInCharacter { crownBearer, queen }

enum CinematicReducedMotionBehavior {
  firstFrame,
  lastFrame,
  selectedFrame,
  hideLayer,
}

/// A fully resolved cinematic. Defaults have already been applied to frames.
final class CinematicScenePresentation {
  CinematicScenePresentation({required Iterable<CinematicSceneFrame> frames})
    : frames = List<CinematicSceneFrame>.unmodifiable(frames) {
    if (this.frames.isEmpty) {
      throw const FormatException(
        'A cinematic presentation must contain at least one frame',
      );
    }
    final ids = <String>{};
    for (final frame in this.frames) {
      if (!ids.add(frame.id)) {
        throw FormatException('Duplicate cinematic frame id ${frame.id}');
      }
    }
  }

  final List<CinematicSceneFrame> frames;

  CinematicSceneFrame frameById(String id) =>
      frames.firstWhere((frame) => frame.id == id);

  factory CinematicScenePresentation.fromJson(Map<String, Object?> json) {
    const scenePath = r'$scene';
    final defaults =
        json['defaults'] == null
            ? const <String, Object?>{}
            : _asMap(json['defaults'], '$scenePath.defaults');

    final rootBackground = _backgroundFromContainer(
      json,
      path: scenePath,
      required: false,
    );
    final defaultBackground = _backgroundFromContainer(
      defaults,
      path: '$scenePath.defaults',
      fallback: rootBackground,
      required: false,
    );

    final directDefaultLayers = _layerListFromContainer(json, path: scenePath);
    var defaultLayers =
        _layerListFromContainer(defaults, path: '$scenePath.defaults') ??
        directDefaultLayers;

    final rawFrames = json['frames'];
    final usesLegacyPages = rawFrames == null;
    if (defaultLayers == null && usesLegacyPages) {
      defaultLayers = _legacyLayersForRole(json['role'], '$scenePath.role');
    }
    defaultLayers ??= const <CinematicCharacterLayer>[];

    final List<Object?> frameValues;
    final String framePath;
    if (rawFrames != null) {
      frameValues = _asList(rawFrames, '$scenePath.frames');
      framePath = '$scenePath.frames';
    } else if (json['pages'] != null) {
      frameValues = _asList(json['pages'], '$scenePath.pages');
      framePath = '$scenePath.pages';
    } else {
      // Old single-page scenes placed narrative keys directly on the scene.
      frameValues = <Object?>[json];
      framePath = scenePath;
    }

    if (frameValues.isEmpty) {
      throw FormatException('$framePath must contain at least one frame');
    }

    final frames = <CinematicSceneFrame>[];
    for (var index = 0; index < frameValues.length; index++) {
      final path =
          frameValues.length == 1 && framePath == scenePath
              ? scenePath
              : '$framePath[$index]';
      frames.add(
        _frameFromJson(
          _asMap(frameValues[index], path),
          path: path,
          fallbackId: usesLegacyPages ? 'frame-${index + 1}' : null,
          defaultBackground: defaultBackground,
          defaultLayers: defaultLayers,
        ),
      );
    }
    return CinematicScenePresentation(frames: frames);
  }
}

final class CinematicSceneFrame {
  CinematicSceneFrame({
    required this.id,
    required this.narrative,
    required this.background,
    Iterable<CinematicCharacterLayer> characterLayers = const [],
  }) : characterLayers = List<CinematicCharacterLayer>.unmodifiable(
         characterLayers,
       ) {
    if (id.trim().isEmpty) {
      throw const FormatException('A cinematic frame id cannot be empty');
    }
    final ids = <String>{};
    for (final layer in this.characterLayers) {
      if (!ids.add(layer.id)) {
        throw FormatException('Duplicate character layer id $id/${layer.id}');
      }
    }
  }

  final String id;
  final CinematicFrameNarrative narrative;
  final CinematicFrameBackground background;

  /// Declaration order is retained so equal z-orders remain deterministic.
  final List<CinematicCharacterLayer> characterLayers;

  /// Stable back-to-front order for a Stack-like renderer.
  List<CinematicCharacterLayer> get characterLayersInPaintOrder {
    final indexed = characterLayers.indexed.toList(growable: false);
    final sorted =
        indexed.toList()..sort((a, b) {
          final byZ = a.$2.zOrder.compareTo(b.$2.zOrder);
          return byZ == 0 ? a.$1.compareTo(b.$1) : byZ;
        });
    return List<CinematicCharacterLayer>.unmodifiable(
      sorted.map((entry) => entry.$2),
    );
  }

  factory CinematicSceneFrame.fromJson(
    Map<String, Object?> json, {
    String? fallbackId,
    CinematicFrameBackground? defaultBackground,
    List<CinematicCharacterLayer> defaultCharacterLayers = const [],
  }) => _frameFromJson(
    json,
    path: r'$frame',
    fallbackId: fallbackId,
    defaultBackground: defaultBackground,
    defaultLayers: defaultCharacterLayers,
  );
}

final class CinematicFrameNarrative {
  CinematicFrameNarrative({
    required this.title,
    required Iterable<String> paragraphs,
    required this.semanticLabel,
    this.actionLabel = 'Continue',
  }) : paragraphs = List<String>.unmodifiable(paragraphs) {
    if (title.trim().isEmpty) {
      throw const FormatException('A cinematic frame title cannot be empty');
    }
    if (this.paragraphs.isEmpty ||
        this.paragraphs.any((paragraph) => paragraph.trim().isEmpty)) {
      throw const FormatException(
        'A cinematic frame must contain non-empty narrative paragraphs',
      );
    }
    if (semanticLabel.trim().isEmpty || actionLabel.trim().isEmpty) {
      throw const FormatException(
        'Cinematic semantic and action labels cannot be empty',
      );
    }
  }

  final String title;
  final List<String> paragraphs;
  final String semanticLabel;
  final String actionLabel;

  factory CinematicFrameNarrative.fromJson(Map<String, Object?> json) =>
      _narrativeFromJson(json, path: r'$narrative');
}

final class CinematicFrameBackground {
  CinematicFrameBackground({
    required this.asset,
    this.fit = CinematicBackgroundFit.cover,
  }) {
    _validateAssetPath(asset, r'$background.asset');
  }

  final String asset;
  final CinematicBackgroundFit fit;

  factory CinematicFrameBackground.fromJson(Object? json) {
    final container = <String, Object?>{'background': json};
    return _backgroundFromContainer(
      container,
      path: r'$background',
      required: true,
    )!;
  }
}

/// Normalized alignment using the same -1..1 coordinate space as Flutter's
/// Alignment, without introducing a Flutter dependency into content parsing.
final class CinematicLayerAlignment {
  const CinematicLayerAlignment._(this.x, this.y);

  factory CinematicLayerAlignment({required double x, required double y}) {
    _validateNormalizedCoordinate(x, r'$alignment.x');
    _validateNormalizedCoordinate(y, r'$alignment.y');
    return CinematicLayerAlignment._(x, y);
  }

  final double x;
  final double y;

  static const topLeft = CinematicLayerAlignment._(-1, -1);
  static const topCenter = CinematicLayerAlignment._(0, -1);
  static const topRight = CinematicLayerAlignment._(1, -1);
  static const centerLeft = CinematicLayerAlignment._(-1, 0);
  static const center = CinematicLayerAlignment._(0, 0);
  static const centerRight = CinematicLayerAlignment._(1, 0);
  static const bottomLeft = CinematicLayerAlignment._(-1, 1);
  static const bottomCenter = CinematicLayerAlignment._(0, 1);
  static const bottomRight = CinematicLayerAlignment._(1, 1);

  factory CinematicLayerAlignment.fromJson(Object? json) =>
      _alignmentFromJson(json, r'$alignment');
}

/// Optional logical dimensions. A renderer preserves aspect ratio when only
/// one dimension is present, then applies the layer's scale.
final class CinematicLayerSize {
  const CinematicLayerSize._({this.width, this.height});

  factory CinematicLayerSize({double? width, double? height}) {
    if (width == null && height == null) {
      throw const FormatException(
        'A cinematic layer size needs a width or height',
      );
    }
    if (width != null) _validatePositive(width, r'$size.width');
    if (height != null) _validatePositive(height, r'$size.height');
    return CinematicLayerSize._(width: width, height: height);
  }

  final double? width;
  final double? height;

  factory CinematicLayerSize.fromJson(Object? json) =>
      _sizeFromJson(json, r'$size');
}

sealed class CinematicCharacterSource {
  const CinematicCharacterSource();

  String get defaultSemanticLabel;

  factory CinematicCharacterSource.fromJson(Object? json) =>
      _sourceFromJson(json, r'$source');
}

final class CinematicBuiltInCharacterSource extends CinematicCharacterSource {
  const CinematicBuiltInCharacterSource(this.character);

  final CinematicBuiltInCharacter character;

  @override
  String get defaultSemanticLabel => switch (character) {
    CinematicBuiltInCharacter.crownBearer => 'The crown-bearer',
    CinematicBuiltInCharacter.queen => 'The Queen',
  };
}

final class CinematicAssetCharacterSource extends CinematicCharacterSource {
  CinematicAssetCharacterSource(this.asset) {
    _validateAssetPath(asset, r'$source.asset');
  }

  final String asset;

  @override
  String get defaultSemanticLabel => 'Story character';
}

final class CinematicCharacterLayer {
  CinematicCharacterLayer({
    required this.id,
    required this.source,
    required this.semanticLabel,
    this.alignment = CinematicLayerAlignment.center,
    this.scale = 1,
    this.size,
    this.mirrored = false,
    this.zOrder = 0,
    this.animation,
  }) {
    if (id.trim().isEmpty || semanticLabel.trim().isEmpty) {
      throw const FormatException(
        'Character layer ids and semantic labels cannot be empty',
      );
    }
    _validatePositive(scale, r'$character.scale');
  }

  final String id;
  final CinematicCharacterSource source;
  final CinematicLayerAlignment alignment;
  final double scale;
  final CinematicLayerSize? size;
  final bool mirrored;
  final String semanticLabel;
  final int zOrder;
  final CinematicSpriteAnimation? animation;

  factory CinematicCharacterLayer.fromJson(
    Map<String, Object?> json, {
    int defaultZOrder = 0,
  }) => _layerFromJson(
    json,
    path: r'$character',
    fallbackId: 'character-${defaultZOrder + 1}',
    defaultZOrder: defaultZOrder,
  );
}

final class CinematicReducedMotionPreference {
  const CinematicReducedMotionPreference._(this.behavior, this.frame);

  final CinematicReducedMotionBehavior behavior;

  /// A zero-based index within the animation, not the whole atlas.
  final int? frame;

  static const firstFrame = CinematicReducedMotionPreference._(
    CinematicReducedMotionBehavior.firstFrame,
    null,
  );
  static const lastFrame = CinematicReducedMotionPreference._(
    CinematicReducedMotionBehavior.lastFrame,
    null,
  );
  static const hideLayer = CinematicReducedMotionPreference._(
    CinematicReducedMotionBehavior.hideLayer,
    null,
  );

  factory CinematicReducedMotionPreference.selectedFrame(int frame) {
    if (frame < 0) {
      throw const FormatException(
        'A reduced-motion animation frame cannot be negative',
      );
    }
    return CinematicReducedMotionPreference._(
      CinematicReducedMotionBehavior.selectedFrame,
      frame,
    );
  }

  factory CinematicReducedMotionPreference.fromJson(
    Object? json, {
    required int frameCount,
  }) => _reducedMotionFromJson(
    json,
    path: r'$animation.reducedMotion',
    frameCount: frameCount,
  );

  int? resolvedFrame(int frameCount) => switch (behavior) {
    CinematicReducedMotionBehavior.firstFrame => 0,
    CinematicReducedMotionBehavior.lastFrame => frameCount - 1,
    CinematicReducedMotionBehavior.selectedFrame => frame,
    CinematicReducedMotionBehavior.hideLayer => null,
  };
}

/// Metadata for an evenly divided sprite sheet.
final class CinematicSpriteAnimation {
  CinematicSpriteAnimation({
    required this.frameCount,
    required this.columns,
    required this.rows,
    required this.frameDuration,
    this.startFrame = 0,
    this.loop = true,
    this.reducedMotion = CinematicReducedMotionPreference.firstFrame,
  }) {
    if (frameCount < 1 || columns < 1 || rows < 1 || startFrame < 0) {
      throw const FormatException(
        'Sprite-sheet dimensions and frame counts must be positive',
      );
    }
    if (startFrame + frameCount > columns * rows) {
      throw const FormatException(
        'Sprite animation frames exceed the declared sheet dimensions',
      );
    }
    if (frameDuration <= Duration.zero) {
      throw const FormatException('Sprite frame duration must be positive');
    }
    final reducedFrame = reducedMotion.frame;
    if (reducedFrame != null && reducedFrame >= frameCount) {
      throw const FormatException(
        'Reduced-motion frame is outside the sprite animation',
      );
    }
  }

  final int frameCount;
  final int columns;
  final int rows;
  final int startFrame;
  final Duration frameDuration;
  final bool loop;
  final CinematicReducedMotionPreference reducedMotion;

  Duration get duration => frameDuration * frameCount;

  factory CinematicSpriteAnimation.fromJson(Map<String, Object?> json) =>
      _animationFromJson(json, r'$animation');
}

CinematicSceneFrame _frameFromJson(
  Map<String, Object?> json, {
  required String path,
  required String? fallbackId,
  required CinematicFrameBackground? defaultBackground,
  required List<CinematicCharacterLayer> defaultLayers,
}) {
  final id = _optionalString(json['id'], '$path.id') ?? fallbackId ?? 'frame-1';
  final narrativeValue = json['narrative'];
  final narrative = _narrativeFromJson(
    narrativeValue == null ? json : _asMap(narrativeValue, '$path.narrative'),
    path: narrativeValue == null ? path : '$path.narrative',
    outer: narrativeValue == null ? null : json,
  );
  final background =
      _backgroundFromContainer(
        json,
        path: path,
        fallback: defaultBackground,
        required: true,
      )!;
  final characterLayers =
      _layerListFromContainer(json, path: path) ?? defaultLayers;
  return CinematicSceneFrame(
    id: id,
    narrative: narrative,
    background: background,
    characterLayers: characterLayers,
  );
}

CinematicFrameNarrative _narrativeFromJson(
  Map<String, Object?> json, {
  required String path,
  Map<String, Object?>? outer,
}) {
  final title = _requiredString(json['title'], '$path.title');
  final rawParagraphs = json['paragraphs'] ?? json['text'];
  final List<String> paragraphs;
  if (rawParagraphs != null) {
    if (rawParagraphs is String) {
      paragraphs = <String>[_requiredString(rawParagraphs, '$path.text')];
    } else {
      paragraphs = _asList(rawParagraphs, '$path.paragraphs').indexed
          .map(
            (entry) =>
                _requiredString(entry.$2, '$path.paragraphs[${entry.$1}]'),
          )
          .toList(growable: false);
    }
  } else if (json['caption'] != null) {
    paragraphs = <String>[_requiredString(json['caption'], '$path.caption')];
  } else {
    throw FormatException('$path needs paragraphs or a caption');
  }

  final semanticLabel =
      _optionalString(json['semanticLabel'], '$path.semanticLabel') ??
      _optionalString(
        outer?['semanticLabel'],
        '${path.substring(0, path.lastIndexOf('.'))}.semanticLabel',
      ) ??
      title;
  final actionLabel =
      _optionalString(json['actionLabel'], '$path.actionLabel') ??
      _optionalString(
        outer?['actionLabel'],
        '${path.substring(0, path.lastIndexOf('.'))}.actionLabel',
      ) ??
      'Continue';
  return CinematicFrameNarrative(
    title: title,
    paragraphs: paragraphs,
    semanticLabel: semanticLabel,
    actionLabel: actionLabel,
  );
}

CinematicFrameBackground? _backgroundFromContainer(
  Map<String, Object?> json, {
  required String path,
  required bool required,
  CinematicFrameBackground? fallback,
}) {
  String? asset;
  Object? fitValue;
  final nested = json['background'];
  if (nested is String) {
    asset = _requiredString(nested, '$path.background');
  } else if (nested != null) {
    final map = _asMap(nested, '$path.background');
    asset = _optionalString(
      map['asset'] ?? map['artAsset'] ?? map['path'],
      '$path.background.asset',
    );
    fitValue = map['fit'];
  }
  asset ??= _optionalString(
    json['backgroundAsset'] ?? json['artAsset'],
    '$path.backgroundAsset',
  );
  fitValue ??= json['backgroundFit'];

  final resolvedAsset = asset ?? fallback?.asset;
  if (resolvedAsset == null) {
    if (!required) return null;
    throw FormatException('$path needs a background asset');
  }
  final fit =
      fitValue == null
          ? fallback?.fit ?? CinematicBackgroundFit.cover
          : _backgroundFitFromJson(fitValue, '$path.background.fit');
  return CinematicFrameBackground(asset: resolvedAsset, fit: fit);
}

List<CinematicCharacterLayer>? _layerListFromContainer(
  Map<String, Object?> json, {
  required String path,
}) {
  const keys = <String>['characters', 'characterLayers', 'layers'];
  String? selectedKey;
  for (final key in keys) {
    if (json.containsKey(key)) {
      selectedKey = key;
      break;
    }
  }
  if (selectedKey == null) return null;
  final values = _asList(json[selectedKey], '$path.$selectedKey');
  return List<CinematicCharacterLayer>.unmodifiable(
    values.indexed.map(
      (entry) => _layerFromJson(
        _asMap(entry.$2, '$path.$selectedKey[${entry.$1}]'),
        path: '$path.$selectedKey[${entry.$1}]',
        fallbackId: 'character-${entry.$1 + 1}',
        defaultZOrder: entry.$1,
      ),
    ),
  );
}

CinematicCharacterLayer _layerFromJson(
  Map<String, Object?> json, {
  required String path,
  required String fallbackId,
  required int defaultZOrder,
}) {
  final id = _optionalString(json['id'], '$path.id') ?? fallbackId;
  final source = _sourceFromLayer(json, path);
  final alignment =
      json['alignment'] == null
          ? CinematicLayerAlignment.center
          : _alignmentFromJson(json['alignment'], '$path.alignment');
  final scale =
      json['scale'] == null ? 1.0 : _double(json['scale'], '$path.scale');
  final sizeValue = json['size'];
  CinematicLayerSize? size;
  if (sizeValue != null) {
    size = _sizeFromJson(sizeValue, '$path.size');
  } else if (json['width'] != null || json['height'] != null) {
    size = CinematicLayerSize(
      width:
          json['width'] == null ? null : _double(json['width'], '$path.width'),
      height:
          json['height'] == null
              ? null
              : _double(json['height'], '$path.height'),
    );
  }
  final mirroredValue = json['mirrored'] ?? json['mirror'] ?? json['faceLeft'];
  final mirrored =
      mirroredValue == null ? false : _bool(mirroredValue, '$path.mirrored');
  final semanticLabel =
      _optionalString(json['semanticLabel'], '$path.semanticLabel') ??
      source.defaultSemanticLabel;
  final zOrder =
      json['zOrder'] == null
          ? defaultZOrder
          : _int(json['zOrder'], '$path.zOrder');
  final animation =
      json['animation'] == null
          ? null
          : _animationFromJson(
            _asMap(json['animation'], '$path.animation'),
            '$path.animation',
          );
  return CinematicCharacterLayer(
    id: id,
    source: source,
    alignment: alignment,
    scale: scale,
    size: size,
    mirrored: mirrored,
    semanticLabel: semanticLabel,
    zOrder: zOrder,
    animation: animation,
  );
}

CinematicCharacterSource _sourceFromLayer(
  Map<String, Object?> json,
  String path,
) {
  if (json['source'] != null) {
    return _sourceFromJson(json['source'], '$path.source');
  }
  if (json['asset'] != null) {
    return CinematicAssetCharacterSource(
      _requiredString(json['asset'], '$path.asset'),
    );
  }
  final builtIn = json['character'] ?? json['builtIn'];
  if (builtIn != null) {
    return CinematicBuiltInCharacterSource(
      _builtInCharacterFromJson(builtIn, '$path.character'),
    );
  }
  throw FormatException('$path needs a built-in character or asset source');
}

CinematicCharacterSource _sourceFromJson(Object? json, String path) {
  if (json is String) {
    final normalized = _normalized(json);
    if (_isBuiltInCharacterName(normalized)) {
      return CinematicBuiltInCharacterSource(
        _builtInCharacterFromJson(json, path),
      );
    }
    return CinematicAssetCharacterSource(_requiredString(json, path));
  }
  final map = _asMap(json, path);
  final type = _optionalString(map['type'] ?? map['kind'], '$path.type');
  if (type == null) {
    if (map['asset'] != null || map['path'] != null) {
      return CinematicAssetCharacterSource(
        _requiredString(map['asset'] ?? map['path'], '$path.asset'),
      );
    }
    return CinematicBuiltInCharacterSource(
      _builtInCharacterFromJson(
        map['character'] ?? map['builtIn'],
        '$path.character',
      ),
    );
  }
  switch (_normalized(type)) {
    case 'builtin':
      return CinematicBuiltInCharacterSource(
        _builtInCharacterFromJson(
          map['character'] ?? map['name'],
          '$path.character',
        ),
      );
    case 'asset':
    case 'customasset':
      return CinematicAssetCharacterSource(
        _requiredString(map['asset'] ?? map['path'], '$path.asset'),
      );
    default:
      throw FormatException('$path has unknown character source type $type');
  }
}

CinematicBuiltInCharacter _builtInCharacterFromJson(Object? json, String path) {
  final value = _requiredString(json, path);
  return switch (_normalized(value)) {
    'crownbearer' || 'knight' => CinematicBuiltInCharacter.crownBearer,
    'queen' => CinematicBuiltInCharacter.queen,
    _ => throw FormatException('$path has unknown built-in character $value'),
  };
}

bool _isBuiltInCharacterName(String value) =>
    value == 'crownbearer' || value == 'knight' || value == 'queen';

CinematicLayerAlignment _alignmentFromJson(Object? json, String path) {
  if (json is String) {
    return switch (_normalized(json)) {
      'topleft' => CinematicLayerAlignment.topLeft,
      'topcenter' => CinematicLayerAlignment.topCenter,
      'topright' => CinematicLayerAlignment.topRight,
      'centerleft' => CinematicLayerAlignment.centerLeft,
      'center' => CinematicLayerAlignment.center,
      'centerright' => CinematicLayerAlignment.centerRight,
      'bottomleft' => CinematicLayerAlignment.bottomLeft,
      'bottomcenter' => CinematicLayerAlignment.bottomCenter,
      'bottomright' => CinematicLayerAlignment.bottomRight,
      _ => throw FormatException('$path has unknown alignment $json'),
    };
  }
  final map = _asMap(json, path);
  return CinematicLayerAlignment(
    x: _double(map['x'] ?? 0, '$path.x'),
    y: _double(map['y'] ?? 0, '$path.y'),
  );
}

CinematicLayerSize _sizeFromJson(Object? json, String path) {
  if (json is num) {
    final dimension = _double(json, path);
    return CinematicLayerSize(width: dimension, height: dimension);
  }
  final map = _asMap(json, path);
  return CinematicLayerSize(
    width: map['width'] == null ? null : _double(map['width'], '$path.width'),
    height:
        map['height'] == null ? null : _double(map['height'], '$path.height'),
  );
}

CinematicSpriteAnimation _animationFromJson(
  Map<String, Object?> json,
  String path,
) {
  final frameCount = _int(
    json['frameCount'] ?? json['frames'],
    '$path.frameCount',
  );
  if (frameCount < 1) {
    throw FormatException('$path.frameCount must be positive');
  }
  final startFrame =
      json['startFrame'] == null
          ? 0
          : _int(json['startFrame'], '$path.startFrame');
  if (startFrame < 0) {
    throw FormatException('$path.startFrame cannot be negative');
  }
  final columns =
      json['columns'] == null
          ? frameCount
          : _int(json['columns'], '$path.columns');
  if (columns < 1) {
    throw FormatException('$path.columns must be positive');
  }
  final rows =
      json['rows'] == null
          ? (startFrame + frameCount + columns - 1) ~/ columns
          : _int(json['rows'], '$path.rows');
  if (json['frameDurationMs'] != null && json['framesPerSecond'] != null) {
    throw FormatException(
      '$path cannot set both frameDurationMs and framesPerSecond',
    );
  }
  final Duration frameDuration;
  if (json['framesPerSecond'] != null) {
    final fps = _double(json['framesPerSecond'], '$path.framesPerSecond');
    _validatePositive(fps, '$path.framesPerSecond');
    frameDuration = Duration(microseconds: (1000000 / fps).round());
  } else {
    final milliseconds =
        json['frameDurationMs'] == null
            ? 150
            : _int(json['frameDurationMs'], '$path.frameDurationMs');
    frameDuration = Duration(milliseconds: milliseconds);
  }
  final loop = json['loop'] == null ? true : _bool(json['loop'], '$path.loop');
  final reducedMotion = _reducedMotionFromJson(
    json['reducedMotion'] ?? 'firstFrame',
    path: '$path.reducedMotion',
    frameCount: frameCount,
  );
  return CinematicSpriteAnimation(
    frameCount: frameCount,
    columns: columns,
    rows: rows,
    startFrame: startFrame,
    frameDuration: frameDuration,
    loop: loop,
    reducedMotion: reducedMotion,
  );
}

CinematicReducedMotionPreference _reducedMotionFromJson(
  Object? json, {
  required String path,
  required int frameCount,
}) {
  if (json is int) {
    return _checkedReducedFrame(json, frameCount, path);
  }
  Object? behaviorValue = json;
  Object? frameValue;
  if (json is Map) {
    final map = _asMap(json, path);
    behaviorValue = map['behavior'] ?? map['mode'];
    frameValue = map['frame'];
  }
  final behavior = _requiredString(behaviorValue, '$path.behavior');
  return switch (_normalized(behavior)) {
    'first' ||
    'firstframe' ||
    'start' => CinematicReducedMotionPreference.firstFrame,
    'last' ||
    'lastframe' ||
    'end' => CinematicReducedMotionPreference.lastFrame,
    'hide' ||
    'hidden' ||
    'hidelayer' => CinematicReducedMotionPreference.hideLayer,
    'frame' || 'selectedframe' || 'staticframe' => _checkedReducedFrame(
      _int(frameValue, '$path.frame'),
      frameCount,
      '$path.frame',
    ),
    _ =>
      throw FormatException(
        '$path has unknown reduced-motion behavior $behavior',
      ),
  };
}

CinematicReducedMotionPreference _checkedReducedFrame(
  int frame,
  int frameCount,
  String path,
) {
  if (frame < 0 || frame >= frameCount) {
    throw FormatException('$path must be between 0 and ${frameCount - 1}');
  }
  return CinematicReducedMotionPreference.selectedFrame(frame);
}

CinematicBackgroundFit _backgroundFitFromJson(Object? json, String path) {
  final value = _requiredString(json, path);
  return switch (_normalized(value)) {
    'cover' => CinematicBackgroundFit.cover,
    'contain' => CinematicBackgroundFit.contain,
    'fill' => CinematicBackgroundFit.fill,
    'fitwidth' => CinematicBackgroundFit.fitWidth,
    'fitheight' => CinematicBackgroundFit.fitHeight,
    'none' => CinematicBackgroundFit.none,
    'scaledown' => CinematicBackgroundFit.scaleDown,
    _ => throw FormatException('$path has unknown background fit $value'),
  };
}

List<CinematicCharacterLayer> _legacyLayersForRole(
  Object? roleValue,
  String path,
) {
  if (roleValue == null) return const [];
  final role = _normalized(_requiredString(roleValue, path));
  if (role == 'opening') {
    return <CinematicCharacterLayer>[
      CinematicCharacterLayer(
        id: 'crown-bearer',
        source: const CinematicBuiltInCharacterSource(
          CinematicBuiltInCharacter.crownBearer,
        ),
        alignment: CinematicLayerAlignment(x: -.48, y: .62),
        size: CinematicLayerSize(width: 92, height: 138),
        semanticLabel: 'The crown-bearer',
        zOrder: 0,
      ),
    ];
  }
  if (role == 'finale') {
    return <CinematicCharacterLayer>[
      CinematicCharacterLayer(
        id: 'crown-bearer',
        source: const CinematicBuiltInCharacterSource(
          CinematicBuiltInCharacter.crownBearer,
        ),
        alignment: CinematicLayerAlignment(x: -.42, y: .65),
        size: CinematicLayerSize(width: 82, height: 123),
        semanticLabel: 'The crown-bearer',
        zOrder: 0,
      ),
      CinematicCharacterLayer(
        id: 'queen',
        source: const CinematicBuiltInCharacterSource(
          CinematicBuiltInCharacter.queen,
        ),
        alignment: CinematicLayerAlignment(x: .34, y: .55),
        size: CinematicLayerSize(width: 92, height: 145),
        mirrored: true,
        semanticLabel: 'The Queen',
        zOrder: 1,
      ),
    ];
  }
  return const [];
}

Map<String, Object?> _asMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$path must have string keys');
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}

List<Object?> _asList(Object? value, String path) {
  if (value is! List) throw FormatException('$path must be an array');
  return value.cast<Object?>();
}

String _requiredString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path must be a non-empty string');
  }
  return value;
}

String? _optionalString(Object? value, String path) =>
    value == null ? null : _requiredString(value, path);

int _int(Object? value, String path) {
  if (value is! int) throw FormatException('$path must be an integer');
  return value;
}

double _double(Object? value, String path) {
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$path must be a finite number');
  }
  return value.toDouble();
}

bool _bool(Object? value, String path) {
  if (value is! bool) throw FormatException('$path must be a boolean');
  return value;
}

void _validateNormalizedCoordinate(double value, String path) {
  if (!value.isFinite || value < -1 || value > 1) {
    throw FormatException('$path must be between -1 and 1');
  }
}

void _validatePositive(double value, String path) {
  if (!value.isFinite || value <= 0) {
    throw FormatException('$path must be positive');
  }
}

void _validateAssetPath(String path, String jsonPath) {
  final segments = path.split('/');
  if (path.trim().isEmpty ||
      path.startsWith('/') ||
      path.contains(r'\') ||
      segments.any((segment) => segment == '..')) {
    throw FormatException('$jsonPath is not a safe asset path');
  }
}

String _normalized(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
