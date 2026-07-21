import '../app/journey.dart';
import '../core/models.dart';
import 'cinematic_scene_models.dart';
import 'content_ids.dart';
import 'entitlements.dart';

enum StorySceneRole { opening, chapter, finale }

class StoryScenePageContent {
  const StoryScenePageContent({
    required this.title,
    required this.paragraphs,
    required this.semanticLabel,
    required this.actionLabel,
  });

  final String title;
  final List<String> paragraphs;
  final String semanticLabel;
  final String actionLabel;

  factory StoryScenePageContent.fromJson(Map<String, Object?> json) {
    final title = json['title']! as String;
    final paragraphs = List<String>.unmodifiable(
      (json['paragraphs']! as List<Object?>).cast<String>(),
    );
    final semanticLabel = json['semanticLabel']! as String;
    final actionLabel = json['actionLabel']! as String;
    if (title.trim().isEmpty ||
        paragraphs.isEmpty ||
        paragraphs.any((paragraph) => paragraph.trim().isEmpty) ||
        semanticLabel.trim().isEmpty ||
        actionLabel.trim().isEmpty) {
      throw const FormatException('Story scene pages cannot be empty');
    }
    return StoryScenePageContent(
      title: title,
      paragraphs: paragraphs,
      semanticLabel: semanticLabel,
      actionLabel: actionLabel,
    );
  }
}

class StorySceneContent {
  StorySceneContent({
    required this.id,
    required this.role,
    required this.presentation,
  }) : pages = List<StoryScenePageContent>.unmodifiable(
         presentation.frames.map(
           (frame) => StoryScenePageContent(
             title: frame.narrative.title,
             paragraphs: frame.narrative.paragraphs,
             semanticLabel: frame.narrative.semanticLabel,
             actionLabel: frame.narrative.actionLabel,
           ),
         ),
       );

  final String id;
  final StorySceneRole role;
  final List<StoryScenePageContent> pages;
  final CinematicScenePresentation presentation;

  List<CinematicSceneFrame> get frames => presentation.frames;
  String get artAsset => frames.first.background.asset;

  Set<String> get assetPaths => {
    for (final frame in frames) ...[
      frame.background.asset,
      for (final layer in frame.characterLayers)
        if (layer.source case CinematicAssetCharacterSource(:final asset))
          asset,
    ],
  };

  String get title => pages.first.title;
  String get caption => pages.first.paragraphs.join('\n\n');
  String get semanticLabel => pages.first.semanticLabel;
  String get actionLabel => pages.first.actionLabel;

  factory StorySceneContent.fromJson(Map<String, Object?> json) {
    final id = json['id']! as String;
    ContentId.parse(id, expectedKind: 'scene');
    return StorySceneContent(
      id: id,
      role: StorySceneRole.values.firstWhere(
        (value) => value.name == json['role'],
        orElse: () => throw FormatException('Unknown scene role for $id'),
      ),
      presentation: CinematicScenePresentation.fromJson(json),
    );
  }
}

class ArcUnlockIds {
  const ArcUnlockIds({required this.fullMap, required this.finale});

  final String fullMap;
  final String finale;

  factory ArcUnlockIds.fromJson(Map<String, Object?> json) {
    final fullMap = json['fullMap']! as String;
    final finale = json['finale']! as String;
    ContentId.parse(fullMap, expectedKind: 'unlock');
    ContentId.parse(finale, expectedKind: 'unlock');
    return ArcUnlockIds(fullMap: fullMap, finale: finale);
  }
}

class StoryArc {
  StoryArc({
    required this.id,
    required this.contentVersion,
    required this.title,
    required this.mapId,
    required this.unlockIds,
    required List<JourneyChapter> chapters,
    required List<StorySceneContent> scenes,
    required this.catalog,
  }) : chapters = List.unmodifiable(chapters),
       scenes = List.unmodifiable(scenes) {
    _validate();
  }

  final String id;
  final int contentVersion;
  final String title;
  final String mapId;
  final ArcUnlockIds unlockIds;
  final List<JourneyChapter> chapters;
  final List<StorySceneContent> scenes;
  final PuzzleCatalog catalog;

  StorySceneContent get openingScene =>
      scenes.firstWhere((scene) => scene.role == StorySceneRole.opening);
  StorySceneContent get finaleScene =>
      scenes.firstWhere((scene) => scene.role == StorySceneRole.finale);

  Iterable<CombatEncounter> get combatEncounters sync* {
    for (final chapter in chapters) {
      yield chapter.boss;
      yield* chapter.encounters;
    }
  }

  StorySceneContent sceneById(String id) =>
      scenes.firstWhere((scene) => scene.id == id);

  JourneyChapter chapterForOrder(int order) => chapters.firstWhere(
    (chapter) => chapter.contains(order),
    orElse: () => chapters.last,
  );

