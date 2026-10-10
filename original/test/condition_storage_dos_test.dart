import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/data/lore_script.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_encounter_logic.dart';
import 'package:lore/logic/lore_lava_logic.dart';
import 'package:lore/logic/lore_main_procedures.dart';
import 'package:lore/logic/lore_spec_procedures.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/logic/script_party_reducer.dart';
import 'package:lore/logic/script_world_reducer.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Zero implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

class _Shop implements LoreShopIo {
  final List<int> answers = [1, 3, 0];
  @override
  int gold = 2147483647;
  @override
  int food = 10;
  @override
  void clear() {}
  @override
  void print(int color, String text) {}
  @override
  Future<void> pressAnyKey() async {}
  @override
  void displayCondition() {}
  @override
  Future<int> select(
    String title,
    List<String> items, {
    int? maxsum,
    required bool clean,
  }) async => answers.removeAt(0);
}

PartyMember player(dynamic r) => PartyMember.createPreset(1)
  ..name = 'Hero'
  ..endurance = r['endurance']
  ..battleLevel = r['level']
  ..hp = r['hp'] ?? 10
  ..unconscious = r['unconscious'] ?? 0
  ..dead = r['dead'] ?? 0;
Map<String, int> state(PartyMember p) => {
  'hp': p.hp,
  'unconscious': p.unconscious,
  'dead': p.dead,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = jsonDecode(
    File('test/fixtures/dos_condition_storage.json').readAsStringSync(),
  );
  for (final r in f['conditions']) {
    test(
      'native ReturnCondition ${r['endurance']} x ${r['level']} ${r['unconscious']} ${r['dead']}',
      () {
        final p = player(r);
        p.returnCondition();
        expect(state(p), r['after']);
      },
    );
  }
  for (final r in f['poisons']) {
    test(
      'native swamp/movement poison ${r['endurance']} x ${r['level']} ${r['unconscious']} ${r['dead']}',
      () {
        final p = player(r)..poison = 10;
        expect(LoreMainProcedures.advancePoison([p]), 1);
        expect(p.poison, 1);
        expect(state(p), r['after']);
      },
    );
  }
  for (final r in f['lava']) {
    test(
      'native lava unconscious cap ${r['endurance']} x ${r['level']} ${r['unconscious']} damage${r['damage']}',
      () {
        final p = player(r);
        LoreLavaLogic.applyDamage(p, r['damage']);
        expect(state(p), r['after']);
      },
    );
  }
  for (final (i, r) in (f['revivals'] as List).indexed) {
    test('native RevitalizeOne cap $i', () {
      final p = player(r)..dead = 1;
      final caster = PartyMember.createPreset(2)..sp = 1000;
      final result = FieldMagicLogic.revitalizeOne(caster, p);
      expect(result.success, true);
      expect(caster.sp, 970);
      expect(p.dead, 0);
      expect(p.unconscious, r['afterUnconscious']);
    });
  }
  for (final r in f['hpStores']) {
    test('native ${r['routine']} HP store ${r['hp']} - ${r['damage']}', () {
      final p = PartyMember.createPreset(2)
        ..sp = 20000
        ..accMagic = 20
        ..accArms = 20;
      final foe = Monster.create(1)
        ..ac = 0
        ..resistance = 0
        ..hp = r['hp'];
      final battle = LoreBattle(
        party: [p],
        enemy: [foe],
        random: _Zero(),
        print: (_, s) {},
      );
      battle.battle[1][1] = r['routine'] == 'attack' ? 1 : 2;
      battle.battle[1][3] = 1;
      if (r['routine'] == 'attack') {
        p.strength = 20;
        p.battleLevel = 20;
        p.weaPower = r['damage'];
        // strength*level/20=20; choose source-valid powers for each tested damage.
        if (r['damage'] == 30) {
          p.battleLevel = 1;
          p.weaPower = 30;
        } else if (r['damage'] == 360) {
          p.strength = 18;
          p.weaPower = 20;
        } else {
          p.weaPower = 50;
        }
        battle.attackOne();
      } else {
        if (r['damage'] == 30) {
          p.magicLevel = 15;
          battle.battle[1][2] = 1;
        } else if (r['damage'] == 1000) {
          p.magicLevel = 125;
          battle.battle[1][2] = 2;
        } else {
          p.magicLevel = 20;
          battle.battle[1][2] = 3;
        }
        battle.castOne();
      }
      expect(foe.hp, (r['afterHp'] as int) <= 0 ? 0 : r['afterHp']);
      expect(foe.isUnconscious, (r['afterHp'] as int) <= 0);
    });
  }
  for (final r in f['enemyPoison']) {
    test('native enemy poison HP${r['hp']}', () {
      final foe = Monster.create(1)
        ..hp = r['hp']
        ..isPoisoned = true
        ..castLevel = 0
        ..accArms = 0
        ..accMagic = 0;
      final battle = LoreBattle(
        party: [PartyMember.createPreset(1)],
        enemy: [foe],
        random: _Zero(),
        print: (_, s) {},
      );
      battle.enemyPhase();
      expect(foe.hp, r['afterHp']);
      expect(foe.isUnconscious, r['afterUnconscious']);
    });
  }
  test(
    'negative integer counters do not pass source exist or prevent GameOver',
    () async {
      for (final counters in [(-1, 0), (0, -1), (-32768, 0), (0, -32768)]) {
        final p = PartyMember.createPreset(1)
          ..hp = 10
          ..dead = counters.$1
          ..unconscious = counters.$2;
        expect(p.isBattleActive, false);
        var calls = 0;
        await LoreMainProcedures.detectGameOver([p], () async {
          calls++;
        });
        expect(calls, 1);
      }
    },
  );
  test('event gold application wraps in the actual resource reducer', () {
    final native = jsonDecode(
      File('test/fixtures/dos_recruit_storage.json').readAsStringSync(),
    );
    for (final r in native['gold']) {
      final out = ScriptWorldReducer.applyResources(
        ScriptResources(gold: r['before'], food: 10),
        ScriptOutcome(goldDelta: r['amount']),
      );
      expect(out.gold, r['after']);
      expect(out.food, 10);
    }
  });
  for (final r in f['experience']) {
    test(
      'event EXP store ${r['before']} + ${r['amount']} uses six named slots',
      () {
        final party = [
          for (var i = 0; i < 7; i++)
            PartyMember.createPreset(1)..experience = r['before'],
        ];
        party[2].name = '';
        final before = [for (final p in party) p.toJson()];
        final result = ScriptPartyReducer.applyProgress(
          party,
          ScriptOutcome(expDelta: r['amount'], partyClassId: 10),
        );
        for (final i in [0, 1, 3, 4, 5]) {
          expect(result[i].experience, r['after']);
          expect(result[i].playerClass, PlayerClass.demigod);
        }
        expect(result[2].toJson(), before[2]);
        expect(result[6].toJson(), before[6]);
        expect([for (final p in party) p.toJson()], before);
      },
    );
  }
  test(
    'Hospital negative cost keeps native longint gold at overflow',
    () async {
      final r = (f['gold'] as List).singleWhere((r) => r['cost'] == -32768);
      final p = PartyMember.createPreset(1)
        ..unconscious = 16384
        ..dead = 0;
      final io = _Shop();
      await LoreTownShops.hospital(io, [p]);
      expect(io.gold, r['after']);
      expect(p.unconscious, 0);
      expect(p.hp, 1);
    },
  );
  for (final (i, r) in (f['averages'] as List).indexed) {
    test('native encounter six-slot ${r['kind']} average $i', () {
      final party = [
        for (final v in r['values'])
          PartyMember.createPreset(1)
            ..agility = v
            ..luck = v,
      ];
      final equal = Monster.create(1)..agility = r['average'];
      final lower = Monster.create(1)..agility = (r['average'] as int) - 1;
      if (r['kind'] == 'agility') {
        expect(LoreEncounterLogic.enemyActsFirst(party, [equal]), true);
        if (r['average'] > 0) {
          expect(LoreEncounterLogic.enemyActsFirst(party, [lower]), false);
        }
      } else {
        expect(LoreEncounterLogic.canEvadeBeforeBattle(party, [equal]), false);
        if (r['average'] > 0) {
          expect(LoreEncounterLogic.canEvadeBeforeBattle(party, [lower]), true);
        }
      }
    });
  }
  test('native EncounterEnemy average divisor zero faults', () {
    expect(f['divisionFaults'], ['party', 'enemy']);
    expect(f['divisionErrorCode'], 200);
    expect(
      () => LoreEncounterLogic.enemyActsFirst([], [Monster.create(1)]),
      throwsStateError,
    );
    expect(
      () => LoreEncounterLogic.canEvadeBeforeBattle([], [Monster.create(1)]),
      throwsStateError,
    );
    expect(() => LoreEncounterLogic.averageEnemyAgility([]), throwsStateError);
  });
  for (final r in f['bosses']) {
    test('native ${r['name']} override keeps initialized HP', () {
      final raw = Uint8List.fromList(List<int>.from(r['after']));
      final d = ByteData.sublistView(raw);
      final p = Monster.create(r['template']);
      final altered = p.withOverrides(
        name: r['name'],
        level: raw[29],
        eNumber: raw[0],
        special: raw[26],
      );
      expect(altered.hp, d.getInt16(30, Endian.little));
      expect(altered.hp, p.hp);
      expect(altered.level, raw[29]);
      expect(altered.eNumber, raw[0]);
      expect(p.level, isNot(altered.level));
      expect(altered.withOverrides(hp: 210, level: 7).hp, 210);
    });
  }
  test(
    'direct mummy-room and Hidra procedures keep original initialized HP',
    () {
      final runs = [
        LoreSpecProcedures.map11(
          30,
          24,
          const ScriptContext(tileAtPlayer: 0, sourceEtc: {13: 1}),
          LoreScriptEngine(),
        )!,
        LoreSpecProcedures.map17(
          22,
          40,
          const ScriptContext(
            tileAtPlayer: 0,
            sourceEtc: {15: 1, 1: 1, 38: 0, 5: 0},
          ),
          LoreScriptEngine(),
        )!,
      ];
      for (var run in runs) {
        while (run.hasPendingScene) {
          run = run.acknowledgeScene();
        }
        final ids = run.outcome.battleMonsters;
        expect(ids, isNotEmpty);
        for (final o in run.outcome.battleOverrides) {
          if (o['level'] == null) continue;
          final original = Monster.create(ids[(o['index'] as int) - 1]);
          final altered = original.withOverrides(
            level: o['level'] as int,
            eNumber: o['eNumber'] as int?,
          );
          final native = (f['bosses'] as List).singleWhere(
            (r) => r['template'] == original.eNumber,
          );
          final bytes = Uint8List.fromList(List<int>.from(native['after']));
          expect(
            altered.hp,
            ByteData.sublistView(bytes).getInt16(30, Endian.little),
          );
        }
      }
    },
  );
}
