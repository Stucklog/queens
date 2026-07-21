/// The shared crown-bearer finisher tracks currently authored in the bundled
/// combat atlas. Story packages select a track by stable name rather than by
/// chapter position, so a short arc can still use a climactic move and two arcs
/// do not have to share the same escalation curve.
enum CombatFinisherTrack {
  crownSlash('Crown Slash'),
  twinSigil('Twin Sigil'),
  skybreak('Skybreak'),
  tidalAegis('Tidal Aegis'),
  cinderfall('Cinderfall'),
  brassJudgment('Brass Judgment'),
  moonlitSever('Moonlit Sever'),
  regaliaNova('Regalia Nova');

  const CombatFinisherTrack(this.defaultMoveName);

  final String defaultMoveName;

  static CombatFinisherTrack parse(Object? value) {
    if (value is! String) {
      throw FormatException('Combat finisher must be a named track: $value');
    }
    return values.firstWhere(
      (track) => track.name == value,
      orElse: () => throw FormatException('Unknown combat finisher $value'),
    );
  }

  static CombatFinisherTrack forLegacyLevel(int level) =>
      values[level.clamp(1, values.length) - 1];
}

/// Content-owned choices applied to the shared encounter-victory renderer.
///
/// Timing and camera behavior remain centralized and tested. Packages choose
/// the authored move, its visible name, and effect intensity without copying
/// any animation widgets.
class CombatFinisherStyle {
  const CombatFinisherStyle({
    required this.track,
    required this.moveName,
    required this.effectLevel,
  });

  final CombatFinisherTrack track;
  final String moveName;
  final int effectLevel;

  factory CombatFinisherStyle.legacy(int spectacleLevel) {
    final level = spectacleLevel.clamp(1, 8);
    final track = CombatFinisherTrack.forLegacyLevel(level);
    return CombatFinisherStyle(
      track: track,
      moveName: track.defaultMoveName,
      effectLevel: level,
    );
  }

  factory CombatFinisherStyle.fromJson(
    Object? value, {
    required int legacySpectacleLevel,
  }) {
    final legacyTrack = CombatFinisherTrack.forLegacyLevel(
      legacySpectacleLevel,
    );
    if (value == null) {
      return CombatFinisherStyle.legacy(legacySpectacleLevel);
    }
    if (value is! Map<String, Object?>) {
      throw const FormatException('finisher must be an object');
    }
    final track =
        value['track'] == null
            ? legacyTrack
            : CombatFinisherTrack.parse(value['track']);
    final moveName = value['moveName'] as String? ?? track.defaultMoveName;
    final effectLevel =
        (value['effectLevel'] as num?)?.toInt() ??
        legacySpectacleLevel.clamp(1, 8);
    if (moveName.trim().isEmpty || effectLevel < 1 || effectLevel > 8) {
      throw FormatException(
        'Invalid combat finisher ${track.name}: $moveName/$effectLevel',
      );
    }
    return CombatFinisherStyle(
      track: track,
      moveName: moveName,
      effectLevel: effectLevel,
    );
  }
}
