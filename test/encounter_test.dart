import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/game/lore_map_manager.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _FixedRandom implements Random {
  final int value;
  final List<int> bounds = [];
  _FixedRandom(this.value);

  @override
  int nextInt(int max) {
    bounds.add(max);
    return value.clamp(0, max - 1);
  }

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  test('일반 조우의 선공은 이름 있는 대원과 적의 정수 평균 민첩성으로 정한다', () {
    final source = File('repo_source/LORE_1993_src/LOREBATT.PAS')
        .readAsStringSync(encoding: latin1);
    final encounter = source.split('Procedure EncounterEnemy;').last;
    expect(
      encounter,
      contains('if k > i then assualt := TRUE else assualt := FALSE;'),
    );

    final party = [
      PartyMember.createPreset(1)..agility = 10,
      PartyMember.createPreset(2)..agility = 11,
      PartyMember.createPreset(3)
        ..name = ''
        ..agility = 99,
    ];
    final enemies = [Monster.create(1)..agility = 10];
    expect(LoreEncounterLogic.enemyActsFirst(party, enemies), isTrue);
    party[1].agility = 13;
    expect(LoreEncounterLogic.enemyActsFirst(party, enemies), isFalse);
    enemies.first.agility = 12;
    expect(LoreEncounterLogic.enemyActsFirst(party, enemies), isTrue);
    expect(LoreEncounterLogic.enemyActsFirst([], enemies), isFalse);
  });

  test('전투 전 도주는 대원의 평균 행운이 적 민첩성보다 높을 때 성공한다', () {
    final source = File('repo_source/LORE_1993_src/LOREBATT.PAS')
        .readAsStringSync(encoding: latin1)
        .split('Procedure EncounterEnemy;')
        .last;
    expect(source, contains('j := j + 1; h := h + luck;'));
    expect(source, contains('if k > i then begin'));

    final party = [
      PartyMember.createPreset(1)..luck = 10,
      PartyMember.createPreset(2)..luck = 11,
      PartyMember.createPreset(3)
        ..name = ''
        ..luck = 99,
    ];
    final enemies = [Monster.create(1)..agility = 10];
    expect(LoreEncounterLogic.canEvadeBeforeBattle(party, enemies), isFalse);
    party[1].luck = 13;
    expect(LoreEncounterLogic.canEvadeBeforeBattle(party, enemies), isTrue);
    enemies.first.agility = 11;
    expect(LoreEncounterLogic.canEvadeBeforeBattle(party, enemies), isFalse);
    expect(LoreEncounterLogic.canEvadeBeforeBattle([], enemies), isFalse);
  });

  test('일반 조우 몬스터 표가 LOREBATT.PAS와 일치한다', () {
    final source = File('repo_source/LORE_1993_src/LOREBATT.PAS')
        .readAsStringSync(encoding: latin1);
    final section = source
        .split('Procedure randomenemy(var enemynumber: integer);')
        .last
        .split('Procedure EncounterEnemy;')
        .first;
    final pattern = RegExp(
      r'(\d+)\s*:\s*begin range := (\d+); plus := (\d+); end;',
    );
    final original = <int, (int, int)>{};
    for (final match in pattern.allMatches(section)) {
      final mapId = int.parse(match[1]!);
      final range = int.parse(match[2]!);
      final plus = int.parse(match[3]!);
      original[mapId] = (plus, plus + range - 1);
    }
    expect(LoreEncounterLogic.pools, original);
    expect(LoreEncounterLogic.pools.containsKey(13), isFalse);
    expect(LoreEncounterLogic.pools.containsKey(21), isFalse);
  });

  test('조우율과 적 수는 원작의 이동 방식과 옵션 범위를 따른다', () {
    final walking = _FixedRandom(0);
    expect(
      LoreEncounterLogic.shouldEncounter(1, TileCategory.walkable, walking),
      isTrue,
    );
    expect(walking.bounds, [40]); // 기본 encounter=2, Move_Mode: *20

    final water = _FixedRandom(0);
    expect(
      LoreEncounterLogic.shouldEncounter(1, TileCategory.water, water),
      isTrue,
    );
    expect(water.bounds, [60]); // enter_water: *30

    final noRoll = _FixedRandom(0);
    expect(
      LoreEncounterLogic.shouldEncounter(1, TileCategory.swamp, noRoll),
      isFalse,
    );
    expect(
      LoreEncounterLogic.shouldEncounter(13, TileCategory.walkable, noRoll),
      isFalse,
    );
    expect(noRoll.bounds, isEmpty);

    final low = _FixedRandom(0);
    expect(LoreEncounterLogic.rollMonsters(18, low), [30]);
    expect(low.bounds, [5, 3]);
    final high = _FixedRandom(999);
    expect(
      LoreEncounterLogic.rollMonsters(18, high, maxEnemies: 7),
      List.filled(7, 32),
    );
    expect(high.bounds.first, 7);
  });

  test('FOEDATA.DAT 75종이 JSON 몬스터와 바이트 필드별로 일치한다', () {
    final bytes = File('repo_source/LORE_1993_runtime/FOEDATA.DAT')
        .readAsBytesSync();
    final monsters =
        (jsonDecode(File('assets/data/monsters.json').readAsStringSync())
                as Map<String, dynamic>)['monsters']
            as List<dynamic>;
    const fields = [
      'strength',
      'mentality',
      'endurance',
      'resistance',
      'agility',
      'accArms',
      'accMagic',
      'ac',
      'special',
      'castLevel',
      'specialCastLevel',
      'level',
    ];
    expect(bytes.length, 75 * 29);
    expect(monsters.length, 75);
    for (var i = 0; i < 75; i++) {
      final base = i * 29;
      final monster = monsters[i] as Map<String, dynamic>;
      expect(monster['eNumber'], i + 1);
      expect(
        monster['name'],
        ascii.decode(bytes.sublist(base + 1, base + 1 + bytes[base])),
      );
      for (var n = 0; n < fields.length; n++) {
        expect(
          monster[fields[n]],
          bytes[base + 17 + n],
          reason: 'monster ${i + 1} ${fields[n]}',
        );
      }
    }
  });
}
