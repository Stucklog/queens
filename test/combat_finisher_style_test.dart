import 'package:flutter_test/flutter_test.dart';
import 'package:regalia/app/combat_style.dart';
import 'package:regalia/app/journey.dart';

void main() {
  test('an encounter selects its finisher independently of story position', () {
    final boss = ChapterBoss.fromJson({
      'id': 'regalia:boss/moon-court/gate-warden',
      'name': 'Gate Warden',
      'puzzleId': 'regalia:puzzle/moon-court/easy-004',
      'spriteFamily': 'spectral',
      'spriteAsset': 'assets/art/combat/opponents/moon-gate-warden.png',
      'spectacleLevel': 1,
      'finisher': {
        'track': 'regaliaNova',
        'moveName': 'Moon-Court Nova',
        'effectLevel': 7,
      },
      'size': 4,
      'targetDifficulty': 'easy',
      'unlocks': 'regalia:unlock/moon-court/finale',
    });

    expect(boss.spectacleLevel, 1);
    expect(boss.finisherStyle.track, CombatFinisherTrack.regaliaNova);
    expect(boss.finisherStyle.moveName, 'Moon-Court Nova');
    expect(boss.finisherStyle.effectLevel, 7);
  });

  test('legacy encounters retain the established track mapping', () {
    expect(
      CombatFinisherStyle.fromJson(null, legacySpectacleLevel: 3).track,
      CombatFinisherTrack.skybreak,
    );
  });
}
