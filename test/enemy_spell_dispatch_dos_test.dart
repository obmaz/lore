import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

class _NoRandom implements Random {
  @override
  int nextInt(int max) =>
      throw StateError('Spell selector must not consume RNG');
  @override
  bool nextBool() => throw StateError('No bool RNG');
  @override
  double nextDouble() => throw StateError('No float RNG');
}

class _SpellBattle extends LoreBattle {
  _SpellBattle(Monster foe, List<(int, String)> messages)
    : super(
        party: [
          for (var i = 1; i <= 7; i++) PartyMember.zero()..name = 'Slot$i',
        ],
        enemy: [foe],
        random: _NoRandom(),
        print: (color, text) => messages.add((color, text)),
      );
  final calls = <List<int>>[];
  @override
  void castAttackSub(int power, int num) => calls.add([power, num]);
}

/// LOREBATT.PAS:602-663. Native case selection, level multiplication and all-six
/// call order. Native string/Print and called effects are not executed here.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/dos_enemy_spell_dispatch.json').readAsStringSync(),
  );
  const single = ['충격', '냉기', '고통', '혹한', '화염', '번개'];
  const all = ['열파', '에너지', '초음파', '혹한기', '화염폭풍'];
  for (final allSlots in [false, true]) {
    test('native ${allSlots ? 'all' : 'single'} spell selector: 1024 byte/level cases', () {
      final rows = (fixture['cases'] as List).where(
        (r) => r['all'] == allSlots,
      );
      expect(rows.length, 1024);
      for (final row in rows) {
        final foe = Monster(
          eNumber: 1,
          name: 'Native caster',
          mentality: row['mentality'],
          level: row['level'],
          strength: 1,
          endurance: 1,
          resistance: 0,
          agility: 0,
          accArms: 0,
          accMagic: 0,
          ac: 0,
          special: 0,
          castLevel: 0,
          specialCastLevel: 0,
        );
        final messages = <(int, String)>[];
        final battle = _SpellBattle(foe, messages);
        final before = battle.party.map((p) => p.toJson()).toList();
        if (allSlots) {
          battle.castAttackAll();
        } else {
          battle.castAttackOne(row['target']);
        }
        final reason =
            'all=$allSlots mentality=${row['mentality']} level=${row['level']}';
        expect(battle.calls, row['calls'], reason: reason);
        expect(messages.length, 1, reason: reason);
        expect(messages.single.$1, 13, reason: reason);
        // Source-translated label checked against the native selected range ID;
        // this is not independent native Korean glyph/string decoding.
        final label = (allSlots ? all : single)[row['method'] - 1];
        expect(messages.single.$2, contains("'$label'"), reason: reason);
        expect(
          battle.party.map((p) => p.toJson()).toList(),
          before,
          reason: reason,
        );
      }
    });
  }
}