  ChapterBoss? bossForPuzzle(PuzzleDefinition puzzle) {
    for (final chapter in chapters) {
      if (chapter.boss.puzzleId == puzzle.id) return chapter.boss;
    }
    return null;
  }

  CombatEncounter? encounterForPuzzle(PuzzleDefinition puzzle) {
    for (final chapter in chapters) {
      if (chapter.boss.puzzleId == puzzle.id) return chapter.boss;
      for (final encounter in chapter.encounters) {
        if (encounter.puzzleId == puzzle.id) return encounter;
      }
    }
    return null;
  }

  void _validate() {
    final arc = ContentId.parse(id, expectedKind: 'arc');
    final map = ContentId.parse(mapId, expectedKind: 'map');
    if (arc.path.length != 1 ||
        contentVersion < 1 ||
        chapters.isEmpty ||
        catalog.puzzles.isEmpty) {
      throw FormatException('$id is an empty or invalid story arc');
    }
    if (map.arcName != arc.localName) {
      throw FormatException('$mapId does not belong to $id');
    }
    var nextOrder = 1;
    final ids = <String>{id, mapId, unlockIds.fullMap, unlockIds.finale};
    for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final chapter = chapters[chapterIndex];
      final chapterId = ContentId.parse(chapter.id, expectedKind: 'chapter');
      final sceneId = ContentId.parse(chapter.sceneId, expectedKind: 'scene');
      if (chapterId.arcName != arc.localName ||
          sceneId.arcName != arc.localName ||
          chapter.mapId != mapId ||
          chapter.startOrder != nextOrder ||
          chapter.endOrder < chapter.startOrder ||
          !ids.add(chapter.id)) {
        throw FormatException('Invalid chapter sequence in $id');
      }
      nextOrder = chapter.endOrder + 1;
    }
    for (final scene in scenes) {
      final sceneId = ContentId.parse(scene.id, expectedKind: 'scene');
      if (sceneId.arcName != arc.localName || !ids.add(scene.id)) {
        throw FormatException('Invalid or duplicate scene ${scene.id}');
      }
    }
    if (scenes.where((scene) => scene.role == StorySceneRole.opening).length !=
            1 ||
        scenes.where((scene) => scene.role == StorySceneRole.finale).length !=
            1 ||
        chapters.any((chapter) => !ids.contains(chapter.sceneId))) {
      throw FormatException('$id has incomplete story scenes');
    }
    final finalOrder = chapters.last.endOrder;
    if (catalog.puzzles.length != finalOrder) {
      throw FormatException(
        '$id expects $finalOrder puzzles, found ${catalog.puzzles.length}',
      );
    }
    for (var index = 0; index < catalog.puzzles.length; index++) {
      final puzzle = catalog.puzzles[index];
      final puzzleId = ContentId.parse(puzzle.id, expectedKind: 'puzzle');
      if (puzzleId.arcName != arc.localName ||
          puzzle.order != index + 1 ||
          !ids.add(puzzle.id)) {
        throw FormatException('Invalid puzzle sequence in $id at ${puzzle.id}');
      }
    }
    for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final chapter = chapters[chapterIndex];
      final boss = chapter.boss;
      final bossId = ContentId.parse(boss.id, expectedKind: 'boss');
      final bossPuzzleId = ContentId.parse(
        boss.puzzleId,
        expectedKind: 'puzzle',
      );
      final expectedUnlockTarget =
          chapterIndex + 1 < chapters.length
              ? chapters[chapterIndex + 1].id
              : unlockIds.finale;
      final expectedDifficulty =
          chapterIndex + 1 < chapters.length
              ? chapters[chapterIndex + 1].difficulty
              : chapter.difficulty;
      final unlockTarget = ContentId.parse(boss.unlockTargetId);
      final puzzle = catalog.puzzles[chapter.endOrder - 1];
      if (bossId.arcName != arc.localName ||
          bossPuzzleId.arcName != arc.localName ||
          unlockTarget.arcName != arc.localName ||
          !ids.add(boss.id) ||
          boss.name.trim().isEmpty ||
          !_isCombatSpriteAsset(boss.spriteAsset, arc.localName) ||
          boss.spectacleLevel < 1 ||
          boss.spectacleLevel > 8 ||
          boss.finisherStyle.effectLevel < 1 ||
          boss.finisherStyle.effectLevel > 8 ||
          boss.unlockTargetId != expectedUnlockTarget ||
          boss.targetDifficulty != expectedDifficulty ||
          boss.puzzleId != puzzle.id ||
          boss.size != puzzle.size ||
          boss.targetDifficulty != puzzle.tier) {
        throw FormatException('Invalid boss ${boss.id} for ${chapter.id}');
      }

