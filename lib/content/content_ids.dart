/// Canonical identifiers shared by content, unlocks, and persisted state.
///
/// IDs use `namespace:kind/path` so independently authored arcs cannot collide.
/// The first path segment of arc-owned content is the arc's local name.
class ContentId {
  ContentId._(this.value, this.namespace, this.kind, this.path);

  final String value;
  final String namespace;
  final String kind;
  final List<String> path;

  String get localName => path.last;
  String get arcName => path.first;

  static final _part = RegExp(r'^[a-z][a-z0-9.-]*$');

  factory ContentId.parse(String value, {String? expectedKind}) {
    final separator = value.indexOf(':');
    final slash = value.indexOf('/', separator + 1);
    if (separator <= 0 || slash <= separator + 1 || slash == value.length - 1) {
      throw FormatException('Invalid namespaced content ID: $value');
    }
    final namespace = value.substring(0, separator);
    final kind = value.substring(separator + 1, slash);
    final path = value.substring(slash + 1).split('/');
    if (!_part.hasMatch(namespace) ||
        !_part.hasMatch(kind) ||
        path.any((part) => !_part.hasMatch(part))) {
      throw FormatException('Invalid namespaced content ID: $value');
    }
    if (expectedKind != null && kind != expectedKind) {
      throw FormatException('$value must be a $expectedKind ID');
    }
    return ContentId._(value, namespace, kind, List.unmodifiable(path));
  }

  static bool isValid(String value, {String? kind}) {
    try {
      ContentId.parse(value, expectedKind: kind);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool belongsToArc(String value, String arcId, {String? kind}) {
    try {
      final content = ContentId.parse(value, expectedKind: kind);
      final arc = ContentId.parse(arcId, expectedKind: 'arc');
      return arc.path.length == 1 &&
          content.namespace == arc.namespace &&
          content.arcName == arc.localName;
    } on FormatException {
      return false;
    }
  }

  @override
  String toString() => value;
}

abstract final class ContentIds {
  static const originArc = 'regalia:arc/origin';
  static const originMap = 'regalia:map/origin/pilgrimage';
  static const originOpeningScene = 'regalia:scene/origin/opening';
  static const originFinaleScene = 'regalia:scene/origin/finale';
  static const originFullMapUnlock = 'regalia:unlock/origin/full-map';
  static const originFinaleUnlock = 'regalia:unlock/origin/finale';
  static const originEntitlement = 'regalia:entitlement/base/origin';
  static const justPuzzleEntitlement = 'regalia:entitlement/base/just-puzzle';
  static const justPuzzleFeature = 'regalia:feature/just-puzzle';
  static const tutorialPuzzle = 'regalia:puzzle/system/guided-tutorial';

  static String originPuzzle(String legacyId) {
    if (ContentId.isValid(legacyId, kind: 'puzzle')) return legacyId;
    final local =
        legacyId.startsWith('regalia-')
            ? legacyId.substring('regalia-'.length)
            : legacyId;
    return 'regalia:puzzle/origin/$local';
  }

  static String originScene(String legacyId) {
    if (ContentId.isValid(legacyId, kind: 'scene')) return legacyId;
    if (legacyId.startsWith('chapter.')) {
      return 'regalia:scene/origin/${legacyId.substring('chapter.'.length)}';
    }
    return 'regalia:scene/origin/$legacyId';
  }

  static String justPuzzle(int seed, int number) =>
      'regalia:puzzle/just-puzzle/run-${seed.toRadixString(16)}/board-${number.toString().padLeft(5, '0')}';

  static String migratePuzzleId(String id) {
    if (id == 'guided-tutorial') return tutorialPuzzle;
    if (id.startsWith('challenge-')) {
      final match = RegExp(r'^challenge-([0-9a-f]+)-(\d+)$').firstMatch(id);
      if (match != null) {
        return 'regalia:puzzle/just-puzzle/run-${match.group(1)}/board-${match.group(2)}';
      }
    }
    return originPuzzle(id);
  }
}

/// Active save keys are content IDs too. Legacy keys are read only by the
/// migration in [AppController].
abstract final class SaveIds {
  static String forArc(String arcId, String slot) {
    final arc = ContentId.parse(arcId, expectedKind: 'arc');
    final scope =
        arc.namespace == 'regalia'
            ? arc.localName
            : '${arc.namespace}.${arc.localName}';
    if (arc.path.length != 1 ||
        !ContentId.isValid('regalia:save/$scope/$slot', kind: 'save')) {
      throw FormatException('Invalid save slot $slot for $arcId');
    }
    return 'regalia:save/$scope/$slot';
  }

  static const migrationVersion = 'regalia:save/global/migration-version';
  static const settings = 'regalia:save/global/settings';
  static const tutorialComplete = 'regalia:save/global/tutorial-complete';
  static const supportPromptedChapters =
      'regalia:save/global/support-prompted-chapters';
  static const unlockedContentIds = 'regalia:save/global/unlocks';
  static const originBoards = 'regalia:save/origin/boards';
  static const originRecords = 'regalia:save/origin/records';
  static const originLastPuzzle = 'regalia:save/origin/last-puzzle';
  static const originSeenScenes = 'regalia:save/origin/seen-scenes';
  // Read only while migrating builds that briefly stored this boolean.
  static const originFullMap = 'regalia:save/origin/full-map';
  static const originCatalogFingerprint =
      'regalia:save/origin/catalog-fingerprint';
  static const justPuzzleSession = 'regalia:save/just-puzzle/session';
  static const justPuzzleDiversity = 'regalia:save/just-puzzle/diversity';
  static const justPuzzleRetries = 'regalia:save/just-puzzle/retries';
  static const academyBoards = 'regalia:save/academy/boards';
  static const academyCompletedLessons =
      'regalia:save/academy/completed-lessons';
}
