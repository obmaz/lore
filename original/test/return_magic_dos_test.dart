import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lore/logic/lore_battle.dart';
import 'package:lore/logic/lore_random.dart';
import 'package:lore/logic/lore_source_memory.dart';
import 'package:lore/logic/lore_sub_text.dart';
import 'package:lore/models/monster.dart';
import 'package:lore/models/party_member.dart';

/// LORESUB.PAS:729 ReturnMagic CASE; original runtime string/set helpers run.
/// Missing assignments are an explicit port fault, not empty/gargabe labels.
void main() {
  final native = jsonDecode(
    File('test/fixtures/dos_return_magic.json').readAsStringSync(),
  );
  test('all signed integer inputs match native names and low-byte grammar', () {
    expect(native['checkedInputs'], 65536);
    expect(native['unassignedInputs'], 65491);
    final names = {
      for (final row in native['defined']) row['magic']: row['name'],
    };
    expect(names.keys.toSet(), {for (var i = 1; i <= 45; i++) i});
    for (var id = -32768; id <= 32767; id++) {
      final grammar = native['grammarByLowByte'][id & 255];
      expect(LoreSubText.magicJosa(id), grammar[0]);
      expect(LoreSubText.magicMokjuk(id), grammar[1]);
      if (names.containsKey(id)) {
        expect(LoreSubText.magicName(id), names[id]);
      } else {
        expect(() => LoreSubText.magicName(id), throwsStateError);
      }
    }
    for (final id in [-2147483648, 2147483647, 65537, -65535, 65581]) {
      final wrapped = LorePascal.integer(id);
      if (names.containsKey(wrapped)) {
        expect(LoreSubText.magicName(id), names[wrapped]);
      } else {
        expect(() => LoreSubText.magicName(id), throwsStateError);
      }
    }
  });

  test(
    'unassigned native result depends on caller memory, never a default name',
    () {
      for (final row in native['unassigned']) {
        expect(row['unchanged'], isTrue);
        expect(row['name'], row['seed']);
        expect(() => LoreSubText.magicName(row['magic']), throwsStateError);
      }
      final atZero = [
        for (final row in native['unassigned'])
          if (row['magic'] == 0) row['name'],
      ];
      expect(atZero.toSet(), {'JUNK', 'Old result', ''});
    },
  );

  test('actual battle log owner uses every defined name without state or RNG changes', () {
    final party = [PartyMember.createPreset(1)];
    final enemy = [Monster.create(1)];
    final random = LoreRandom(1993);
    final battle = LoreBattle(
      party: party,
      enemy: enemy,
      random: random,
      print: (_, _) {},
    );
    final beforeParty = party.first.toJson();
    final beforeHp = enemy.first.hp;
    final beforeSeed = random.seed;
    for (final row in native['defined']) {
      final text = battle.returnMessage(1, 2, row['magic'], 1);
      expect(
        text,
        "${party.first.name}는 '${row['name']}'${row['josa']}로 ${enemy.first.name}에게 공격했다",
      );
    }
    expect(() => battle.returnMessage(1, 2, 0, 1), throwsStateError);
    expect(party.first.toJson(), beforeParty);
    expect(enemy.first.hp, beforeHp);
    expect(random.seed, beforeSeed);
  });
}