      final encounterPuzzleIds = <String>{};
      for (final encounter in chapter.encounters) {
        final encounterId = ContentId.parse(
          encounter.id,
          expectedKind: 'enemy',
        );
        final encounterPuzzleId = ContentId.parse(
          encounter.puzzleId,
          expectedKind: 'puzzle',
        );
        final encounterPuzzle = catalog.byId(encounter.puzzleId);
        if (encounterId.arcName != arc.localName ||
            encounterPuzzleId.arcName != arc.localName ||
            !ids.add(encounter.id) ||
            !encounterPuzzleIds.add(encounter.puzzleId) ||
            encounter.name.trim().isEmpty ||
            !_isCombatSpriteAsset(encounter.spriteAsset, arc.localName) ||
            encounter.isBoss ||
            encounter.spectacleLevel != 1 ||
            !chapter.contains(encounterPuzzle.order) ||
            encounter.puzzleId == boss.puzzleId) {
          throw FormatException(
            'Invalid encounter ${encounter.id} for ${chapter.id}',
          );
        }
      }
    }
    final spriteAssets = combatEncounters.map(
      (encounter) => encounter.spriteAsset,
    );
    if (spriteAssets.toSet().length != spriteAssets.length) {
      throw FormatException('$id reuses opponent sprite art within the arc');
    }
  }
}

bool _isCombatSpriteAsset(String path, String arcName) =>
    path.startsWith(
      arcName == 'origin'
          ? 'assets/art/combat/opponents/'
          : 'assets/art/arcs/$arcName/combat/opponents/',
    ) &&
    path.endsWith('.png') &&
    !path.contains('..');

class ArcStorefrontTheme {
  const ArcStorefrontTheme({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final int backgroundColor;
  final int surfaceColor;
  final int primaryColor;
  final int secondaryColor;

  factory ArcStorefrontTheme.fromJson(
    Map<String, Object?> json,
  ) => ArcStorefrontTheme(
    backgroundColor: _parseStorefrontColor(
      json['backgroundColor'],
      'backgroundColor',
    ),
    surfaceColor: _parseStorefrontColor(json['surfaceColor'], 'surfaceColor'),
    primaryColor: _parseStorefrontColor(json['primaryColor'], 'primaryColor'),
    secondaryColor: _parseStorefrontColor(
      json['secondaryColor'],
      'secondaryColor',
    ),
  );
}

int _parseStorefrontColor(Object? source, String name) {
  final value = source as String?;
  if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw FormatException('Invalid storefront $name color $value');
  }
  return int.parse('ff${value.substring(1)}', radix: 16);
}

class ArcStorefrontContent {
  const ArcStorefrontContent({
    required this.title,
    required this.tileSubtitle,
    required this.lockedTileSubtitle,
    required this.tileArtAsset,
    required this.tileForegroundAsset,
    required this.theme,
    required this.prologuePreview,
  });

  final String title;
  final String tileSubtitle;
  final String lockedTileSubtitle;
  final String tileArtAsset;
  final String? tileForegroundAsset;

  final ArcStorefrontTheme theme;
  final StorySceneContent prologuePreview;

  factory ArcStorefrontContent.fromJson(Map<String, Object?> json) {
    final title = json['title']! as String;
    final tileSubtitle = json['tileSubtitle']! as String;
    final lockedTileSubtitle = json['lockedTileSubtitle']! as String;
    final tileArtAsset = json['tileArtAsset']! as String;
    final tileForegroundAsset = json['tileForegroundAsset'] as String?;
    if (title.trim().isEmpty ||
        tileSubtitle.trim().isEmpty ||
        lockedTileSubtitle.trim().isEmpty) {
      throw const FormatException(
        'Storefront copy and visuals cannot be empty',
      );
    }
    _validateStorefrontAsset(tileArtAsset);
    if (tileForegroundAsset != null) {
      _validateStorefrontAsset(tileForegroundAsset);
    }
    return ArcStorefrontContent(
      title: title,
      tileSubtitle: tileSubtitle,
      lockedTileSubtitle: lockedTileSubtitle,
      tileArtAsset: tileArtAsset,
      tileForegroundAsset: tileForegroundAsset,
      theme: ArcStorefrontTheme.fromJson(
        json['theme']! as Map<String, Object?>,
      ),
      prologuePreview: StorySceneContent.fromJson(
        json['prologuePreview']! as Map<String, Object?>,
      ),
    );
  }
}

void _validateStorefrontAsset(String path) {
  if (!path.startsWith('assets/') || path.contains('..')) {
    throw FormatException('Invalid storefront asset $path');
  }
}

class StorefrontLinks {
  const StorefrontLinks({required this.appStore, required this.playStore});

  final Uri appStore;
  final Uri playStore;

