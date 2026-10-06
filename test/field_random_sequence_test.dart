import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_game.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/logic/lore_swamp_logic.dart';
import 'package:lore/models/party_member.dart';

class _RecordingRandom implements Random {
  final List<int> bounds = [];

  @override
  int nextInt(int max) {
    bounds.add(max);
    return 0;
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('용암→늪→일반 조우·몬스터 편성이 한 난수열을 순서대로 소비한다', () {
    final random = _RecordingRandom();
    final party = [
      for (var i = 0; i < 6; i++) PartyMember.createPreset(1)..luck = 10,
    ];
    final grid = List.generate(20, (_) => List.filled(20, 42));
    grid[5][6] = 50; // ground lava at (7, 6)
    grid[5][7] = 49; // ground swamp at (8, 6)
    final map = LoreMapData(
      name: 'TEST',
      category: 'ground',
      xmax: 20,
      ymax: 20,
      grid: grid,
    );
    List<int>? monsters;
    final game = LoreGame(
      initialMapId: 1,
      initialPlayerX: 6,
      initialPlayerY: 6,
      random: random,
      onHazardTile: (tile) {
        switch (tile) {
          case TileCategory.lava:
            LoreLavaLogic.rollDamages(party, random);
          case TileCategory.swamp:
            LoreSwampLogic.rollPoisonedSlots(party, random);
          default:
            break;
        }
      },
      onEncounter: () => monsters = LoreEncounterLogic.rollMonsters(1, random),
    )..currentMap = map;

    expect(game.tryMove(1, 0), isTrue);
    expect(game.tryMove(1, 0), isTrue);
    expect(monsters, isNull);
    expect(game.tryMove(1, 0), isTrue);
    expect(monsters, [1]);
    expect(random.bounds, [
      for (var i = 0; i < 6; i++) ...[10, 40],
      for (var i = 0; i < 6; i++) 20,
      40, // Move_Mode encounter probability
      5, // number of enemies
      10, // GROUND1 monster range
    ]);
  });
}
