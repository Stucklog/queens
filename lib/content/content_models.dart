import '../app/journey.dart';
import '../core/models.dart';
import 'content_ids.dart';
import 'entitlements.dart';

enum StorySceneRole { opening, chapter, finale }

class StorySceneContent {
  const StorySceneContent({
    required this.id,
    required this.role,
    required this.title,
    required this.caption,
    required this.semanticLabel,
    required this.actionLabel,
    required this.artAsset,
  });

  final String id;
  final StorySceneRole role;
  final String title;
  final String caption;
  final String semanticLabel;
  final String actionLabel;
  final String artAsset;

  factory StorySceneContent.fromJson(Map<String, Object?> json) {
    final id = json['id']! as String;
    ContentId.parse(id, expectedKind: 'scene');
    return StorySceneContent(
      id: id,
      role: StorySceneRole.values.firstWhere(
        (value) => value.name == json['role'],
        orElse: () => throw FormatException('Unknown scene role for $id'),
      ),
      title: json['title']! as String,
      caption: json['caption']! as String,
      semanticLabel: json['semanticLabel']! as String,
      actionLabel: json['actionLabel']! as String,
      artAsset: json['artAsset']! as String,
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
          !_isCombatSpriteAsset(boss.spriteAsset) ||
          boss.spectacleLevel != chapterIndex + 1 ||
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
            encounter.rewardLabel.trim().isEmpty ||
            !_isCombatSpriteAsset(encounter.spriteAsset) ||
            !encounter.skippable ||
            encounter.isBoss ||
            encounter.spectacleLevel != 1 ||
            !chapter.contains(encounterPuzzle.order) ||
            encounter.puzzleId == boss.puzzleId) {
          throw FormatException(
            'Invalid optional encounter ${encounter.id} for ${chapter.id}',
          );
        }
      }
    }
  }
}

bool _isCombatSpriteAsset(String path) =>
    path.startsWith('assets/art/combat/opponents/') &&
    path.endsWith('.png') &&
    !path.contains('..');

class ArcPackageDescriptor {
  const ArcPackageDescriptor({
    required this.arcId,
    required this.metadataAsset,
    required this.entitlementId,
    required this.channels,
  });

  final String arcId;
  final String metadataAsset;
  final String entitlementId;
  final Set<ReleaseChannel> channels;

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
    return ArcPackageDescriptor(
      arcId: arcId,
      metadataAsset: json['metadataAsset']! as String,
      entitlementId: entitlementId,
      channels: Set.unmodifiable(channels),
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
  const ArcAvailability({required this.status, this.arc, this.error});

  final ContentAvailabilityStatus status;
  final StoryArc? arc;
  final Object? error;

  bool get isAvailable => status == ContentAvailabilityStatus.available;
}

class ContentRegistry {
  ContentRegistry({
    required Map<String, ArcAvailability> arcs,
    required this.justPuzzleAvailable,
  }) : arcs = Map.unmodifiable(arcs);

  final Map<String, ArcAvailability> arcs;
  final bool justPuzzleAvailable;

  Iterable<StoryArc> get availableArcs => arcs.values
      .where((entry) => entry.isAvailable)
      .map((entry) => entry.arc!);

  StoryArc? arc(String id) => arcs[id]?.arc;

  ArcAvailability availabilityFor(String id) =>
      arcs[id] ??
      const ArcAvailability(status: ContentAvailabilityStatus.notPackaged);
}
