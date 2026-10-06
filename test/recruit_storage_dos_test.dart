import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/field_magic_logic.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_field_logic.dart';
import 'package:lore/logic/lore_join.dart';
import 'package:lore/logic/lore_rigel_blessing.dart';
import 'package:lore/logic/lore_town_shops.dart';
import 'package:lore/logic/town_logic.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _Random implements Random {
  _Random([this.values = const []]);
  final List<int> values;
  final List<int> bounds = [];
  @override
  int nextInt(int max) {
    bounds.add(max);
    return values.isEmpty ? 0 : values[bounds.length - 1];
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

class _Io implements LoreShopIo {
  _Io(this.answers);
  final List<int> answers;
  final List<String> lines = [];
  @override
  int gold = 1000000;
  @override
  int food = 10;
  @override
  void clear() {}
  @override
  void print(int color, String text) => lines.add(text);
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

PartyMember _player(dynamic r) => PartyMember.createPreset(1)
  ..name = 'Hero'
  ..endurance = r['endurance']
  ..battleLevel = r['level']
  ..magicLevel = 1
  ..espLevel = 1
  ..hp = r['hp'] ?? 0
  ..dead = 0
  ..unconscious = 0
  ..poison = 0;
Monster _monster(dynamic r) => Monster(
  eNumber: 1,
  name: 'Template',
  strength: 30,
  mentality: r['mentality'] ?? 20,
  endurance: r['endurance'],
  resistance: 80,
  agility: 18,
  accArms: 19,
  accMagic: 20,
  ac: 7,
  special: 2,
  castLevel: r['cast'] ?? 5,
  specialCastLevel: 1,
  level: r['level'],
);
void main() {
  final f = jsonDecode(
    File('test/fixtures/dos_recruit_storage.json').readAsStringSync(),
  );
  for (final r in f['joins']) {
    test(
      'original join level${r['level']} cast${r['cast']} end${r['endurance']}',
      () {
        final p = PartyMember.fromMonsterTemplate(
          _monster(r),
          previousExperience: r['previousExperience'],
        );
        final b = Uint8List.fromList(List<int>.from(r['record']));
        final d = ByteData.sublistView(b);
        expect(p.name, 'Template');
        expect(p.playerClass, PlayerClass.none);
        expect([
          p.strength,
          p.mentality,
          p.concentration,
          p.endurance,
          p.resistance,
          p.agility,
          p.accArms,
          p.accMagic,
          p.accEsp,
          p.luck,
          p.poison,
        ], b.sublist(20, 31));
        expect(
          [p.unconscious, p.dead, p.hp, p.sp, p.esp],
          [
            for (final i in [31, 33, 35, 37, 39]) d.getInt16(i, Endian.little),
          ],
        );
        expect([
          p.battleLevel,
          p.magicLevel,
          p.espLevel,
          p.ac,
        ], b.sublist(41, 45));
        expect(p.experience, d.getInt32(45, Endian.little));
        expect([
          p.weapon,
          p.shield,
          p.armor,
          p.weaPower,
          p.shiPower,
          p.armPower,
        ], b.sublist(49, 55));
        final old = PartyMember.blank()..experience = r['previousExperience'];
        final party = [PartyMember.createPreset(1), old];
        final recruit = PartyMember.fromMonsterTemplate(_monster(r));
        LoreJoin.applyJoin(party, recruit, 0);
        expect(party[1].experience, p.experience);
      },
    );
  }
  for (final r in f['enemies']) {
    test('original enemy HP ${r['endurance']} x ${r['level']}', () {
      expect(_monster(r).hp, r['hp']);
      final original = _monster(r)..hp = 123;
      // A field-only override is not a second joinenemy initialization.
      expect(original.withOverrides(level: r['level']).hp, 123);
      expect(original.withOverrides(name: 'Renamed').hp, 123);
      expect(original.withOverrides(level: r['level'], hp: 123).hp, 123);
    });
  }
  for (final r in f['minds']) {
    test('original turn_mind HP ${r['endurance']} x ${r['level']}', () {
      final victim = _player(r);
      final party = [for (var i = 0; i < 5; i++) PartyMember.blank(), victim];
      final foe = Monster.create(20)..specialCastLevel = 2;
      final random = _Random([0, 1, 0]);
      final battle = LoreBattle(
        party: party,
        enemy: [foe],
        random: random,
        print: (_, s) {},
      );
      battle.specialCastAttack();
      expect(battle.enemy.last.hp, r['hp']);
      expect(victim.name, '');
      expect(random.bounds, [3, 3, 5]);
    });
  }
  for (final r in f['gold']) {
    test('original findgold ${r['before']} + ${r['amount']}', () {
      expect(
        LoreFieldLogic.applyGoldFound(r['before'], r['amount']),
        r['after'],
      );
    });
  }
  for (final r in f['health']) {
    test(
      'original HealOne branches ${r['endurance']} ${r['level']} HP${r['hp']}',
      () {
        final caster = PartyMember.createPreset(2)
          ..magicLevel = 255
          ..sp = 1000;
        final p = _player(r);
        final result = FieldMagicLogic.healOne(caster, p);
        expect(result.success, r['needsHealing']);
        expect(p.hp, r['needsHealing'] ? r['healedHp'] : r['hp']);
        expect(caster.sp, r['needsHealing'] ? 490 : 1000);
      },
    );
    test(
      'original Hospital branches ${r['endurance']} ${r['level']} HP${r['hp']}',
      () async {
        final p = _player(r);
        final io = _Io(r['hospitalNeedsHealing'] ? [1, 1, 0] : [1, 1, 0, 0]);
        await LoreTownShops.hospital(io, [p]);
        expect(p.hp, r['hospitalNeedsHealing'] ? r['hospitalHp'] : r['hp']);
        if (!r['hospitalNeedsHealing']) expect(io.gold, 1000000);
      },
    );
  }
  for (final r in f['rests']) {
    test(
      'original Rest cap/refund ${r['endurance']} ${r['level']} HP${r['hp']} food${r['food']}',
      () {
        final p = _player(r);
        final out = TownLogic.rest([p], r['food']);
        expect(p.hp, r['afterHp']);
        expect(out.food, r['afterFood']);
        expect(out.logs.any((s) => s.contains('모든 건강')), r['full']);
      },
    );
  }
  for (final r in f['weapons']) {
    test('original weapon class${r['classId']} power${r['power']}', () {
      final p = PartyMember.createPreset(1)
        ..playerClass = PlayerClass.fromId(r['classId']);
      p.equipWeaponRaw(1, r['power']);
      expect(p.weaPower, r['after']);
    });
  }
  for (final r in f['armors']) {
    test(
      'original armor class${r['classId']} shield${r['shield']} armor${r['armor']}',
      () {
        final p = PartyMember.createPreset(1)
          ..playerClass = PlayerClass.fromId(r['classId']);
        p.equipShieldRaw(1, r['shield']);
        p.equipArmorRaw(1, r['armor']);
        expect(p.ac, r['after']);
      },
    );
  }
  test('original Rigel Round and byte store for all 256 weapon bytes; only six slots', () {
    for (final r in f['rigel']) {
      final party = [
        for (var i = 0; i < 7; i++)
          PartyMember.createPreset(1)..weaPower = r['power'],
      ];
      final random = _Random();
      applyRigelBlessing(party, random);
      expect([
        for (final p in party.take(6)) p.weaPower,
      ], List.filled(6, r['after']));
      expect(party[6].weaPower, r['power']);
      expect(random.bounds, List.filled(12, 20));
    }
  });
  test('original CastAttack6 zero named party faults before armor RNG', () {
    expect(f['emptyAverageFault'], true);
    final foe = Monster.create(1)
      ..castLevel = 6
      ..hp = 1000;
    final random = _Random();
    final lines = <String>[];
    final battle = LoreBattle(
      party: [],
      enemy: [foe],
      random: random,
      print: (_, s) => lines.add(s),
    );
    expect(battle.castAttack, throwsStateError);
    expect(random.bounds, isEmpty);
    expect(lines, isEmpty);
  });
}
