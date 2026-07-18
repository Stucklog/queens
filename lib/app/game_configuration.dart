/// Build-time gameplay switches that deliberately do not change the settings
/// UI or become player preferences.
abstract final class GameConfiguration {
  /// When true, Settings -> Unlock Game Board also grants the arc finale.
  ///
  /// Enable with:
  /// `--dart-define=REGALIA_UNLOCK_FINALE_WITH_GAME_BOARD=true`.
  static const unlockFinaleWithGameBoard = bool.fromEnvironment(
    'REGALIA_UNLOCK_FINALE_WITH_GAME_BOARD',
    defaultValue: false,
  );
}