  factory StorefrontLinks.fromJson(Map<String, Object?> json) =>
      StorefrontLinks(
        appStore: _parseStorefrontLink(json['appStore'], 'App Store'),
        playStore: _parseStorefrontLink(json['playStore'], 'Play Store'),
      );
}

Uri _parseStorefrontLink(Object? source, String name) {
  final uri = source is String ? Uri.tryParse(source) : null;
  final allowedHosts = switch (name) {
    'App Store' => const {'apps.apple.com'},
    'Play Store' => const {'play.google.com'},
    _ => const <String>{},
  };
  if (uri == null ||
      uri.scheme != 'https' ||
      !allowedHosts.contains(uri.host.toLowerCase())) {
    throw FormatException('Invalid $name link $source');
  }
  return uri;
}

class ArcPackageDescriptor {
  const ArcPackageDescriptor({
    required this.arcId,
    required this.metadataAsset,
    required this.entitlementId,
    required this.channels,
    required this.lockedPreviewChannels,
    required this.storefront,
  });

  final String arcId;
  final String metadataAsset;
  final String entitlementId;
  final Set<ReleaseChannel> channels;
  final Set<ReleaseChannel> lockedPreviewChannels;
  final ArcStorefrontContent storefront;

  factory ArcPackageDescriptor.fromJson(Map<String, Object?> json) {
    final arcId = json['arcId']! as String;
    final entitlementId = json['entitlementId']! as String;
    ContentId.parse(arcId, expectedKind: 'arc');
    ContentId.parse(entitlementId, expectedKind: 'entitlement');
    final channels =
        (json['channels']! as List<Object?>)
            .map(
              (value) => ReleaseChannel.values.firstWhere(
                (channel) => channel.name == value,
                orElse:
                    () =>
                        throw FormatException('Unknown release channel $value'),
              ),
            )
            .toSet();
    if (channels.isEmpty) {
      throw FormatException('$arcId has no release channel');
    }
    final lockedPreviewChannels =
        (json['lockedPreviewChannels'] as List<Object?>? ?? const [])
            .map(
              (value) => ReleaseChannel.values.firstWhere(
                (channel) => channel.name == value,
                orElse:
                    () =>
                        throw FormatException(
                          'Unknown locked-preview channel $value',
                        ),
              ),
            )
            .toSet();
    final conflictingChannels = channels.intersection(lockedPreviewChannels);
    if (conflictingChannels.isNotEmpty) {
      throw FormatException(
        '$arcId cannot be both available and locked on $conflictingChannels',
      );
    }
    final storefront = ArcStorefrontContent.fromJson(
      json['storefront']! as Map<String, Object?>,
    );
    final arcName = ContentId.parse(arcId, expectedKind: 'arc').localName;
    final previewId = ContentId.parse(
      storefront.prologuePreview.id,
      expectedKind: 'scene',
    );
    if (previewId.arcName != arcName ||
        storefront.prologuePreview.role != StorySceneRole.opening) {
      throw FormatException('$arcId has an invalid storefront prologue');
    }
    return ArcPackageDescriptor(
      arcId: arcId,
      metadataAsset: json['metadataAsset']! as String,
      entitlementId: entitlementId,
      channels: Set.unmodifiable(channels),
      lockedPreviewChannels: Set.unmodifiable(lockedPreviewChannels),
      storefront: storefront,
    );
  }
}

enum ContentAvailabilityStatus {
  available,
  notEntitled,
  notInEdition,
  missingPackage,
  invalidPackage,
  notPackaged,
}

class ArcAvailability {
  const ArcAvailability({
    required this.status,
    this.descriptor,
    this.arc,
    this.error,
  });

  final ContentAvailabilityStatus status;
  final ArcPackageDescriptor? descriptor;
  final StoryArc? arc;
  final Object? error;

  bool get isAvailable => status == ContentAvailabilityStatus.available;
  ArcStorefrontContent? get storefront => descriptor?.storefront;
}

class ContentRegistry {
  ContentRegistry({
    required Map<String, ArcAvailability> arcs,
    required this.justPuzzleAvailable,
    this.storefrontLinks,
  }) : arcs = Map.unmodifiable(arcs);

  final Map<String, ArcAvailability> arcs;
  final bool justPuzzleAvailable;
  final StorefrontLinks? storefrontLinks;

  Iterable<ArcAvailability> get arcEntries => arcs.values;

  Iterable<StoryArc> get availableArcs => arcs.values
      .where((entry) => entry.isAvailable)
      .map((entry) => entry.arc!);

  StoryArc? arc(String id) => arcs[id]?.arc;

  ArcAvailability availabilityFor(String id) =>
      arcs[id] ??
      const ArcAvailability(status: ContentAvailabilityStatus.notPackaged);
}
